# Vio - AI Coding Instructions

## Project Overview
Penpot-inspired design & prototyping tool with Git-like version control for designs. **Melos monorepo**: Flutter client (Web/Windows) + Bun ConnectRPC backend.

## Architecture

### Monorepo Layout
- `apps/client/` — Flutter app, composition root. Features in `lib/src/features/{canvas,version_control,workspace,assets}/`
- `packages/core/` — Shared domain models (`Shape` hierarchy), math (`Matrix2D`), utilities
- `packages/ui_kit/` — Design system: `VioTheme.darkTheme`, `VioColors` constants
- `packages/protos/` — Protobuf `.proto` files, single source of truth for API types
- `backend/` — Bun + ConnectRPC server, Drizzle ORM + PostgreSQL

### Communication Flow
Protos (`packages/protos/vio/v1/*.proto`) → codegen → TypeScript services (`backend/src/gen/`) + Dart gRPC clients (`apps/client/lib/src/gen/`). Flutter uses gRPC-Web; backend serves ConnectRPC (HTTP/2). Conversion layer: `apps/client/lib/src/core/grpc/proto_converter.dart`.

### Data Flow: Canvas ↔ Backend
`CanvasBloc` holds shapes in-memory → `_CanvasVersionControlBridge` (in `app.dart`) syncs shapes bidirectionally between `CanvasBloc` and `VersionControlBloc` → `GrpcCanvasRepository` auto-syncs to backend every 5s with last-write-wins. Branch switches pause auto-sync via `beginBranchSwitch()`/`endBranchSwitch()`.

## Development Workflows

```bash
# Setup
fvm install && fvm use && dart pub global activate melos && melos bootstrap

# Start PostgreSQL (required before backend)
podman machine start
podman compose up -d postgres

# Run (use --dart-define-from-file for env config)
melos run run:client:web              # Flutter web (dev config)
cd backend && bun run dev             # Backend with watch mode (port 4000/4001)

# Codegen (proto → Dart + TypeScript)
cd backend && bun run proto:generate  # Generates both backend/src/gen/ and apps/client/lib/src/gen/

# Database
cd backend && bun run db:push         # Push Drizzle schema to PostgreSQL
cd backend && bun run db:seed         # Seed demo data

# Quality
melos run analyze                     # Static analysis across all packages
cd backend && bun run format          # Biome formatter for backend
```

VS Code tasks exist for: "Start Backend Server", "Database Push", "Run Build Runner", "Melos Bootstrap".

## Key Conventions

### BLoC Pattern
- Events/state use `part` directive from the bloc file (e.g., `part 'canvas_event.dart'` in `canvas_bloc.dart`)
- Events are `sealed class` with `EquatableMixin`; state is immutable with `copyWith()`
- Canvas uses **manual undo/redo stack** (not `ReplayBloc`) — see `_undoStack`/`_redoStack` in `canvas_bloc.dart`
- DI via `ServiceLocator` singleton initialized in `main()`, provides gRPC clients and repositories

### Shape Model (packages/core)
Shapes use a **6-parameter affine transform matrix** (`Matrix2D`):
```dart
// Position: use transform.e / transform.f — NOT x, y directly
shape.copyWith(transform: shape.transform.copyWith(e: newX, f: newY))

// Rotation: keep BOTH transform matrix AND rotation field in sync
Matrix2D.rotationAt(angleDeg, centerX, centerY)

// Duplicate: always generate new UUID
shape.duplicate(newId: Uuid().v4(), offsetX: 10, offsetY: 10)
```
Shape hierarchy: `Shape` (abstract) → `RectangleShape`, `EllipseShape`, `TextShape`, `FrameShape`, `GroupShape`, `PathShape`, `ImageShape`, `SvgShape`, `BoolShape`. Each has specific geometric params (e.g., `r1`–`r4` corner radii on rectangles). `sortOrder` controls z-order among siblings. Shapes support `ShapeShadow`, `ShapeBlur`, gradient fills, and fill/stroke visibility toggling.

### Asset System
- `AssetBloc` manages graphics + palette colors via gRPC `AssetServiceClient`
- Upload flow: `AssetUploaded` event → backend processes with `sharp` (resize, format) → stores binary → optionally creates `ImageShape`/`SvgShape` on canvas via `createShapeOnCanvas` flag
- Binary data cached in `AssetState.assetDataCache` for rendering
- Backend enforces 10MB limit and MIME validation (`backend/src/services/asset.ts`)

### Backend (ConnectRPC + Drizzle)
- Services in `backend/src/services/` implement `ServiceImpl<T>` from `@connectrpc/connect`
- Proto messages created via `create(SchemaName, { ... })` from `@bufbuild/protobuf`
- DB schema in `backend/src/db/schema/index.ts` — shapes store transform as 6 separate columns (`transform_a` through `transform_f`), type-specific props as `jsonb`
- Use Biome for lint/format (not ESLint/Prettier). Config: `backend/biome.json`
- Three-way merge for version control conflicts at property level (see `backend/src/services/merge.ts`)

### Theme
Always use `VioColors` from `packages/ui_kit/`: `primary` (#4C9AFF), `background` (#0D1117), `surface` (#161B22), `textPrimary` (#E6EDF3). Theme applied via `VioTheme.darkTheme`.

### Environment Config
Flutter environments configured via `apps/client/config/{dev,staging,production}.json` passed with `--dart-define-from-file`. Controls `GRPC_HOST`, `GRPC_PORT`, `GRPC_WEB_PORT`, `USE_TLS`.

## Key Files
- **PLAN.md** / **PROGRESS.md** / **SKILL.md** — Roadmap, daily log, and tech stack reference (repo root)
- **apps/client/lib/src/features/canvas/bloc/canvas_bloc.dart** — Core canvas logic (~3300 lines)
- **packages/core/lib/src/models/shape.dart** — Shape base class hierarchy
- **apps/client/lib/src/core/grpc/proto_converter.dart** — Proto ↔ domain conversion
- **apps/client/lib/src/app.dart** — BLoC wiring and `_CanvasVersionControlBridge`
- **backend/src/db/schema/index.ts** — Full DB schema (projects, branches, commits, snapshots, shapes, pull_requests)
- **backend/src/services/merge.ts** — Three-way merge algorithm for version control
- **packages/protos/vio/v1/** — All `.proto` definitions
