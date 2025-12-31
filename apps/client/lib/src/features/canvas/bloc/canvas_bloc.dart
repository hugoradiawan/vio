import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';

part 'canvas_event.dart';
part 'canvas_state.dart';

/// Manages the infinite canvas state including:
/// - Viewport (pan/zoom transforms)
/// - Shapes on canvas
/// - Selection state
/// - Interaction mode
class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  CanvasBloc() : super(CanvasState(shapes: _createTestShapes())) {
    on<CanvasInitialized>(_onInitialized);
    on<ViewportPanned>(_onViewportPanned);
    on<ViewportZoomed>(_onViewportZoomed);
    on<ViewportReset>(_onViewportReset);
    on<ZoomIn>(_onZoomIn);
    on<ZoomOut>(_onZoomOut);
    on<ZoomSet>(_onZoomSet);
    on<PointerDown>(_onPointerDown);
    on<PointerMove>(_onPointerMove);
    on<PointerUp>(_onPointerUp);
    on<SelectionCleared>(_onSelectionCleared);
    on<ShapeAdded>(_onShapeAdded);
    on<ShapesAdded>(_onShapesAdded);
    on<ShapeRemoved>(_onShapeRemoved);
    on<ShapeUpdated>(_onShapeUpdated);
    on<ShapeSelected>(_onShapeSelected);
    on<ShapesSelected>(_onShapesSelected);
  }

  /// Create test shapes for development
  static Map<String, Shape> _createTestShapes() {
    final shapes = <String, Shape>{};

    // Frame (artboard)
    const frame = FrameShape(
      id: 'frame-1',
      name: 'Frame 1',
      x: 0,
      y: 0,
      frameWidth: 800,
      frameHeight: 600,
      fills: [ShapeFill(color: 0xFF2D2D2D)],
      strokes: [ShapeStroke(color: 0xFF404040)],
    );
    shapes[frame.id] = frame;

    // Blue rectangle
    final rect1 = RectangleShape(
      id: 'rect-1',
      name: 'Rectangle 1',
      x: 50,
      y: 50,
      rectWidth: 200,
      rectHeight: 150,
      r1: 8,
      r2: 8,
      r3: 8,
      r4: 8,
      fills: const [ShapeFill(color: 0xFF3B82F6)],
      strokes: const [ShapeStroke(color: 0xFF1D4ED8, width: 2)],
      frameId: frame.id,
    );
    shapes[rect1.id] = rect1;

    // Green rectangle
    final rect2 = RectangleShape(
      id: 'rect-2',
      name: 'Rectangle 2',
      x: 300,
      y: 100,
      rectWidth: 180,
      rectHeight: 120,
      fills: const [ShapeFill(color: 0xFF22C55E)],
      strokes: const [ShapeStroke(color: 0xFF16A34A, width: 2)],
      frameId: frame.id,
    );
    shapes[rect2.id] = rect2;

    // Red ellipse (center at 600,200 with semi-axes 80,60 means bounds: x=520, y=140, w=160, h=120)
    final ellipse1 = EllipseShape(
      id: 'ellipse-1',
      name: 'Ellipse 1',
      x: 520,
      y: 140,
      ellipseWidth: 160,
      ellipseHeight: 120,
      fills: const [ShapeFill(color: 0xFFEF4444)],
      strokes: const [ShapeStroke(color: 0xFFDC2626, width: 2)],
      frameId: frame.id,
    );
    shapes[ellipse1.id] = ellipse1;

    // Yellow rectangle with no fill, just stroke
    final rect3 = RectangleShape(
      id: 'rect-3',
      name: 'Rectangle 3',
      x: 100,
      y: 300,
      rectWidth: 250,
      rectHeight: 180,
      strokes: const [
        ShapeStroke(
          color: 0xFFFACC15,
          width: 3,
          alignment: StrokeAlignment.inside,
        ),
      ],
      frameId: frame.id,
    );
    shapes[rect3.id] = rect3;

    // Purple circle (center at 550,400 with radius 70 means bounds: x=480, y=330, w=140, h=140)
    final ellipse2 = EllipseShape(
      id: 'ellipse-2',
      name: 'Circle 1',
      x: 480,
      y: 330,
      ellipseWidth: 140,
      ellipseHeight: 140,
      fills: const [ShapeFill(color: 0xFFA855F7)],
      strokes: const [ShapeStroke(color: 0xFF9333EA, width: 2)],
      frameId: frame.id,
    );
    shapes[ellipse2.id] = ellipse2;

    return shapes;
  }

  void _onInitialized(
    CanvasInitialized event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        viewportSize: Point2D(event.width, event.height),
      ),
    );
  }

  void _onViewportPanned(
    ViewportPanned event,
    Emitter<CanvasState> emit,
  ) {
    final newOffset = Point2D(
      state.viewportOffset.x + event.deltaX,
      state.viewportOffset.y + event.deltaY,
    );
    emit(state.copyWith(viewportOffset: newOffset));
  }

  void _onViewportZoomed(
    ViewportZoomed event,
    Emitter<CanvasState> emit,
  ) {
    // Calculate new zoom level
    final newZoom = (state.zoom * event.scaleFactor).clamp(0.01, 64.0);

    // Zoom towards the focal point (mouse position in screen coordinates)
    // The point under the mouse should stay in the same position after zoom
    //
    // Before zoom: canvasPoint = (screenPoint - offset) / oldZoom
    // After zoom:  canvasPoint = (screenPoint - newOffset) / newZoom
    //
    // We want the same canvas point under the mouse, so:
    // (focalPoint - offset) / oldZoom = (focalPoint - newOffset) / newZoom
    //
    // Solving for newOffset:
    // newOffset = focalPoint - (focalPoint - offset) * (newZoom / oldZoom)

    final zoomRatio = newZoom / state.zoom;
    final newOffset = Point2D(
      event.focalX - (event.focalX - state.viewportOffset.x) * zoomRatio,
      event.focalY - (event.focalY - state.viewportOffset.y) * zoomRatio,
    );

    emit(
      state.copyWith(
        zoom: newZoom,
        viewportOffset: newOffset,
      ),
    );
  }

  void _onViewportReset(
    ViewportReset event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        zoom: 1.0,
        viewportOffset: const Point2D(0, 0),
      ),
    );
  }

  void _onZoomIn(
    ZoomIn event,
    Emitter<CanvasState> emit,
  ) {
    _zoomAtCenter(1.25, emit);
  }

  void _onZoomOut(
    ZoomOut event,
    Emitter<CanvasState> emit,
  ) {
    _zoomAtCenter(1 / 1.25, emit);
  }

  void _onZoomSet(
    ZoomSet event,
    Emitter<CanvasState> emit,
  ) {
    final targetZoom = event.zoom.clamp(0.01, 64.0);
    final scaleFactor = targetZoom / state.zoom;
    _zoomAtCenter(scaleFactor, emit);
  }

  void _zoomAtCenter(double scaleFactor, Emitter<CanvasState> emit) {
    // Use viewport center as focal point
    final centerX = state.viewportSize.x / 2;
    final centerY = state.viewportSize.y / 2;

    // Calculate new zoom level
    final newZoom = (state.zoom * scaleFactor).clamp(0.01, 64.0);

    // Adjust offset to zoom towards center
    final zoomDelta = newZoom / state.zoom;
    final newOffset = Point2D(
      centerX - (centerX - state.viewportOffset.x) * zoomDelta,
      centerY - (centerY - state.viewportOffset.y) * zoomDelta,
    );

    emit(
      state.copyWith(
        zoom: newZoom,
        viewportOffset: newOffset,
      ),
    );
  }

  void _onPointerDown(
    PointerDown event,
    Emitter<CanvasState> emit,
  ) {
    final canvasPoint = _screenToCanvas(Point2D(event.x, event.y));

    // Hit test to find shape under pointer
    final hitShape = HitTest.findTopShapeAtPoint(canvasPoint, state.shapeList);

    if (hitShape != null) {
      // Check if shift is held for multi-select
      final addToSelection = event.shiftPressed;

      if (addToSelection) {
        // Toggle selection
        if (state.selectedShapeIds.contains(hitShape.id)) {
          emit(
            state.copyWith(
              selectedShapeIds: state.selectedShapeIds
                  .where((id) => id != hitShape.id)
                  .toList(),
              interactionMode: InteractionMode.idle,
              clearDragStart: true,
              clearCurrentPointer: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              selectedShapeIds: [...state.selectedShapeIds, hitShape.id],
              interactionMode: InteractionMode.movingShapes,
              dragStart: canvasPoint,
              currentPointer: canvasPoint,
            ),
          );
        }
      } else {
        // Single selection - shape clicked, start moving
        final isAlreadySelected = state.selectedShapeIds.contains(hitShape.id);
        emit(
          state.copyWith(
            selectedShapeIds: isAlreadySelected
                ? state.selectedShapeIds
                : [hitShape.id],
            interactionMode: InteractionMode.movingShapes,
            dragStart: canvasPoint,
            currentPointer: canvasPoint,
          ),
        );
      }
    } else {
      // No shape hit - start marquee selection
      emit(
        state.copyWith(
          interactionMode: InteractionMode.dragging,
          dragStart: canvasPoint,
          currentPointer: canvasPoint,
          selectedShapeIds: [], // Clear selection
        ),
      );
    }
  }

  void _onPointerMove(
    PointerMove event,
    Emitter<CanvasState> emit,
  ) {
    final canvasPoint = _screenToCanvas(Point2D(event.x, event.y));

    // Handle shape movement
    if (state.interactionMode == InteractionMode.movingShapes &&
        state.currentPointer != null &&
        state.selectedShapeIds.isNotEmpty) {
      final delta = Point2D(
        canvasPoint.x - state.currentPointer!.x,
        canvasPoint.y - state.currentPointer!.y,
      );

      // Move all selected shapes
      final newShapes = Map<String, Shape>.from(state.shapes);
      for (final shapeId in state.selectedShapeIds) {
        final shape = newShapes[shapeId];
        if (shape != null) {
          newShapes[shapeId] = shape.moveBy(delta.x, delta.y);
        }
      }

      emit(state.copyWith(
        shapes: newShapes,
        currentPointer: canvasPoint,
      ),);
    } else {
      emit(state.copyWith(currentPointer: canvasPoint));
    }
  }

  void _onPointerUp(
    PointerUp event,
    Emitter<CanvasState> emit,
  ) {
    // Check if we were doing marquee selection
    if (state.interactionMode == InteractionMode.dragging &&
        state.dragRect != null) {
      // Find shapes in the marquee rectangle
      final shapesInRect = HitTest.findShapesInRect(
        state.dragRect!,
        state.shapeList,
      );
      final selectedIds = shapesInRect.map((s) => s.id).toList();

      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          selectedShapeIds: selectedIds,
          clearDragStart: true,
          clearCurrentPointer: true,
        ),
      );
    } else if (state.interactionMode == InteractionMode.movingShapes) {
      // Finished moving shapes - keep selection, just end the mode
      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          interactionMode: InteractionMode.idle,
          clearDragStart: true,
          clearCurrentPointer: true,
        ),
      );
    }
  }

  void _onSelectionCleared(
    SelectionCleared event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(selectedShapeIds: []));
  }

  void _onShapeAdded(
    ShapeAdded event,
    Emitter<CanvasState> emit,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shape.id] = event.shape;
    emit(state.copyWith(shapes: newShapes));
  }

  void _onShapesAdded(
    ShapesAdded event,
    Emitter<CanvasState> emit,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    for (final shape in event.shapes) {
      newShapes[shape.id] = shape;
    }
    emit(state.copyWith(shapes: newShapes));
  }

  void _onShapeRemoved(
    ShapeRemoved event,
    Emitter<CanvasState> emit,
  ) {
    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes.remove(event.shapeId);

    // Also remove from selection
    final newSelection =
        state.selectedShapeIds.where((id) => id != event.shapeId).toList();

    emit(
      state.copyWith(
        shapes: newShapes,
        selectedShapeIds: newSelection,
      ),
    );
  }

  void _onShapeUpdated(
    ShapeUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (!state.shapes.containsKey(event.shape.id)) return;

    final newShapes = Map<String, Shape>.from(state.shapes);
    newShapes[event.shape.id] = event.shape;
    emit(state.copyWith(shapes: newShapes));
  }

  void _onShapeSelected(
    ShapeSelected event,
    Emitter<CanvasState> emit,
  ) {
    if (!state.shapes.containsKey(event.shapeId)) return;

    List<String> newSelection;
    if (event.addToSelection) {
      // Toggle selection if already selected
      if (state.selectedShapeIds.contains(event.shapeId)) {
        newSelection =
            state.selectedShapeIds.where((id) => id != event.shapeId).toList();
      } else {
        newSelection = [...state.selectedShapeIds, event.shapeId];
      }
    } else {
      // Replace selection
      newSelection = [event.shapeId];
    }
    emit(state.copyWith(selectedShapeIds: newSelection));
  }

  void _onShapesSelected(
    ShapesSelected event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(selectedShapeIds: event.shapeIds));
  }

  /// Convert screen coordinates to canvas coordinates
  Point2D _screenToCanvas(Point2D screenPoint) {
    return Point2D(
      (screenPoint.x - state.viewportOffset.x) / state.zoom,
      (screenPoint.y - state.viewportOffset.y) / state.zoom,
    );
  }
}
