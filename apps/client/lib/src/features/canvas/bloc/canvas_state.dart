part of 'canvas_bloc.dart';

/// Current interaction mode for the canvas
enum InteractionMode {
  /// No active interaction
  idle,

  /// User is panning the viewport
  panning,

  /// User is dragging to select or create
  dragging,

  /// User is drawing a new shape
  drawing,

  /// User is resizing a shape
  resizing,

  /// User is rotating a shape
  rotating,
}

/// Represents the complete state of the canvas
class CanvasState extends Equatable {
  const CanvasState({
    this.zoom = 1.0,
    this.viewportOffset = const Point2D(0, 0),
    this.viewportSize = const Point2D(800, 600),
    this.interactionMode = InteractionMode.idle,
    this.dragStart,
    this.currentPointer,
    this.shapes = const {},
    this.selectedShapeIds = const [],
    this.hoveredShapeId,
  });

  /// Current zoom level (1.0 = 100%)
  final double zoom;

  /// Viewport offset (pan position) in screen coordinates
  final Point2D viewportOffset;

  /// Viewport size in screen coordinates
  final Point2D viewportSize;

  /// Current interaction mode
  final InteractionMode interactionMode;

  /// Starting point of current drag operation (canvas coordinates)
  final Point2D? dragStart;

  /// Current pointer position (canvas coordinates)
  final Point2D? currentPointer;

  /// All shapes on the canvas, keyed by ID
  final Map<String, Shape> shapes;

  /// IDs of currently selected shapes
  final List<String> selectedShapeIds;

  /// ID of shape currently under the pointer
  final String? hoveredShapeId;

  /// Get shapes as an ordered list (for rendering)
  List<Shape> get shapeList => shapes.values.toList();

  /// Get currently selected shapes
  List<Shape> get selectedShapes =>
      selectedShapeIds.map((id) => shapes[id]).whereType<Shape>().toList();

  /// Get the visible rectangle in canvas coordinates
  Rect2D get visibleRect {
    final topLeft = screenToCanvas(const Point2D(0, 0));
    final bottomRight = screenToCanvas(viewportSize);
    return Rect2D.fromPoints(topLeft, bottomRight);
  }

  /// Convert screen coordinates to canvas coordinates
  Point2D screenToCanvas(Point2D screenPoint) {
    return Point2D(
      (screenPoint.x - viewportOffset.x) / zoom,
      (screenPoint.y - viewportOffset.y) / zoom,
    );
  }

  /// Convert canvas coordinates to screen coordinates
  Point2D canvasToScreen(Point2D canvasPoint) {
    return Point2D(
      canvasPoint.x * zoom + viewportOffset.x,
      canvasPoint.y * zoom + viewportOffset.y,
    );
  }

  /// Get the transformation matrix for rendering
  Matrix2D get viewMatrix {
    return Matrix2D.identity
        .translated(viewportOffset.x, viewportOffset.y)
        .scaled(zoom, zoom);
  }

  /// Whether there is an active selection
  bool get hasSelection => selectedShapeIds.isNotEmpty;

  /// Whether the canvas is in a dragging state
  bool get isDragging => interactionMode == InteractionMode.dragging;

  /// Get drag rectangle if currently dragging
  Rect2D? get dragRect {
    if (dragStart == null || currentPointer == null) return null;
    return Rect2D.fromPoints(dragStart!, currentPointer!);
  }

  CanvasState copyWith({
    double? zoom,
    Point2D? viewportOffset,
    Point2D? viewportSize,
    InteractionMode? interactionMode,
    Point2D? dragStart,
    Point2D? currentPointer,
    Map<String, Shape>? shapes,
    List<String>? selectedShapeIds,
    String? hoveredShapeId,
    bool clearDragStart = false,
    bool clearCurrentPointer = false,
  }) {
    return CanvasState(
      zoom: zoom ?? this.zoom,
      viewportOffset: viewportOffset ?? this.viewportOffset,
      viewportSize: viewportSize ?? this.viewportSize,
      interactionMode: interactionMode ?? this.interactionMode,
      dragStart: clearDragStart ? null : (dragStart ?? this.dragStart),
      currentPointer:
          clearCurrentPointer ? null : (currentPointer ?? this.currentPointer),
      shapes: shapes ?? this.shapes,
      selectedShapeIds: selectedShapeIds ?? this.selectedShapeIds,
      hoveredShapeId: hoveredShapeId ?? this.hoveredShapeId,
    );
  }

  @override
  List<Object?> get props => [
        zoom,
        viewportOffset,
        viewportSize,
        interactionMode,
        dragStart,
        currentPointer,
        shapes,
        selectedShapeIds,
        hoveredShapeId,
      ];
}
