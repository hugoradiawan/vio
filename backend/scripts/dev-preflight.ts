#!/usr/bin/env bun

import { existsSync } from "node:fs";

const POSTGRES_HOST_PORT = "55432";

const run = (cmd: string[], quiet = false) => {
  const proc = Bun.spawnSync(cmd, {
    stdout: quiet ? "ignore" : "inherit",
    stderr: quiet ? "ignore" : "inherit",
  });
  return proc.exitCode === 0;
};

const runCapture = (cmd: string[]) => {
  const proc = Bun.spawnSync(cmd, {
    stdout: "pipe",
    stderr: "ignore",
  });

  return {
    ok: proc.exitCode === 0,
    stdout: proc.stdout ? new TextDecoder().decode(proc.stdout).trim() : "",
  };
};

const ensurePostgresWithPodmanRunFallback = () => {
  if (run(["podman", "compose", "up", "-d", "postgres"], true)) {
    return true;
  }

  console.log(
    "[preflight] podman compose unavailable or failed; falling back to direct podman container startup...",
  );

  // If container already exists, try starting it instead of recreating.
  if (run(["podman", "container", "exists", "vio-postgres"], true)) {
    const portInfo = runCapture(["podman", "port", "vio-postgres"]);
    const hasExpectedPort =
      portInfo.ok && portInfo.stdout.includes(`:${POSTGRES_HOST_PORT}`);

    if (!hasExpectedPort) {
      console.log(
        `[preflight] Recreating vio-postgres to bind host port ${POSTGRES_HOST_PORT}...`,
      );
      if (!run(["podman", "rm", "-f", "vio-postgres"], true)) {
        console.error("[preflight] ERROR: unable to recreate vio-postgres container.");
        return false;
      }
    } else if (run(["podman", "start", "vio-postgres"], true)) {
      return true;
    } else {
      console.error("[preflight] ERROR: existing vio-postgres container could not be started.");
      return false;
    }
  }

  // Mirror backend/docker-compose.yml defaults for local development.
  return run(
    [
      "podman",
      "run",
      "-d",
      "--name",
      "vio-postgres",
      "--restart",
      "unless-stopped",
      "-e",
      "POSTGRES_USER=vio",
      "-e",
      "POSTGRES_PASSWORD=vio",
      "-e",
      "POSTGRES_DB=vio",
      "-p",
      `${POSTGRES_HOST_PORT}:5432`,
      "-v",
      "postgres_data:/var/lib/postgresql/data",
      "postgres:16-alpine",
    ],
    true,
  );
};

const runDbPush = (quiet = true) => {
  if (run(["bun", "run", "db:push"], quiet)) {
    return true;
  }

  // Fallback for environments where local bin shims are not on PATH yet.
  return run(["bunx", "drizzle-kit", "push"], quiet);
};

const ensureBackendDependencies = () => {
  const hasDrizzleOrm = existsSync(
    new URL("../node_modules/drizzle-orm/package.json", import.meta.url),
  );
  const hasDrizzleKit = existsSync(
    new URL("../node_modules/drizzle-kit/package.json", import.meta.url),
  );

  if (hasDrizzleOrm && hasDrizzleKit) {
    return true;
  }

  console.log("[preflight] Installing backend dependencies (bun install)...");
  return run(["bun", "install"], false);
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

console.log("[preflight] Checking Podman availability...");
if (!run(["podman", "--version"], true)) {
  console.error("[preflight] ERROR: podman is not installed or not in PATH.");
  process.exit(1);
}

if (!run(["podman", "ps"], true)) {
  console.log("[preflight] Podman connection unavailable. Attempting podman machine start...");
  if (!run(["podman", "machine", "start"], true)) {
    console.log("[preflight] podman machine start returned non-zero; re-checking connection...");
  }
}

if (!run(["podman", "ps"], true)) {
  console.error("[preflight] ERROR: unable to connect to Podman after restart attempt.");
  process.exit(1);
}

console.log("[preflight] Ensuring postgres container is running...");
if (!ensurePostgresWithPodmanRunFallback()) {
  console.error("[preflight] ERROR: failed to start postgres container.");
  process.exit(1);
}

console.log("[preflight] Waiting for database readiness...");
const maxAttempts = 8;
for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
  if (run(["podman", "exec", "vio-postgres", "pg_isready", "-U", "vio", "-d", "vio"], true)) {
    console.log("[preflight] Database is reachable.");
    if (!ensureBackendDependencies()) {
      console.error("[preflight] ERROR: failed to install backend dependencies.");
      process.exit(1);
    }

    if (runDbPush(true)) {
      process.exit(0);
    }

    console.error("[preflight] ERROR: database reachable but failed to apply schema.");
    runDbPush(false);
    process.exit(1);
  }

  console.log(
    `[preflight] DB not ready yet (attempt ${attempt}/${maxAttempts}); retrying in 2s...`,
  );
  await sleep(2000);
}

console.error("[preflight] ERROR: database is still unreachable after retries.");
run(["podman", "logs", "--tail", "50", "vio-postgres"], false);
process.exit(1);
