part of 'canvas_bloc.dart';

mixin _CanvasViewportMixin on Bloc<CanvasEvent, CanvasState> {
  void _onInitialized(
    CanvasInitialized event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        viewportSize: Size(event.width, event.height),
      ),
    );
  }

  void _onViewportPanned(
    ViewportPanned event,
    Emitter<CanvasState> emit,
  ) {
    final newOffset = Offset(
      state.viewportOffset.dx + event.deltaX,
      state.viewportOffset.dy + event.deltaY,
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
    final newOffset = Offset(
      event.focalX - (event.focalX - state.viewportOffset.dx) * zoomRatio,
      event.focalY - (event.focalY - state.viewportOffset.dy) * zoomRatio,
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
        viewportOffset: const Offset(0, 0),
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

  void _onSelectionCentered(
    SelectionCentered event,
    Emitter<CanvasState> emit,
  ) {
    final selectionRect = state.selectionRect;
    if (selectionRect == null) return;

    final center = selectionRect.center;
    final viewportCenter = Offset(
      state.viewportSize.width / 2,
      state.viewportSize.height / 2,
    );

    final newOffset = Offset(
      viewportCenter.dx - center.dx * state.zoom,
      viewportCenter.dy - center.dy * state.zoom,
    );

    emit(state.copyWith(viewportOffset: newOffset));
  }

  void _zoomAtCenter(double scaleFactor, Emitter<CanvasState> emit) {
    // Use viewport center as focal point
    final centerX = state.viewportSize.width / 2;
    final centerY = state.viewportSize.height / 2;

    // Calculate new zoom level
    final newZoom = (state.zoom * scaleFactor).clamp(0.01, 64.0);

    // Adjust offset to zoom towards center
    final zoomDelta = newZoom / state.zoom;
    final newOffset = Offset(
      centerX - (centerX - state.viewportOffset.dx) * zoomDelta,
      centerY - (centerY - state.viewportOffset.dy) * zoomDelta,
    );

    emit(
      state.copyWith(
        zoom: newZoom,
        viewportOffset: newOffset,
      ),
    );
  }
}
