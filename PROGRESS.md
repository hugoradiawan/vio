# Vio - Development Progress Log

## Format
`[Date] - [Task] - [Status] - [Notes/Blockers]`

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
