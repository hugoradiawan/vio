# Vio - AI Coding Instructions

## Project Overview
Vio is a **Penpot-inspired design & prototyping tool** with Git-like version control for designs. It uses a **Melos monorepo** with Flutter (client) and Bun + Elysia (backend).

## Architecture

### Monorepo Structure
- `apps/client/` - Flutter app (Web/Windows) - the composition root
- `packages/core/` - Shared models, math utilities (`Matrix2D`, `Shape` hierarchy)
- `packages/ui_kit/` - Design system with `VioTheme`, `VioColors` (blue dark mode)
- `backend/` - Bun + Elysia REST API with Drizzle ORM + PostgreSQL

### Flutter Architecture Pattern
**Feature-first Clean Architecture** in `apps/client/lib/src/features/`:
```
feature/
├── bloc/           # flutter_bloc state management (events, state, bloc)
├── models/         # Feature-specific models
├── presentation/   # Widgets and views
```

### Key Data Model
Shapes use a **6-parameter affine transform matrix** (`Matrix2D` in `packages/core/lib/src/math/`):
```dart
Matrix2D(a: scaleX, b: skewY, c: skewX, d: scaleY, e: translateX, f: translateY)
```
- Use `Matrix2D.rotationAt()` for rotation around center point
- Both `shape.transform` matrix AND `shape.rotation` field must stay in sync

## Development Workflows

### Setup
```bash
fvm install && fvm use           # Flutter SDK
dart pub global activate melos
melos bootstrap
```

### Common Commands
```bash
melos run run:client:web         # Run Flutter web
melos run run:client:windows     # Run Flutter desktop
bun run dev                      # Backend (from backend/)
bun run db:push                  # Push schema to database
melos run analyze                # Static analysis
```

### VS Code Tasks
Use existing tasks: "Start Backend Server", "Database Push", "Run Build Runner"

## Code Conventions

### BLoC Events & State
- Events in `canvas_event.dart` use `part` directive from bloc file
- State in `canvas_state.dart` is immutable with `copyWith()`
- Canvas uses manual undo/redo stack, NOT `ReplayBloc`

### Shape Operations
```dart
// Move: update transform translation (e, f), NOT x, y directly
shape.copyWith(transform: shape.transform.copyWith(e: newE, f: newF))

// Duplicate: always generate new UUID
shape.duplicate(newId: Uuid().v4(), offsetX: 10, offsetY: 10)
```

### API Layer
- DTOs in `apps/client/lib/src/core/api/dto.dart` - use `ShapeDto` extension and `ShapeFactory`
- Services wrap API calls in `core/api/services/`
- `CanvasRepository` handles auto-sync with 5-second interval, last-write-wins conflict resolution

### Backend (Elysia)
- Use TypeBox (`t.*`) for validation, NOT Zod
- Routes organized by resource in `backend/src/routes/`
- Database schema in `backend/src/db/schema/index.ts` using Drizzle ORM

### Theme & Colors
Always use `VioColors` constants from `packages/ui_kit/`:
```dart
VioColors.primary        // #4C9AFF - main accent
VioColors.background     // #0D1117 - darkest
VioColors.surface        // #161B22 - panels
VioColors.textPrimary    // #E6EDF3 - high emphasis text
```

## Important Files
- [PLAN.md](../PLAN.md) - Feature roadmap with checkboxes
- [PROGRESS.md](../PROGRESS.md) - Daily implementation log
- [canvas_bloc.dart](../apps/client/lib/src/features/canvas/bloc/canvas_bloc.dart) - Core canvas logic
- [shape.dart](../packages/core/lib/src/models/shape.dart) - Shape base class hierarchy
- [schema/index.ts](../backend/src/db/schema/index.ts) - Database schema

## Git-like Version Control (Planned)
Database models exist for `projects`, `branches`, `commits`, `snapshots` - enabling design versioning with branches/merges.
