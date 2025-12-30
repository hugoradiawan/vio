import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:vio_core/vio_core.dart';

part 'canvas_event.dart';
part 'canvas_state.dart';

/// Manages the infinite canvas state including:
/// - Viewport (pan/zoom transforms)
/// - Shapes on canvas
/// - Selection state
/// - Interaction mode
@injectable
class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  CanvasBloc() : super(const CanvasState()) {
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

    emit(
      state.copyWith(
        interactionMode: InteractionMode.dragging,
        dragStart: canvasPoint,
        currentPointer: canvasPoint,
      ),
    );
  }

  void _onPointerMove(
    PointerMove event,
    Emitter<CanvasState> emit,
  ) {
    final canvasPoint = _screenToCanvas(Point2D(event.x, event.y));

    emit(state.copyWith(currentPointer: canvasPoint));
  }

  void _onPointerUp(
    PointerUp event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        interactionMode: InteractionMode.idle,
      ),
    );
  }

  void _onSelectionCleared(
    SelectionCleared event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(selectedShapeIds: []));
  }

  /// Convert screen coordinates to canvas coordinates
  Point2D _screenToCanvas(Point2D screenPoint) {
    return Point2D(
      (screenPoint.x - state.viewportOffset.x) / state.zoom,
      (screenPoint.y - state.viewportOffset.y) / state.zoom,
    );
  }
}
