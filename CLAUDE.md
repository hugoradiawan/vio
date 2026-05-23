# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vio is a Figma/Penpot-like design and prototyping tool with Git-like version control, built as a Melos monorepo. The stack is Flutter (Web/Desktop) + Rust rendering engine + Bun/ConnectRPC backend + PostgreSQL.

## Prerequisites

- [FVM](https://fvm.app/) — Flutter Version Management (`dart pub global activate fvm`)
- [Melos](https://melos.invertase.dev/) — Monorepo management (`dart pub global activate melos`)
- [Bun](https://bun.sh/) — Backend runtime
- [Podman](https://podman.io/) — Container runtime for PostgreSQL
- Rust toolchain with `wasm32-unknown-unknown` target for web builds
- `wasm-bindgen-cli` v0.2.92 for WASM output

## Common Commands

### Bootstrap

```bash
fvm install && fvm use      # Pin Flutter SDK
melos bootstrap             # Install Dart deps across all packages
cd backend && bun install   # Install backend deps
```

### Run

```bash
# Start PostgreSQL first
podman machine start && podman compose up -d postgres

# Flutter client
melos run run:client:web        # Chrome (dev)
melos run run:client:macos      # macOS (dev)
melos run run:client:windows    # Windows (dev)

# Backend (watch mode, ports 4000 gRPC / 4001 gRPC-Web)
cd backend && bun run dev
```

### Test & Lint

```bash
melos run test              # Flutter tests across all packages
melos run analyze           # dart analyze across all packages
melos run format            # dart format across all packages
cd backend && bun test      # Backend tests
cd backend && bun run lint  # Biome lint
cd backend && bun run format # Biome format (writes)
melos run rust:test         # Rust unit tests
melos run rust:clippy       # Rust clippy (errors on warnings)
```

### Single test

```bash
cd apps/client && fvm flutter test test/path/to/test.dart
cd backend && bun test src/path/to/test.ts
cd apps/client/rust && cargo test test_name
```

### Code Generation

```bash
# Protobuf → Dart + TypeScript (run from repo root)
cd backend && bun run proto:generate

# flutter_rust_bridge Dart bindings from Rust API
melos run rust:generate

# build_runner (Dart codegen)
melos run build:runner
```

### Rust / WASM

```bash
melos run rust:build:wasm       # Release WASM build for Flutter web
bash apps/client/tool/build_wasm.sh --debug  # Debug WASM build
cd apps/client/rust && cargo bench           # Benchmarks
```

### Database

```bash
cd backend && bun run db:push   # Push Drizzle schema (dev)
cd backend && bun run db:seed   # Seed demo data
cd backend && bun run db:studio # Drizzle Studio UI
```

## Architecture

### Monorepo Layout

```
apps/client/       Flutter app (Web, macOS, Windows)
  lib/src/
    features/      Feature-first slices (canvas, version_control, workspace, assets, auth)
    core/          DI (ServiceLocator), gRPC client, repositories, router, config
    gen/           Generated Dart gRPC stubs (do not edit)
  rust/            Rust canvas engine (flutter_rust_bridge)
  config/          Per-env dart-define JSON (dev/staging/production)

packages/
  core/            Shared Dart: Shape model hierarchy, Matrix2D math, extensions
  ui_kit/          VioTheme, VioColors (Blue Dark Mode design system)
  protos/          .proto files — single source of truth for all types
    vio/v1/        shape, canvas, branch, commit, pullrequest, auth, asset, project

backend/           Bun + ConnectRPC server
  src/
    services/      Service implementations (one per proto service)
    db/schema/     Drizzle ORM table definitions
    gen/           Generated TypeScript from protos (do not edit)
```

### Flutter Client Architecture

**State management**: `flutter_bloc`. Each feature has a BLoC; `CanvasBloc` is the largest and is split across several `part` files (`canvas_bloc_commands.dart`, `canvas_bloc_history.dart`, `canvas_bloc_rust.dart`, etc.).

**Dependency injection**: `ServiceLocator` (singleton, initialized in `main()`). It owns gRPC service clients, repositories, `PreferencesService`, and `RustEngineService`.

**Routing**: Centralized in `core/router.dart`.

**gRPC**: `GrpcClient` (singleton) connects to the backend. Platform-specific channel creation is abstracted in `core/grpc/`. Config (host/port/TLS) comes from `--dart-define-from-file` JSON.

### Rust Engine (`apps/client/rust/`)

Exposed to Dart via `flutter_rust_bridge`. Entry point is `src/lib.rs`. Key modules:

- `api/engine.rs` — `CanvasEngine` (the opaque type Dart holds): owns `SceneTree`, `SpatialIndex`, `TileGrid`. Methods: `sync_shapes`, `query_visible`, hit-test, `rasterize_dirty_tiles`.
- `scene_graph/` — `SceneTree` (parent/child relationships), `SpatialIndex` (rstar R-tree for viewport queries), `RenderShape`.
- `render/` — `DrawCommand` generation and culling logic.
- `rasterizer/` — `tiny-skia` tile painter (512×512 px tiles). Shapes above a size threshold are tile-rasterized; smaller ones are drawn via Dart's `CustomPainter`.
- `math/` — `Aabb`, matrix helpers (mirrors Dart's `Matrix2D` in `packages/core`).

For web, the Rust crate compiles to WASM (`wasm32-unknown-unknown`) via `tool/build_wasm.sh`; output lands in `web/pkg/`. Native desktop uses a static library.

### Backend Architecture

ConnectRPC service handlers in `src/services/` implement the proto-defined interfaces. Database access goes through Drizzle ORM (`src/db/schema/`). Ports: **4000** (HTTP/2 gRPC), **4001** (gRPC-Web for Flutter web).

### Protobuf as Single Source of Truth

All data types live in `packages/protos/vio/v1/*.proto`. Running `cd backend && bun run proto:generate` regenerates both:
- `apps/client/lib/src/gen/` (Dart)
- `backend/src/gen/` (TypeScript)

Never edit generated files directly.

### Version Control Feature

The `features/version_control/` feature implements a Git-like model: branches, commits, pull requests, and three-way property-level merge with conflict detection and resolution. Data flows through the same proto/gRPC pipeline as canvas data.

## Environment Config

Client environment is injected at build time via `--dart-define-from-file=config/<env>.json`. The JSON keys are `APP_ENV`, `API_BASE_URL`, `GRPC_HOST`, `GRPC_PORT`, `GRPC_WEB_PORT`, `USE_TLS`. Never hardcode these in source.

## Backend Linting

The backend uses **Biome** (not ESLint/Prettier). Run `bun run format` and `bun run lint` from `backend/`. Do not add ESLint or Prettier config.
