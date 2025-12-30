# Vio - Design & Prototyping Tool with Git-like Version Control

## Vision

Recreate the core functionality of Penpot (Open Source Design & Prototyping Tool) using Flutter for the frontend and Bun + Elysia for the backend. This implementation introduces a **Git-like Version Control System for Design** where users work on branches, commit changes, and merge via Pull Requests.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        MONOREPO (Melos)                         │
├─────────────────────────────────────────────────────────────────┤
│  apps/                                                          │
│  └── client/           # Flutter composition root (Web/Desktop) │
│                                                                 │
│  packages/                                                      │
│  ├── core/             # Shared utilities & base abstractions   │
│  ├── ui_kit/           # Design system (Blue Dark Mode theme)   │
│  └── protos/           # Protobuf definitions (Dart + TS gen)   │
│                                                                 │
│  features/                                                      │
│  ├── canvas/           # Infinite canvas & rendering engine     │
│  ├── version_control/  # Git-like VC (branches, commits, PRs)   │
│  ├── auth/             # Authentication & authorization         │
│  └── collaboration/    # Real-time presence & draft states      │
│                                                                 │
│  backend/                                                       │
│  └── server/           # Bun + Elysia API server                │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Frontend (Flutter)
- **Runtime**: Flutter (latest stable via FVM)
- **Architecture**: Feature-first Clean Architecture
- **State Management**:
  - `flutter_bloc` for business logic
  - `bloc_concurrency` for sequential drawing events
  - `hydrated_bloc` for persistence
  - `replay_bloc` for localized Undo/Redo
- **Rendering**: `CustomPainter` + Flow delegates for infinite canvas

### Backend (Bun + Elysia)
- **Runtime**: Bun (latest)
- **Framework**: ElysiaJS with `elysia-decorators`
- **Database**: PostgreSQL
- **ORM**: Drizzle ORM
- **Communication**: gRPC (connect-es) with Protobuf

### Shared
- **Protobuf**: Single source of truth for types
- **Code Generation**: Auto-generate Dart & TypeScript from `.proto` files

---

## Phase 1: Canvas Core & UI Foundation

### 1.1 Project Setup
- [x] Create PLAN.md documentation
- [x] Create PROGRESS.md daily log
- [x] Initialize Melos monorepo structure
- [x] Configure FVM for Flutter SDK pinning
- [x] Create `apps/client` Flutter app (Web/Desktop)
- [x] Create `packages/core` with base utilities
- [x] Create `packages/ui_kit` with design system

### 1.2 Infinite Canvas Implementation
- [x] Implement viewport transformation matrix (Translation + Scale)
- [x] Create grid system that scales with zoom level
- [x] Implement pan gestures (Mouse drag, Trackpad)
- [x] Implement zoom gestures (Mouse wheel, Trackpad pinch)
- [x] Add canvas coordinate system helpers

### 1.3 Shape Rendering Engine
- [x] Define Shape base model (id, type, selrect, transform, parent-id)
- [x] Implement Rectangle shape with CustomPainter
- [x] Implement Ellipse shape with CustomPainter
- [ ] Add fill and stroke support (rendering)
- [ ] Implement shape transform matrix (rotation, scale, skew) - rendering

### 1.4 Selection System
- [ ] Implement hit-testing for shapes
- [ ] Create selection rectangle (marquee) tool
- [ ] Add multi-selection support
- [ ] Implement selection bounding box with handles

### 1.5 Blue Dark Mode Theme
- [x] Define color palette (primary, surface, background)
- [x] Create themed widget components
- [x] Implement theme provider with bloc

---

## Phase 2: Backend & Data Layer

### 2.1 Backend Setup
- [x] Initialize Bun project with Elysia
- [x] Configure Drizzle ORM with PostgreSQL
- [x] Set up database migrations
- [x] Create base API structure with decorators

### 2.2 Database Schema
- [x] Create `users` table (via ownerId/authorId references)
- [x] Create `teams` table (via teamId reference)
- [x] Create `projects` table (single board per project)
- [x] Create `frames` table (artboards)
- [x] Create `shapes` table (all shape types with transforms)

### 2.3 Protobuf Definitions
- [ ] Define Shape message types
- [ ] Define Matrix/Transform messages
- [ ] Define File/Project messages
- [ ] Set up code generation scripts

### 2.4 REST API Endpoints
- [ ] Authentication endpoints (register, login, refresh)
- [x] Project CRUD endpoints
- [x] Shape CRUD endpoints
- [x] Shape batch operations endpoints

---

## Phase 3: Git-like Version Control

### 3.1 Core VC Data Model
- [x] Create `branches` table (pointer to commit hash)
- [x] Create `commits` table (snapshot of shape tree DAG)
- [x] Create `pull_requests` table
- [ ] Implement commit hash generation

### 3.2 Branch Operations
- [x] Create branch from commit
- [ ] Switch between branches (UI)
- [x] Delete branch
- [x] List branches for project

### 3.3 Commit Operations
- [ ] Stage changes (diff current vs last commit)
- [x] Create commit with message
- [ ] View commit history (log)
- [ ] Checkout specific commit

### 3.4 Merge Operations
- [ ] Create Pull Request (source → target branch)
- [ ] Implement Last-Write-Wins conflict resolution
- [ ] Merge PR into target branch
- [ ] Close/Cancel PR

### 3.5 Frontend VC UI
- [ ] Branch selector dropdown
- [ ] Commit panel with staged changes
- [ ] PR creation dialog
- [ ] Merge conflict resolution UI

---

## Phase 4: Real-time Collaboration

### 4.1 gRPC Streaming Setup
- [ ] Configure gRPC server with Bun
- [ ] Define streaming protobuf services
- [ ] Implement client-side gRPC connection

### 4.2 Presence System
- [ ] Broadcast cursor positions
- [ ] Show other users' cursors on canvas
- [ ] Display selection highlights for others
- [ ] User avatar indicators

### 4.3 Draft State Sync
- [ ] Implement draft changes before commit
- [ ] Sync drafts via bi-directional streaming
- [ ] Handle draft conflicts (soft merge)
- [ ] Draft expiration/cleanup

### 4.4 Notifications
- [ ] File subscription (join/leave)
- [ ] PR/Merge notifications
- [ ] Comment notifications (future)

---

## Phase 5: Advanced Features (Future)

### 5.1 Additional Shape Types
- [ ] Path/Pen tool
- [ ] Text with fonts
- [ ] Images
- [ ] Boolean operations (union, subtract, intersect)

### 5.2 Components & Libraries
- [ ] Create reusable components
- [ ] Component instances with overrides
- [ ] Shared libraries across projects

### 5.3 Export
- [ ] Export to SVG
- [ ] Export to PNG/JPEG
- [ ] Export to PDF

---

## Key Domain Concepts (From Penpot)

### Shape Model
```dart
class Shape {
  final String id;
  final String name;
  final ShapeType type;
  final Rect selrect;
  final List<Point> points;
  final Matrix transform;
  final Matrix transformInverse;
  final String? parentId;
  final String frameId;
  final bool? flipX;
  final bool? flipY;
}
```

### Shape Types
- `frame` - Artboard/container
- `group` - Shape grouping
- `rect` - Rectangle
- `circle` - Ellipse
- `path` - Vector path
- `text` - Text content
- `image` - Raster image
- `bool` - Boolean operation result

### Viewport Model
```dart
class Viewport {
  final Rect vbox;      // Visible area in world coordinates
  final Size vport;     // Physical viewport size
  final double zoom;    // Current zoom level
  final double zoomInverse;
}
```

### Transform Matrix (6-param affine)
```
| a  c  e |
| b  d  f |
| 0  0  1 |

a = scaleX, b = skewY, c = skewX, d = scaleY, e = translateX, f = translateY
```

---

## Skipped Features (Per Requirements)
- ❌ Design-to-Code export
- ❌ Inspect Mode
- ❌ Plugin System

---

## References

- Penpot Source: `/penpot/` directory
- Shape Types: `common/src/app/common/types/shape.cljc`
- Matrix Math: `common/src/app/common/geom/matrix.cljc`
- Viewport Logic: `frontend/src/app/main/data/workspace/viewport.cljs`
- Zoom Logic: `frontend/src/app/main/data/workspace/zoom.cljs`
- Rust Renderer: `render-wasm/src/shapes.rs`
