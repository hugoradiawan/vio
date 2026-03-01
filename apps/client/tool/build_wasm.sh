#!/usr/bin/env bash
# Build the Rust canvas engine to WASM for Flutter web.
#
# Prerequisites (one-time):
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-bindgen-cli --version 0.2.92
#
# Usage:
#   ./tool/build_wasm.sh          # release build
#   ./tool/build_wasm.sh --debug  # debug build (faster compile, larger output)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$CLIENT_DIR/rust"
WEB_PKG_DIR="$CLIENT_DIR/web/pkg"

# Parse arguments
PROFILE="release"
CARGO_FLAGS="--release"
if [[ "${1:-}" == "--debug" ]]; then
  PROFILE="debug"
  CARGO_FLAGS=""
fi

echo "==> Building Rust crate for wasm32-unknown-unknown ($PROFILE)..."

# 1. Verify prerequisites
if ! rustup target list --installed | grep -q wasm32-unknown-unknown; then
  echo "ERROR: wasm32-unknown-unknown target not installed."
  echo "  Run: rustup target add wasm32-unknown-unknown"
  exit 1
fi

if ! command -v wasm-bindgen &>/dev/null; then
  echo "ERROR: wasm-bindgen CLI not found."
  echo "  Run: cargo install wasm-bindgen-cli --version 0.2.92"
  exit 1
fi

# 2. Compile to WASM (redirect stderr→stdout so melos doesn't label progress as ERROR)
cd "$RUST_DIR"
cargo build --target wasm32-unknown-unknown $CARGO_FLAGS 2>&1

# 3. Run wasm-bindgen to produce JS glue + processed WASM
WASM_FILE="$RUST_DIR/target/wasm32-unknown-unknown/$PROFILE/rust_lib_vio_client.wasm"

if [[ ! -f "$WASM_FILE" ]]; then
  echo "ERROR: WASM binary not found at $WASM_FILE"
  exit 1
fi

mkdir -p "$WEB_PKG_DIR"

wasm-bindgen \
  "$WASM_FILE" \
  --out-dir "$WEB_PKG_DIR" \
  --web \
  --no-typescript 2>&1

echo "==> WASM artifacts written to $WEB_PKG_DIR"
ls -lh "$WEB_PKG_DIR"

# 4. Optional: optimize with wasm-opt (if available)
WASM_BG="$WEB_PKG_DIR/rust_lib_vio_client_bg.wasm"
if command -v wasm-opt &>/dev/null && [[ "$PROFILE" == "release" ]]; then
  echo "==> Optimizing WASM binary with wasm-opt..."
  wasm-opt -Oz "$WASM_BG" -o "$WASM_BG" 2>&1
  echo "==> Optimized size: $(du -h "$WASM_BG" | cut -f1)"
fi

echo "==> Done! WASM build complete."
