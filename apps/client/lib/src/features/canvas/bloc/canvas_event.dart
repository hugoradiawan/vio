part of 'canvas_bloc.dart';

/// Tool intent for pointer interactions that need to be routed into the canvas
/// logic (kept minimal to avoid coupling CanvasBloc to WorkspaceBloc).
enum CanvasPointerTool {
  /// Default selection / manipulation behavior
  select,

  /// Drag-to-create shapes
  drawRectangle,
  drawEllipse,
  drawFrame,

  /// Click-to-create text
  drawText,
}

/// Base class for canvas events
sealed class CanvasEvent with EquatableMixin {
  const CanvasEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the canvas is first mounted with its size
class CanvasInitialized extends CanvasEvent {
  const CanvasInitialized({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  List<Object?> get props => [width, height];
}

/// Fired when the viewport is panned (translated)
class ViewportPanned extends CanvasEvent {
  const ViewportPanned({
    required this.deltaX,
    required this.deltaY,
  });

  final double deltaX;
  final double deltaY;

  @override
  List<Object?> get props => [deltaX, deltaY];
}

/// Fired when zoom level changes
class ViewportZoomed extends CanvasEvent {
  const ViewportZoomed({
    required this.scaleFactor,
    required this.focalX,
    required this.focalY,
  });

  /// Multiplicative scale factor (e.g., 1.1 for 10% zoom in)
  final double scaleFactor;

  /// Focal point X in screen coordinates
  final double focalX;

  /// Focal point Y in screen coordinates
  final double focalY;

  @override
  List<Object?> get props => [scaleFactor, focalX, focalY];
}

/// Fired to reset viewport to default state
class ViewportReset extends CanvasEvent {
  const ViewportReset();
}

/// Fired when pointer/mouse is pressed down on canvas
class PointerDown extends CanvasEvent {
  const PointerDown({
    required this.x,
    required this.y,
    this.button = 0,
    this.shiftPressed = false,
    this.tool = CanvasPointerTool.select,
    this.initialWidth,
    this.initialHeight,
  });

  /// X position in screen coordinates
  final double x;

  /// Y position in screen coordinates
  final double y;

  /// Mouse button (0 = left, 1 = middle, 2 = right)
  final int button;

  /// Whether shift key is pressed (for multi-select)
  final bool shiftPressed;

  /// Current tool intent (used for drawing tools)
  final CanvasPointerTool tool;

  /// Optional initial size for click-to-create (used by Frame presets).
  /// Values are in canvas coordinates.
  final double? initialWidth;
  final double? initialHeight;

  @override
  List<Object?> get props => [
        x,
        y,
        button,
        shiftPressed,
        tool,
        initialWidth,
        initialHeight,
      ];
}

/// Commit an active text edit session.
///
/// `width`/`height` should be the measured text bounds in canvas coordinates.
class TextEditCommitted extends CanvasEvent {
  const TextEditCommitted({
    required this.shapeId,
    required this.text,
    required this.width,
    required this.height,
  });

  final String shapeId;
  final String text;
  final double width;
  final double height;

  @override
  List<Object?> get props => [shapeId, text, width, height];
}

/// Update the measured bounds of the currently edited text shape.
///
/// This is used while typing (e.g., when pressing Enter to add a new line)
/// so the selection box can grow without committing the edit.
class TextEditLayoutChanged extends CanvasEvent {
  const TextEditLayoutChanged({
    required this.shapeId,
    required this.width,
    required this.height,
  });

  final String shapeId;
  final double width;
  final double height;

  @override
  List<Object?> get props => [shapeId, width, height];
}

/// Cancel an active text edit session.
class TextEditCanceled extends CanvasEvent {
  const TextEditCanceled({required this.shapeId});

  final String shapeId;

  @override
  List<Object?> get props => [shapeId];
}

/// Request starting an inline text edit session for an existing text shape.
class TextEditRequested extends CanvasEvent {
  const TextEditRequested({required this.shapeId});

  final String shapeId;

  @override
  List<Object?> get props => [shapeId];
}

/// Fired when pointer/mouse moves on canvas
class PointerMove extends CanvasEvent {
  const PointerMove({
    required this.x,
    required this.y,
    this.shiftPressed = false,
  });

  /// X position in screen coordinates
  final double x;

  /// Y position in screen coordinates
  final double y;

  /// Whether shift key is pressed (for rotation snapping)
  final bool shiftPressed;

  @override
  List<Object?> get props => [x, y, shiftPressed];
}

/// Fired when pointer/mouse is released
class PointerUp extends CanvasEvent {
  const PointerUp({
    required this.x,
    required this.y,
  });

  /// X position in screen coordinates
  final double x;

  /// Y position in screen coordinates
  final double y;

  @override
  List<Object?> get props => [x, y];
}

/// Reparent one or more shapes to a destination frame (or root when null).
///
/// Coordinates remain absolute in canvas space; only `frameId` (and any
/// frame-owned ordering metadata) is updated.
class ShapesReparented extends CanvasEvent {
  const ShapesReparented({
    required this.shapeIds,
    required this.destinationFrameId,
  });

  final List<String> shapeIds;
  final String? destinationFrameId;

  @override
  List<Object?> get props => [shapeIds, destinationFrameId];
}

/// Fired when pointer leaves the canvas area
class CanvasPointerExited extends CanvasEvent {
  const CanvasPointerExited();
}

/// Fired to clear all selections
class SelectionCleared extends CanvasEvent {
  const SelectionCleared();
}

/// Fired to zoom in from keyboard shortcut (uses viewport center as focal point)
class ZoomIn extends CanvasEvent {
  const ZoomIn();
}

/// Fired to zoom out from keyboard shortcut (uses viewport center as focal point)
class ZoomOut extends CanvasEvent {
  const ZoomOut();
}

/// Fired to set zoom to a specific level (uses viewport center as focal point)
class ZoomSet extends CanvasEvent {
  const ZoomSet(this.zoom);

  final double zoom;

  @override
  List<Object?> get props => [zoom];
}

/// Fired to add a shape to the canvas
class ShapeAdded extends CanvasEvent {
  const ShapeAdded(this.shape);

  final Shape shape;

  @override
  List<Object?> get props => [shape];
}

/// Fired to add multiple shapes to the canvas
class ShapesAdded extends CanvasEvent {
  const ShapesAdded(this.shapes);

  final List<Shape> shapes;

  @override
  List<Object?> get props => [shapes];
}

/// Fired to remove a shape from the canvas
class ShapeRemoved extends CanvasEvent {
  const ShapeRemoved(this.shapeId);

  final String shapeId;

  @override
  List<Object?> get props => [shapeId];
}

/// Fired to update a shape's properties
class ShapeUpdated extends CanvasEvent {
  const ShapeUpdated(this.shape);

  final Shape shape;

  @override
  List<Object?> get props => [shape];
}

/// Fired to select a single shape
class ShapeSelected extends CanvasEvent {
  const ShapeSelected(this.shapeId, {this.addToSelection = false});

  final String shapeId;

  /// If true, add to existing selection (Shift+click)
  final bool addToSelection;

  @override
  List<Object?> get props => [shapeId, addToSelection];
}

/// Fired to select multiple shapes (e.g., from marquee selection)
class ShapesSelected extends CanvasEvent {
  const ShapesSelected(this.shapeIds);

  final List<String> shapeIds;

  @override
  List<Object?> get props => [shapeIds];
}

// ============================================================================
// Layer Panel Events
// ============================================================================

/// Fired to expand a layer (frame/group) in the layers panel
class LayerExpanded extends CanvasEvent {
  const LayerExpanded(this.layerId);

  final String layerId;

  @override
  List<Object?> get props => [layerId];
}

/// Fired to collapse a layer (frame/group) in the layers panel
class LayerCollapsed extends CanvasEvent {
  const LayerCollapsed(this.layerId);

  final String layerId;

  @override
  List<Object?> get props => [layerId];
}

/// Fired when hovering over a layer in the layers panel
class LayerHovered extends CanvasEvent {
  const LayerHovered(this.layerId);

  /// The layer ID being hovered, or null to clear hover
  final String? layerId;

  @override
  List<Object?> get props => [layerId];
}

/// Fired to toggle shape visibility (hidden flag)
class ShapeVisibilityToggled extends CanvasEvent {
  const ShapeVisibilityToggled(this.shapeId);

  final String shapeId;

  @override
  List<Object?> get props => [shapeId];
}

/// Fired to toggle shape lock (blocked flag)
class ShapeLockToggled extends CanvasEvent {
  const ShapeLockToggled(this.shapeId);

  final String shapeId;

  @override
  List<Object?> get props => [shapeId];
}

/// Fired to rename a shape
class ShapeRenamed extends CanvasEvent {
  const ShapeRenamed(this.shapeId, this.newName);

  final String shapeId;
  final String newName;

  @override
  List<Object?> get props => [shapeId, newName];
}

// ============================================================================
// Clipboard Events
// ============================================================================

/// Fired to copy selected shapes to clipboard (Ctrl+C)
class CopySelected extends CanvasEvent {
  const CopySelected();
}

/// Fired to cut selected shapes (Ctrl+X) - copies then deletes
class CutSelected extends CanvasEvent {
  const CutSelected();
}

/// Fired to paste shapes from clipboard (Ctrl+V)
class PasteShapes extends CanvasEvent {
  const PasteShapes();
}

/// Fired to duplicate selected shapes in place (Ctrl+D)
class DuplicateSelected extends CanvasEvent {
  const DuplicateSelected();
}

/// Fired to delete selected shapes (Delete/Backspace)
class DeleteSelected extends CanvasEvent {
  const DeleteSelected();
}

/// Fired to remove multiple shapes from the canvas
class ShapesRemoved extends CanvasEvent {
  const ShapesRemoved(this.shapeIds);

  final List<String> shapeIds;

  @override
  List<Object?> get props => [shapeIds];
}

// ============================================================================
// Undo/Redo Events
// ============================================================================

/// Fired to undo the last shape change (Ctrl+Z)
class Undo extends CanvasEvent {
  const Undo();
}

/// Fired to redo a previously undone change (Ctrl+Y or Ctrl+Shift+Z)
class Redo extends CanvasEvent {
  const Redo();
}

// ============================================================================
// Sync Events
// ============================================================================

/// Fired to load canvas state from the server
class CanvasLoadRequested extends CanvasEvent {
  const CanvasLoadRequested({
    required this.projectId,
    required this.branchId,
  });

  final String projectId;
  final String branchId;

  @override
  List<Object?> get props => [projectId, branchId];
}

/// Fired when canvas state is successfully loaded from server
class CanvasLoadSucceeded extends CanvasEvent {
  const CanvasLoadSucceeded({
    required this.shapes,
    required this.serverVersion,
  });

  final Map<String, Shape> shapes;
  final int serverVersion;

  @override
  List<Object?> get props => [shapes, serverVersion];
}

/// Fired when canvas loading fails
class CanvasLoadFailed extends CanvasEvent {
  const CanvasLoadFailed(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}

/// Fired to sync local changes to the server
class CanvasSyncRequested extends CanvasEvent {
  const CanvasSyncRequested();
}

/// Fired when canvas sync succeeds
class CanvasSyncSucceeded extends CanvasEvent {
  const CanvasSyncSucceeded({required this.serverVersion});

  final int serverVersion;

  @override
  List<Object?> get props => [serverVersion];
}

/// Fired when canvas sync fails
class CanvasSyncFailed extends CanvasEvent {
  const CanvasSyncFailed(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}
