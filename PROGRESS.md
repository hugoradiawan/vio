# Vio - Development Progress Log

## Format
`[Date] - [Task] - [Status] - [Notes/Blockers]`

---

## 2026-02-08

### Session: Asset Management System

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-02-08 | Implement AssetBloc with gRPC AssetServiceClient | ✅ Completed | CRUD for graphics and palette colors |
| 2026-02-08 | Create ProjectAsset / ProjectColor domain models | ✅ Completed | In `packages/core/lib/src/models/project_asset.dart` |
| 2026-02-08 | Build Assets tab UI with drag-and-drop upload | ✅ Completed | Graphics section, Colors section, search, `desktop_drop` + file picker |
| 2026-02-08 | Implement backend AssetService | ✅ Completed | Upload with `sharp` image processing, CRUD, 10MB limit, MIME validation |
| 2026-02-08 | Extend ProtoConverter for assets | ✅ Completed | `assetFromProto()`, `projectColorFromProto()` |
| 2026-02-08 | Update copilot-instructions.md and README.md | ✅ Completed | Corrected Elysia → ConnectRPC throughout |

### Changes Made

#### apps/client/lib/src/features/assets/
- `bloc/asset_bloc.dart` - **New** (431 lines) - Full CRUD via gRPC `AssetServiceClient`:
  - Events: `AssetsLoadRequested`, `AssetUploaded`, `AssetDeleted`, `AssetRenamed`, `AssetDataRequested`, `ColorCreated`, `ColorUpdated`, `ColorDeleted`, `AssetSearchChanged`, `AssetViewModeToggled`
  - State: `AssetState` with `assetDataCache` (binary data for canvas rendering), search/filter, grid/list view mode
  - Integrates with `CanvasBloc` — `createShapeOnCanvas` flag on upload adds image/SVG shapes directly
- `presentation/widgets/assets_tab.dart` - **New** (1143 lines) - Graphics section, Colors section, Components/Typographies placeholders, search bar, drag-and-drop upload, file picker

#### packages/core/lib/src/models/
- `project_asset.dart` - **New** - `ProjectAsset` and `ProjectColor` domain models

#### backend/src/services/
- `asset.ts` - **New** (596 lines) - Upload with `sharp` image processing, CRUD for assets/colors, 10MB limit, MIME validation

---

## 2026-02-07

### Session: Gradient Fills + Discard Changes

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-02-07 | Implement gradient fill editor | ✅ Completed | Linear + radial gradients with color stops |
| 2026-02-07 | Add discard all changes in version control | ✅ Completed | `AllChangesDiscarded` event reverts shapes to base state |
| 2026-02-07 | Code readability refactoring | ✅ Completed | Consistency pass across multiple files |

### Changes Made

#### apps/client/lib/src/features/workspace/presentation/widgets/
- `gradient_editor.dart` - **New** - Gradient fill editor in shape properties panel

#### apps/client/lib/src/features/version_control/
- `bloc/version_control_bloc.dart` - Added `AllChangesDiscarded` event handler — full shape revert to base state

---

## 2026-02-03 – 2026-02-04

### Session: Resizable Panels + Shadow/Blur Effects

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-02-03 | Add resizable left and right panels | ✅ Completed | Drag handles with `LeftPanelWidthChanged` / `RightPanelWidthChanged` events |
| 2026-02-04 | Implement shadow and blur effects | ✅ Completed | `ShapeShadow` / `ShapeBlur` models, rendering, property editor, proto converter |

### Changes Made

#### apps/client/lib/src/features/workspace/
- `presentation/widgets/resizable_panel_handle.dart` - **New** - Drag handle widget for panel resizing
- `bloc/workspace_bloc.dart` - Added `LeftPanelWidthChanged` / `RightPanelWidthChanged` events

#### packages/core/lib/src/models/
- `shape.dart` - Added `ShapeShadow` and `ShapeBlur` model classes

#### apps/client/lib/src/features/canvas/presentation/painters/
- `shape_painter.dart` - Shadow and blur rendering support

#### apps/client/lib/src/core/grpc/
- `proto_converter.dart` - Shadow/blur proto conversion

---

## 2026-02-02

### Session: Fill/Stroke Visibility

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-02-02 | Add fill/stroke visibility toggle | ✅ Completed | Hidden property in shape property editor |
| 2026-02-02 | Formatting cleanup | ✅ Completed | gRPC channel and repository files |

---

## 2026-02-01

### Session: ConnectRPC Migration + gRPC Client Infrastructure

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-02-01 | Migrate backend from Elysia REST to ConnectRPC | ✅ Completed | `@connectrpc/connect` + `connectNodeAdapter` with HTTP/2 |
| 2026-02-01 | Implement dual-port server | ✅ Completed | Port 4000 (native gRPC) + 4001 (gRPC-Web for Flutter web) |
| 2026-02-01 | Create GrpcClient singleton | ✅ Completed | Manages channel + 8 service clients |
| 2026-02-01 | Implement platform-agnostic gRPC channels | ✅ Completed | Conditional imports: gRPC-Web/XHR for web, native HTTP/2 for desktop |
| 2026-02-01 | Create AppConfig from dart-define-from-file | ✅ Completed | `AppEnvironment` enum (dev/staging/production) with per-env defaults |
| 2026-02-01 | Create ServiceLocator DI container | ✅ Completed | Singleton initializing GrpcClient, all service clients, GrpcCanvasRepository |
| 2026-02-01 | Create environment config files | ✅ Completed | `config/{dev,staging,production}.json` |
| 2026-02-01 | Wire up main.dart lifecycle | ✅ Completed | AppConfig → ServiceLocator → HydratedStorage → AppLifecycleListener |

### Changes Made

#### backend/src/
- `index.ts` - **Rewritten** - ConnectRPC router with `router.service()` for all 8 services, HTTP/2 server, CORS for Flutter web

#### apps/client/lib/src/core/grpc/
- `grpc_client.dart` - **New** - `GrpcClient` singleton managing channel + 8 service clients
- `grpc_channel.dart` - **New** - Platform-agnostic channel factory (conditional import)
- `grpc_channel_web.dart` - **New** - gRPC-Web/XHR transport for Flutter web
- `grpc_channel_native.dart` - **New** - Native HTTP/2 transport for desktop

#### apps/client/lib/src/core/config/
- `app_config.dart` - **New** - `AppConfig` with `AppEnvironment` enum, `fromEnvironment()` factory

#### apps/client/lib/src/core/
- `service_locator.dart` - **New** - Singleton DI container

#### apps/client/config/
- `dev.json` / `staging.json` / `production.json` - **New** - Environment-specific gRPC host/port/TLS settings

### Key Design Decisions
1. **Dual-port server**: Native gRPC on port 4000, gRPC-Web on port 4001 — Flutter web requires gRPC-Web (XHR), desktop uses native HTTP/2
2. **Conditional imports**: `grpc_channel.dart` uses `dart:io`-based conditional import to select web vs native transport at compile time
3. **ServiceLocator pattern**: All gRPC clients created once in `main()`, accessed via `ServiceLocator.instance` throughout the app

---

## 2026-01-31

### Session: Canvas↔VersionControl Bridge

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-31 | Create _CanvasVersionControlBridge widget | ✅ Completed | Bidirectional sync between CanvasBloc and VersionControlBloc |
| 2026-01-31 | Add ShapesReplaced event to CanvasBloc | ✅ Completed | Efficient bulk shape replacement for branch switches |
| 2026-01-31 | Add branch switch protection to GrpcCanvasRepository | ✅ Completed | `beginBranchSwitch()` / `endBranchSwitch()` pauses auto-sync |
| 2026-01-31 | Add setShapesFromSnapshot to repository | ✅ Completed | Replaces internal state atomically, clears pending ops |

### Changes Made

#### apps/client/lib/src/
- `app.dart` - Added `_CanvasVersionControlBridge` widget using `MultiBlocListener`:
  - Canvas→VC: sends `CanvasShapesChanged` whenever shapes change
  - VC→Canvas: dispatches `ShapesReplaced` on branch switch or initial load completion
- `features/canvas/bloc/canvas_bloc.dart` - Added `ShapesReplaced` event handler
- `core/repositories/grpc_canvas_repository.dart` - Added `beginBranchSwitch()`, `endBranchSwitch()`, `setShapesFromSnapshot()`

### Key Design Decisions
1. **Bridge widget over direct BLoC coupling**: `_CanvasVersionControlBridge` uses `MultiBlocListener` to avoid CanvasBloc depending on VersionControlBloc directly
2. **Branch switch safety**: Auto-sync paused during switch to prevent stale data from overwriting new branch state

---

## 2026-01-27

### Session: Version Control Frontend UI

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-27 | Implement VersionControlBloc | ✅ Completed | 1458 lines, 27+ events, full branch/commit/PR state management |
| 2026-01-27 | Build branch selector header + list panel | ✅ Completed | Branch switching with uncommitted changes detection |
| 2026-01-27 | Build commit panel + dialog + history list | ✅ Completed | Shape-level change tracking, staging, commit creation |
| 2026-01-27 | Build PR list + merge/close UI | ✅ Completed | Full PR lifecycle in UI |
| 2026-01-27 | Build conflict resolution dialog | ✅ Completed | Interactive property-level conflict resolution |
| 2026-01-27 | Build branch settings dialog | ✅ Completed | Rename, protection settings |
| 2026-01-27 | Add PreferencesService | ✅ Completed | Persists last-selected branch per project |

### Changes Made

#### apps/client/lib/src/features/version_control/
- `bloc/version_control_bloc.dart` - **New** (1458 lines) - Full VC state management:
  - VersionControlStatus enum: `initial`, `loading`, `ready`, `committing`, `switching`, `merging`, `error`
  - Change detection: compares `baseShapes` (HEAD snapshot) vs `currentShapes` (live canvas)
  - Branch switch protection: `pendingSwitchBranchId` triggers confirmation when uncommitted changes exist
  - Accesses gRPC clients via `ServiceLocator.instance`
- `bloc/version_control_event.dart` - 27+ events including `BranchSwitchRequested`, `CommitCreateRequested`, `PullRequestMergeRequested`, `CanvasShapesChanged`, `AllChangesDiscarded`, `CommitAndSwitchRequested`
- `bloc/version_control_state.dart` - Immutable state with branches, commits, PRs, staging set, base/current shapes
- `presentation/widgets/version_control_tab.dart` - **New** - Main VC tab with collapsible sections
- `presentation/widgets/branch_selector_header.dart` - **New** - Branch dropdown with switch confirmation
- `presentation/widgets/branch_list_panel.dart` - **New** - Branch list with create/delete actions
- `presentation/widgets/commit_dialog.dart` - **New** - Commit message input dialog
- `presentation/widgets/commit_panel.dart` - **New** - Staged changes panel
- `presentation/widgets/commit_history_list.dart` - **New** - Commit log with checkout/revert actions
- `presentation/widgets/pull_request_list.dart` - **New** - PR list with merge/close actions
- `presentation/widgets/conflict_resolution_dialog.dart` - **New** - Property-level conflict resolution
- `presentation/widgets/branch_settings_dialog.dart` - **New** - Branch rename/protection

#### apps/client/lib/src/core/services/
- `preferences_service.dart` - **New** - SharedPreferences wrapper for persisting branch selection

---

## 2026-01-26

### Session: Git-like Version Control Implementation

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-26 | Clone Gitea as reference implementation | ✅ Completed | Shallow clone with depth=1 |
| 2026-01-26 | Add gitea/ to .gitignore | ✅ Completed | |
| 2026-01-26 | Define proto RPCs for version control | ✅ Completed | branch.proto, commit.proto, pullrequest.proto, common.proto |
| 2026-01-26 | Regenerate TypeScript from protos | ✅ Completed | ts-proto codegen |
| 2026-01-26 | Create merge.ts utility | ✅ Completed | Property-level three-way merge with conflict detection |
| 2026-01-26 | Extend BranchService with merge operations | ✅ Completed | mergeBranches, compareBranches |
| 2026-01-26 | Extend CommitService with checkout/revert | ✅ Completed | checkoutCommit, revertCommit, cherryPick |
| 2026-01-26 | Implement PullRequestService | ✅ Completed | 10 RPCs for full PR workflow |
| 2026-01-26 | Fix lint and type errors | ✅ Completed | Non-null assertions, import fixes, response type fixes |

### Changes Made

#### packages/protos/vio/v1/
- `branch.proto` - Added MergeBranchesRequest/Response, CompareBranchesRequest/Response
- `commit.proto` - Added CheckoutCommitRequest/Response, RevertCommitRequest/Response, CherryPickRequest/Response
- `pullrequest.proto` - New file with 10 RPCs for full PR lifecycle
- `common.proto` - Added ShapeConflict, PropertyConflict, ConflictResolution, ConflictChoice

#### backend/src/services/
- `merge.ts` - **New file** - Core merge utilities:
  - `findCommonAncestor()` - Find common ancestor commit for two branches
  - `performThreeWayMerge()` - Property-level three-way merge with conflict detection
  - `canFastForward()` - Check if fast-forward merge is possible
  - `countCommitsDivergence()` - Count commits ahead/behind between branches
  - `createMergeCommit()` - Create merge commit with merged snapshot
  - `performFastForward()` - Execute fast-forward merge
  - `getSnapshotData()` - Helper to fetch snapshot data

- `branch.ts` - Extended with:
  - `mergeBranches()` - Merge source into target with auto/fast-forward strategy
  - `compareBranches()` - Compare two branches for ahead/behind counts

- `commit.ts` - Extended with:
  - `checkoutCommit()` - Create new branch from specific commit
  - `revertCommit()` - Create revert commit undoing changes
  - `cherryPick()` - Apply commit changes to another branch

- `pullrequest.ts` - **New file** - Full PR service:
  - `listPullRequests()` - List PRs with filtering by status
  - `getPullRequest()` - Get single PR with branch and commit details
  - `createPullRequest()` - Create new PR between branches
  - `updatePullRequest()` - Update PR title/description
  - `mergePullRequest()` - Execute merge (auto strategy)
  - `closePullRequest()` - Close PR without merging
  - `reopenPullRequest()` - Reopen closed PR
  - `listReviewers()` - List PR reviewers
  - `checkMergeStatus()` - Check if PR is mergeable with conflict detection
  - `resolveConflicts()` - Apply conflict resolutions

- `index.ts` - Added exports for new services

#### backend/src/
- `index.ts` - Registered PullRequestService with gRPC server

### Key Design Decisions

1. **Property-level Merge (Option B)**: Conflicts detected at property level, not shape level.
   - More granular conflict detection
   - Allows partial auto-merges (e.g., position changes merge with color changes)

2. **Three-way Merge Algorithm**:
   - Find common ancestor commit
   - Compare base→source and base→target changes
   - Only conflict when same property changed differently on both sides

3. **Merge Strategies**:
   - Auto: Three-way merge with conflict detection
   - Fast-forward: If target is ancestor of source, just update pointer

4. **PR Status Flow**: open → merged OR open → closed → open (reopen)

---

## 2026-01-24

### Session: Editor UX + Web Performance

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-24 | Add Penpot-like context menus (canvas + layers) | ✅ Completed | Right click selects-under-cursor; cut/copy/paste + group/ungroup + z-order |
| 2026-01-24 | Add explicit z-order (`sortOrder`) | ✅ Completed | Render/hit-test order derived from sortOrder within containers |
| 2026-01-24 | Improve web perf (grid batching, hover/snap throttling) | ✅ Completed | Reduced draw calls; cached snap index per drag |
| 2026-01-24 | Rulers + panels UX shortcuts | ✅ Completed | Ruler context menu; `Ctrl+\\` zen mode toggle |
| 2026-01-24 | Layers row hover-only controls | ✅ Completed | Eye/lock buttons only show on row hover unless hidden/locked |

### Changes Made

#### apps/client/lib/src/features/workspace/
- `presentation/workspace_page.dart` - Added `Ctrl+\\` zen mode shortcut; kept panel shortcuts
- `bloc/workspace_bloc.dart` / `bloc/workspace_state.dart` / `bloc/workspace_event.dart` - Zen mode state + restore previous visibility

#### apps/client/lib/src/features/canvas/
- `presentation/canvas_view.dart` - Canvas context menu + web native menu suppression; ruler context menu routing
- `presentation/painters/grid_painter.dart` - Batched grid lines into paths for fewer draw calls
- `bloc/canvas_bloc.dart` - Snap index cached per drag session + hover/snap throttling

#### apps/client/lib/src/features/canvas/presentation/widgets/
- `layer_item.dart` / `layer_tree.dart` - Layer row context menu; hover-only eye/lock controls (always visible when hidden/locked)

#### packages/core/lib/src/models/
- `shape.dart` (+ shape types) - Added `sortOrder` for explicit z-ordering

## 2026-01-16

### Session: Canvas Horizontal Pan Shortcut

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-16 | Add Shift+mouse wheel horizontal pan | ✅ Completed | Shift + wheel maps vertical scroll to horizontal pan; Ctrl + wheel still zooms |

### Changes Made

#### apps/client/lib/src/features/canvas/presentation/
- `canvas_view.dart` - Updated pointer signal handling so Shift + mouse wheel pans the viewport horizontally

### Session: Text Element Enhancements

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-16 | Enhance text element (editing + typography) | ✅ Completed | Inline edit overlay, typography controls, Google Fonts rendering, stable box sizing with grow-only relayout |

### Changes Made

#### packages/core/lib/src/models/
- `text_shape.dart` - Added persistent typography fields (line height multiplier, letter spacing %, text align)

#### apps/client/lib/src/features/canvas/
- `canvas_bloc.dart` - Improved text editing lifecycle (draft text, commit/cancel behavior, grow-only sizing)

#### apps/client/lib/src/features/canvas/presentation/
- `canvas_view.dart` - Text overlay editing + measurement updated to keep alignment/width constraints consistent

#### apps/client/lib/src/features/canvas/presentation/painters/
- `shape_painter.dart` - Text rendering via Google Fonts with fixed-width layout for correct alignment + clipping

#### apps/client/lib/src/features/workspace/presentation/widgets/
- `property_sections.dart` - Typography inspector (font/size/align/line height/letter spacing) + relayout after changes

### Session: Frame Preset Sizes

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2026-01-16 | Add frame preset sizes (tool default + apply to selection) | ✅ Completed | Default preset applies on click-to-create; drag-to-create ignores preset; applying preset changes only width/height |

### Changes Made

#### apps/client/lib/src/features/canvas/
- `models/frame_presets.dart` - Preset catalog (Penpot-inspired + extended list) + lookup helper
- `bloc/canvas_bloc.dart` - Click-to-create preset frames + preset disarm on drag
- `presentation/canvas_view.dart` - Pass default preset size into `PointerDown`

#### apps/client/lib/src/features/workspace/
- `presentation/widgets/frame_preset_picker.dart` - Category + preset picker widget
- `presentation/widgets/right_panel.dart` - Default preset UI (Frame tool) + multi-select frame preset apply
- `presentation/widgets/shape_properties.dart` - Frame preset apply for selected frame
- `bloc/workspace_state.dart` / `bloc/workspace_event.dart` / `bloc/workspace_bloc.dart` - Persist default frame preset selection

## 2025-01-03

### Session 6: Shape Rotation Implementation

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2025-01-03 | Add initialRotationAngle to CanvasState | ✅ Completed | Tracks starting angle for delta calculation |
| 2025-01-03 | Add shiftPressed to PointerMove event | ✅ Completed | For 15° angle snapping |
| 2025-01-03 | Implement rotation via handle drag | ✅ Completed | Single shape rotates around own center, multi-select around selection center |
| 2025-01-03 | Update rotation field on rotate | ✅ Completed | Both transform matrix and rotation field updated |
| 2025-01-03 | Fix move behavior for rotated shapes | ✅ Completed | Updates transform translation (e,f) instead of x,y |
| 2025-01-03 | Fix rotation input in properties panel | ✅ Completed | Now applies rotation transform, not just field |

### Changes Made

#### apps/client/lib/src/features/canvas/bloc/
- `canvas_state.dart` - Added `initialRotationAngle` field with `clearInitialRotationAngle` flag
- `canvas_event.dart` - Added `shiftPressed` parameter to `PointerMove` event
- `canvas_bloc.dart` - Implemented rotation logic:
  - Store initial angle on rotation start
  - Calculate delta angle during rotation
  - Shift key snaps to 15° increments
  - Apply `Matrix2D.rotationAt()` around appropriate center
  - Update both `transform` and `rotation` fields
  - Move rotated shapes by updating transform translation (e,f)

#### apps/client/lib/src/features/canvas/presentation/
- `canvas_view.dart` - Pass `HardwareKeyboard.instance.isShiftPressed` to `PointerMove`

#### apps/client/lib/src/features/workspace/presentation/widgets/
- `shape_properties.dart` - Fixed `_updateRotation()` to apply rotation transform matrix

### Key Implementation Details
1. **Single vs Multi Rotation**: Single shape rotates around its own center, multi-select rotates all shapes around the selection's center point
2. **Shift Snapping**: Hold Shift while rotating to snap to 15° increments
3. **Transform + Field Sync**: Both `shape.transform` matrix and `shape.rotation` field are kept in sync
4. **Move After Rotate**: Rotated shapes update transform translation (e,f) instead of x,y to preserve rotation behavior
5. **Properties Panel**: Rotation input now computes delta angle and applies rotation matrix

---

## 2025-01-01

### Session 5: API Infrastructure & Backend Migration

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2025-01-01 | Migrate backend to Bun SQL | ✅ Completed | Replaced postgres.js with Bun's native SQL |
| 2025-01-01 | Update drizzle-orm to bun-sql adapter | ✅ Completed | drizzle-orm/bun-sql |
| 2025-01-01 | Remove unused packages | ✅ Completed | Removed postgres, zod (TypeBox already in use) |
| 2025-01-01 | Add Flutter HTTP client (dio) | ✅ Completed | dio: ^5.8.0 |
| 2025-01-01 | Create ApiClient base class | ✅ Completed | Dio wrapper with interceptors |
| 2025-01-01 | Create API configuration | ✅ Completed | ApiConfig, ApiEndpoints |
| 2025-01-01 | Create Shape DTOs | ✅ Completed | ShapeDto extension, ShapeFactory |
| 2025-01-01 | Create API services | ✅ Completed | Project, Branch, Canvas services |
| 2025-01-01 | Create CanvasRepository | ✅ Completed | Auto-sync with last-write-wins |

### Changes Made

#### backend/
- `package.json` - Removed `postgres` and `zod` packages (Elysia uses TypeBox)
- `src/db/index.ts` - Migrated to Bun native SQL:
  ```typescript
  import { SQL } from 'bun';
  import { drizzle } from 'drizzle-orm/bun-sql';
  const client = new SQL(connectionString);
  export const db = drizzle({ client, schema });
  ```
- `drizzle.config.ts` - Removed incorrect driver config

#### apps/client/lib/src/core/api/
- `api_client.dart` - Dio wrapper with logging/error interceptors, ApiException
- `api_config.dart` - ApiConfig (baseUrl), ApiEndpoints (all REST paths)
- `dto.dart` - Data transfer objects:
  - `ShapeDto` extension on Shape (toJson)
  - `ShapeFactory` (fromJson)
  - `ProjectDto`, `BranchDto`
  - `CanvasStateDto`, `SyncRequestDto`, `SyncResponseDto`
  - `SyncOperation`, `SyncOperationType`

#### apps/client/lib/src/core/api/services/
- `project_api_service.dart` - CRUD for projects
- `branch_api_service.dart` - CRUD for branches
- `canvas_api_service.dart` - Canvas state, sync, shape CRUD

#### apps/client/lib/src/core/repositories/
- `canvas_repository.dart` - Local state management with auto-sync:
  - 5-second sync interval
  - Pending operations queue
  - Last-write-wins conflict resolution
  - SyncStatus stream for UI feedback

### Key Design Decisions
1. **Bun SQL**: Using Bun's native SQL client for better performance and simpler setup
2. **No Zod**: Elysia already provides TypeBox (t.*) for validation - Zod was unused
3. **Auto-sync**: Changes sync every 5 seconds, with immediate local application
4. **Last-write-wins**: Simple conflict resolution - server version always wins
5. **Operation Queuing**: Shape operations tracked for efficient batch sync

### API Endpoint Structure
```
/projects
/projects/:id
/projects/:id/branches
/projects/:id/branches/:branchId
/projects/:id/branches/:branchId/canvas
/projects/:id/branches/:branchId/sync
/projects/:id/branches/:branchId/commits/:commitId/shapes
```

---

## 2025-01-01

### Session 4: Clipboard & Undo/Redo Implementation

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2025-01-01 | Add Shape.duplicate() method | ✅ Completed | Returns copy with new ID and optional offset |
| 2025-01-01 | Add clipboardShapes to CanvasState | ✅ Completed | Stores copied shapes for paste |
| 2025-01-01 | Implement Copy (Ctrl+C) | ✅ Completed | Copies selected shapes to state clipboard |
| 2025-01-01 | Implement Cut (Ctrl+X) | ✅ Completed | Copies then removes selected shapes |
| 2025-01-01 | Implement Paste (Ctrl+V) | ✅ Completed | Duplicates clipboard shapes with 10px offset |
| 2025-01-01 | Implement Duplicate (Ctrl+D) | ✅ Completed | In-place duplication with offset |
| 2025-01-01 | Implement Delete (Del/Backspace) | ✅ Completed | Removes selected shapes |
| 2025-01-01 | Implement manual Undo/Redo stack | ✅ Completed | Replaced ReplayBloc with custom stack |
| 2025-01-01 | Add global keyboard handler | ✅ Completed | HardwareKeyboard.instance for focus-independent shortcuts |

### Changes Made

#### packages/core/lib/src/models/
- `Shape` - Added `duplicate()` method with newId, offsetX, offsetY parameters

#### apps/client/lib/src/features/canvas/
- `canvas_state.dart` - Added `clipboardShapes` field for copy/paste storage
- `canvas_event.dart` - Added `CopySelected`, `CutSelected`, `PasteShapes`, `DuplicateSelected`, `DeleteSelected`, `Undo`, `Redo` events
- `canvas_bloc.dart` - Switched from ReplayBloc to Bloc with manual undo stack:
  - `_undoStack` / `_redoStack` for shape snapshots
  - `_pushUndoState()` called after each shape-modifying operation
  - `canUndo` / `canRedo` getters
  - Handlers for all clipboard and undo/redo events
- `canvas_view.dart` - Added `HardwareKeyboard.instance.addHandler()` for global shortcuts

### Key Implementation Details
1. **Manual Undo Stack**: Replaced ReplayBloc with custom implementation because ReplayBloc's `shouldReplay` wasn't suitable for filtering shape-only changes from interaction state changes.
2. **Global Keyboard Handler**: Used `HardwareKeyboard.instance.addHandler()` instead of `KeyboardListener` widget to ensure shortcuts work regardless of focus state.
3. **Clipboard Storage**: Shapes stored in state (not system clipboard) for simplicity. Future: integrate with system clipboard for cross-app paste.
4. **Undo State Tracking**: Each shape-modifying operation (move, add, remove, update, paste, duplicate, cut, delete) pushes to undo stack.

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Ctrl+C | Copy selected shapes |
| Ctrl+X | Cut selected shapes |
| Ctrl+V | Paste shapes |
| Ctrl+D | Duplicate selected shapes |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| Ctrl+Shift+Z | Redo (alternative) |
| Delete/Backspace | Delete selected shapes |
| Escape | Clear selection |

---

## 2025-01-01

### Session 3: Selection & Interaction Improvements

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2025-01-01 | Fix desktop zoom focal point | ✅ Completed | Zoom now follows cursor position |
| 2025-01-01 | Fix trackpad pan/zoom interference | ✅ Completed | Pan only when scale == 1.0 |
| 2025-01-01 | Implement shape dragging | ✅ Completed | Added moveBy() to Shape hierarchy |
| 2025-01-01 | Add InteractionMode.movingShapes | ✅ Completed | Separate mode for shape movement |
| 2025-01-01 | Fix marquee during drag | ✅ Completed | Only show dragRect in dragging mode |
| 2025-01-01 | Add shift+click multi-select | ✅ Completed | Toggle selection with shift key |

### Changes Made

#### packages/core/lib/src/models/
- `Shape` - Added abstract `x`, `y` getters and `moveBy(dx, dy)` method
- `RectangleShape` - Implemented `moveBy()` using `copyWith()`
- `EllipseShape` - Implemented `moveBy()` using `copyWith()`
- `FrameShape` - Implemented `moveBy()` using `copyWith()`

#### apps/client/lib/src/features/canvas/
- `canvas_state.dart` - Added `InteractionMode.movingShapes`, fixed `dragRect` getter
- `canvas_bloc.dart` - Updated pointer handlers for shape dragging
- `canvas_event.dart` - Added `shiftPressed` to `PointerDown` event
- `canvas_view.dart` - Fixed zoom/pan interference, pass shift key state

### Key Fixes
1. **Desktop Zoom**: Trackpad was sending both scale and panDelta during zoom, causing zoom to fight against pan. Fixed by only applying pan when NOT zooming.
2. **Shape Dragging**: Base `Shape` class didn't have position accessors. Added abstract `x`/`y` getters and `moveBy()` method to all shape types.
3. **Marquee During Drag**: `dragRect` was computed whenever `dragStart`/`currentPointer` were set. Fixed by checking `interactionMode == dragging`.

---

## 2024-12-31

### Session 2: Phase 1.3 & 1.4 Implementation

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2024-12-31 | Fix compilation errors | ✅ Completed | Fixed constructor parameter mismatches |
| 2024-12-31 | Create ShapePainter utility | ✅ Completed | Renders fills, strokes, gradients |
| 2024-12-31 | Create SelectionBoxPainter | ✅ Completed | Bounding box with 8 handles + rotation |
| 2024-12-31 | Create HitTest utility | ✅ Completed | Point-in-shape for rect, ellipse, frame |
| 2024-12-31 | Add shapes storage to CanvasBloc | ✅ Completed | Map<String, Shape> with events |
| 2024-12-31 | Implement click-to-select | ✅ Completed | Hit testing in _onPointerDown |
| 2024-12-31 | Implement marquee selection | ✅ Completed | Rect intersection in _onPointerUp |
| 2024-12-31 | Add test shapes | ✅ Completed | Frame, 2 rects, 2 ellipses |
| 2024-12-31 | Enable Windows platform | ✅ Completed | flutter create --platforms=windows |

### Components Created

#### apps/client/lib/src/features/canvas/presentation/painters/
- `ShapePainter` - Shape rendering utility
  - Solid and gradient fills
  - Stroke alignment (inside, center, outside)
  - Stroke caps and joins
  - Per-corner radii for rectangles

- `SelectionBoxPainter` - Selection visualization
  - Combined bounding box for multi-select
  - 8 resize handles (corners + edges)
  - Rotation handle with connecting line
  - Transform-aware bounds calculation

#### packages/core/lib/src/utils/
- `HitTest` - Hit-testing utility
  - `hitTestShape()` - Point-in-shape with transforms
  - `findShapesAtPoint()` - All shapes at point (top-first)
  - `findTopShapeAtPoint()` - Single top-most shape
  - `findShapesInRect()` - Marquee/rectangle selection
  - Per-shape-type algorithms (rect, ellipse, frame)

### Test Shapes Added
- Frame (artboard): 800x600, dark gray with border
- Rectangle 1: Blue with rounded corners (r=8)
- Rectangle 2: Green
- Ellipse 1: Red
- Rectangle 3: Yellow stroke only (inside alignment)
- Circle: Purple (ellipse with equal radii)

---

## 2024-12-30

### Session 1: Project Initialization

| Date | Task | Status | Notes/Blockers |
|------|------|--------|----------------|
| 2024-12-30 | Create PLAN.md | ✅ Completed | Comprehensive roadmap with 5 phases defined |
| 2024-12-30 | Create PROGRESS.md | ✅ Completed | Daily log initialized |
| 2024-12-30 | Initialize Melos monorepo | ✅ Completed | melos.yaml, pubspec.yaml, .fvmrc |
| 2024-12-30 | Configure FVM | ✅ Completed | Flutter 3.27.1 pinned |
| 2024-12-30 | Create apps/client | ✅ Completed | Flutter app with DI, workspace UI |
| 2024-12-30 | Create packages/core | ✅ Completed | Math, extensions, shape models |
| 2024-12-30 | Create packages/ui_kit | ✅ Completed | Theme system, design widgets |
| 2024-12-30 | Create features/canvas | ✅ Completed | Infinite canvas with grid/rulers |
| 2024-12-30 | Implement Shape models | ✅ Completed | Rectangle, Ellipse, Frame |

### Key Decisions Made
1. **Monorepo Structure**: Using Melos for Flutter workspace management
2. **State Management**: flutter_bloc with bloc_concurrency for canvas operations
3. **Rendering**: CustomPainter for high-performance canvas (not widget tree)
4. **Theme**: Blue Dark Mode as primary theme
5. **Version Control Model**: Git-like DAG with branches, commits, and PRs

### Architecture Notes
- Analyzed Penpot's ClojureScript source for domain logic reference
- Key files referenced:
  - `shape.cljc` - Shape model and types
  - `matrix.cljc` - 6-parameter affine transform
  - `viewport.cljs` - Viewport/viewbox management
  - `zoom.cljs` - Zoom implementation with scale matrix
  - `shapes.rs` - Rust/Skia rendering reference

### Components Created

#### packages/core
- `Matrix2D` - 6-parameter affine transformation
- `Point2D` - Immutable 2D point with vector ops
- `Rect2D` - Immutable rectangle with intersection/union
- `Shape` - Base shape class with fills, strokes, effects
- `RectangleShape` - Rectangle with corner radii
- `EllipseShape` - Ellipse/circle shape
- `FrameShape` - Container with auto-layout support

#### packages/ui_kit
- `VioColors` - Blue dark mode palette
- `VioTypography` - Inter font system
- `VioSpacing` - 8px grid spacing
- `VioTheme` - Material 3 dark theme
- `VioButton` - Primary/secondary/ghost/danger variants
- `VioIconButton` - Ghost/filled/outlined icons
- `VioTextField` - Standard + numeric input
- `VioPanel` - Collapsible sidebar panels
- `VioToolbar` - Tool selection toolbar

#### apps/client
- Main entry with DI configuration
- `WorkspaceBloc` - Tool, panel, zoom state
- `CanvasBloc` - Viewport, pointer, selection state
- `WorkspacePage` - Full workspace layout
- `TopToolbar` - Tools and actions
- `LeftPanel` - Layers and assets
- `RightPanel` - Properties inspector
- `BottomBar` - Zoom controls
- `CanvasView` - Infinite canvas with gestures
- `GridPainter` - Grid overlay
- `CanvasPainter` - Shape rendering

---

## Legend
- ✅ Completed
- 🔄 In Progress
- ⏳ Pending
- ❌ Blocked
- 🔴 Critical Issue
