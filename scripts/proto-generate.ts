#!/usr/bin/env bun

import { spawnSync } from "node:child_process";
import * as path from "node:path";

const rootDir = process.cwd();
const homeDir = process.env.HOME || process.env.USERPROFILE || "";
const pathSep = process.platform === "win32" ? ";" : ":";

const extraPaths = [
  path.join(rootDir, "backend", "node_modules", ".bin"),
  path.join(homeDir, ".pub-cache", "bin"),
];

const env = {
  ...process.env,
  PATH: [process.env.PATH || "", ...extraPaths].join(pathSep),
};

const run = (command: string, args: string[]) =>
  spawnSync(command, args, {
    cwd: rootDir,
    env,
    stdio: "inherit",
    shell: process.platform === "win32",
  });

const commandExists = (command: string) => {
  const checker = process.platform === "win32" ? "where" : "which";
  const result = spawnSync(checker, [command], {
    cwd: rootDir,
    env,
    stdio: "ignore",
    shell: process.platform === "win32",
  });
  return result.status === 0;
};

if (!commandExists("protoc-gen-dart")) {
  console.log("[proto:generate] protoc-gen-dart not found. Installing protoc_plugin...");

  let install = run("dart", ["pub", "global", "activate", "protoc_plugin"]);
  if (install.status !== 0 && commandExists("fvm")) {
    install = run("fvm", ["dart", "pub", "global", "activate", "protoc_plugin"]);
  }

  if (install.status !== 0) {
    console.error("[proto:generate] ERROR: failed to install protoc_plugin.");
    process.exit(1);
  }
}

const result = spawnSync("bunx", ["@bufbuild/buf", "generate"], {
  cwd: path.join(rootDir, "packages", "protos"),
  env,
  stdio: "inherit",
  shell: process.platform === "win32",
});

process.exit(result.status ?? 1);
