class SelectionHandleMetrics {
  const SelectionHandleMetrics._();

  static const double resizeVisualSize = 8.0;
  static const double rotationVisualSize = 8.0;
  static const double rotationOffset = 24.0;
  static const double cornerRadiusVisualSize = 10.0;
  static const double selectionStrokeWidth = 0.7;
  static const double handleStrokeWidth = 0.6;

  static const double resizeHitSize = 14.0;
  static const double rotationHitRadius = 8.0;
  static const double cornerRadiusHitRadius = 8.0;
  static const double edgeHitSlop = 6.0;
  static const double cornerHitSlop = 14.0;

  static const double cornerRadiusMinInset = 8.0;

  static double toCanvasUnits({
    required double screenPx,
    required double zoom,
  }) {
    if (zoom <= 0) return screenPx;
    return screenPx / zoom;
  }
}
