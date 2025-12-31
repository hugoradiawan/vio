part of 'canvas_bloc.dart';

/// Base class for canvas events
sealed class CanvasEvent extends Equatable {
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
  });

  /// X position in screen coordinates
  final double x;

  /// Y position in screen coordinates
  final double y;

  /// Mouse button (0 = left, 1 = middle, 2 = right)
  final int button;

  /// Whether shift key is pressed (for multi-select)
  final bool shiftPressed;

  @override
  List<Object?> get props => [x, y, button, shiftPressed];
}

/// Fired when pointer/mouse moves on canvas
class PointerMove extends CanvasEvent {
  const PointerMove({
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
