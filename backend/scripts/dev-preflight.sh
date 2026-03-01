#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[preflight] Checking Podman availability..."
if ! command -v podman >/dev/null 2>&1; then
  echo "[preflight] ERROR: podman is not installed or not in PATH."
  exit 1
fi

if ! podman ps >/dev/null 2>&1; then
  echo "[preflight] Podman connection unavailable. Attempting podman machine start..."
  if ! podman machine start >/dev/null 2>&1; then
    echo "[preflight] podman machine start returned non-zero; re-checking connection..."
  fi
fi

if ! podman ps >/dev/null 2>&1; then
  echo "[preflight] Still unreachable — performing full stop/start cycle (stale SSH tunnel)..."
  podman machine stop >/dev/null 2>&1 || true
  if ! podman machine start >/dev/null 2>&1; then
    echo "[preflight] ERROR: podman machine start failed after stop/start cycle."
    exit 1
  fi
fi

if ! podman ps >/dev/null 2>&1; then
  echo "[preflight] ERROR: unable to connect to Podman after stop/start cycle."
  exit 1
fi

echo "[preflight] Ensuring postgres container is running..."
if ! podman compose up -d postgres >/dev/null 2>&1; then
  echo "[preflight] ERROR: failed to start postgres via podman compose."
  exit 1
fi

echo "[preflight] Waiting for database readiness..."
attempt=1
max_attempts=8
while [ "$attempt" -le "$max_attempts" ]; do
  if bun run db:push >/dev/null 2>&1; then
    echo "[preflight] Database is reachable."
    exit 0
  fi

  echo "[preflight] DB not ready yet (attempt ${attempt}/${max_attempts}); retrying in 2s..."
  attempt=$((attempt + 1))
  sleep 2
done

echo "[preflight] ERROR: database is still unreachable after retries."
bun run db:push || true
exit 1
