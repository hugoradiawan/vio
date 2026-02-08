# Vio - Skills & Technology Reference

## Core Stack

| Area | Technology | Where Used |
|------|-----------|------------|
| **Frontend** | Flutter (Dart) | `apps/client/` — Web + Windows desktop |
| **Backend** | Bun (TypeScript) | `backend/` — gRPC server |
| **Database** | PostgreSQL | Via Drizzle ORM, runs in Podman container |
| **Protocol** | Protobuf + gRPC | `packages/protos/vio/v1/` — shared API contract |
| **Monorepo** | Melos | Root `pubspec.yaml` — workspace orchestration |

## Frontend Skills

### Flutter / Dart
- **State management**: `flutter_bloc` — events, states, `copyWith()` immutability
- **Custom painting**: `CustomPainter` for canvas rendering (shapes, selection boxes, grid, rulers, snap guides)
- **Affine transforms**: `Matrix2D` (6-param matrix) for position, rotation, scale — see `packages/core/lib/src/math/matrix2d.dart`
- **Hit testing**: Point-in-shape algorithms per shape type (rect, ellipse, frame)
- **Gesture handling**: Pointer events for pan/zoom/draw/resize/rotate, trackpad vs mouse disambiguation
- **Keyboard shortcuts**: `HardwareKeyboard.instance` for global focus-independent shortcuts
- **Platform channels**: Conditional imports for web vs native gRPC transport (`grpc_channel_web.dart` / `grpc_channel_native.dart`)

### Architecture Patterns
- **Feature-first structure**: `features/{canvas,version_control,workspace,assets}/` each with `bloc/`, `presentation/`
- **BLoC pattern**: `sealed class` events with `EquatableMixin`, immutable state, `part` directives
- **Manual undo/redo**: Custom stack instead of `ReplayBloc` — filters shape changes from interaction state
- **Cross-BLoC sync**: `_CanvasVersionControlBridge` widget using `MultiBlocListener` (avoids direct BLoC coupling)
- **DI**: `ServiceLocator` singleton initialized in `main()`, provides gRPC clients and repositories
- **Environment config**: `--dart-define-from-file` with `config/{dev,staging,production}.json`

### Domain Knowledge
- **Shape hierarchy**: Abstract `Shape` → `RectangleShape`, `EllipseShape`, `TextShape`, `FrameShape`, `GroupShape`, `PathShape`, `ImageShape`, `SvgShape`, `BoolShape`
- **Transform math**: Position via `transform.e`/`transform.f`, rotation via `Matrix2D.rotationAt()`, keeping `transform` matrix and `rotation` field in sync
- **Z-ordering**: `sortOrder` within parent container (group/frame/root)
- **Canvas viewport**: Infinite canvas with grid that scales with zoom, coordinate system conversion (screen ↔ canvas)

## Backend Skills

### Bun + ConnectRPC
- **ConnectRPC services**: `ServiceImpl<T>` from `@connectrpc/connect`, registered via `router.service()`
- **Proto message creation**: `create(SchemaName, { ... })` from `@bufbuild/protobuf` (v2)
- **Dual-port server**: HTTP/2 on port 4000 (native gRPC), HTTP/1.1 on port 4001 (gRPC-Web for Flutter web)
- **CORS**: Custom origin validation for localhost development

### Drizzle ORM + PostgreSQL
- **Schema definition**: `pgTable()` with typed columns, indexes, foreign key references — see `backend/src/db/schema/index.ts`
- **Bun SQL adapter**: `drizzle-orm/bun-sql` with Bun's native SQL client
- **Migrations**: `drizzle-kit generate` / `drizzle-kit push`
- **JSON columns**: `jsonb` for fills, strokes, shape-specific properties
- **Transform storage**: 6 separate `doublePrecision` columns (`transform_a` through `transform_f`)

### Version Control System
- **Three-way merge**: Property-level conflict detection — `backend/src/services/merge.ts`
- **Merge strategies**: Fast-forward (pointer update) and auto (three-way with conflicts)
- **Snapshot model**: Commits reference immutable snapshots of full canvas state
- **PR workflow**: Open → merged, or open → closed → reopened

## Protobuf / Codegen

- **Proto definitions**: `packages/protos/vio/v1/*.proto` — 9 proto files (shape, canvas, branch, commit, pullrequest, asset, auth, project, common)
- **Buf CLI**: `buf generate` configured via `packages/protos/buf.gen.yaml`
- **Dual codegen**: `protoc-gen-es` → TypeScript (backend), `protoc-gen-dart` → Dart gRPC stubs (client)
- **Generated output**: `backend/src/gen/` (TS) and `apps/client/lib/src/gen/` (Dart) — never edit these

## Infrastructure

| Tool | Purpose | Command |
|------|---------|---------|
| FVM | Flutter SDK version pinning | `fvm install && fvm use` |
| Melos | Monorepo workspace scripts | `melos bootstrap`, `melos run analyze` |
| Podman | Container runtime (PostgreSQL) | `podman machine start && podman compose up -d postgres` |
| Biome | Backend lint + format | `cd backend && bun run format` |
| Drizzle Kit | DB migrations | `cd backend && bun run db:push` |
| Buf | Protobuf codegen | `cd backend && bun run proto:generate` |

## Testing

| Layer | Framework | Run |
|-------|-----------|-----|
| Flutter | `flutter_test` | `melos run test` |
| Backend | Bun test runner | `cd backend && bun test` |
| Core package | `flutter_test` | `cd packages/core && flutter test` |
| UI Kit | `flutter_test` | `cd packages/ui_kit && flutter test` |

## Design Knowledge

Understanding these design tool concepts helps when working on the canvas:

- **Artboards/Frames**: Container shapes that clip content, similar to Figma frames or Sketch artboards
- **Selection rect (selrect)**: Axis-aligned bounding box used for hit testing and selection
- **Marquee selection**: Drag-to-select region that selects all intersecting shapes
- **Snap-to-grid / snap guides**: Visual alignment aids during shape manipulation
- **Layers panel**: Tree view of shape hierarchy with visibility (eye) and lock controls
- **Z-order operations**: Bring to front, send to back — manipulates `sortOrder` within container

## Reference Codebases

These are checked into the repo as shallow clones for reference (not part of Vio's build):

| Directory | Purpose |
|-----------|---------|
| `penpot/` | Penpot source — shape model, matrix math, rendering patterns |
| `gitea/` | Gitea source — Git version control workflows, PR/merge patterns |
