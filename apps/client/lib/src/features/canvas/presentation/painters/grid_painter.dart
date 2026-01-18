import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Paints the infinite grid pattern on the canvas
class GridPainter extends CustomPainter {
  GridPainter({
    required this.gridSize,
    required this.zoom,
    required this.offset,
  });

  static final Paint _minorPaint = Paint()
    ..color = VioColors.canvasGrid.withValues(alpha: 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  static final Paint _majorPaint = Paint()
    ..color = VioColors.canvasGrid.withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  static final Paint _originPaint = Paint()
    ..color = VioColors.error.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  /// Base grid cell size in logical pixels
  final double gridSize;

  /// Current zoom level
  final double zoom;

  /// Current viewport offset
  final Offset offset;

  double _effectiveGridSize() {
    // Calculate effective grid size based on zoom.
    var effectiveGridSize = gridSize * zoom;

    // If grid is too small or too large, adjust.
    while (effectiveGridSize < 10) {
      effectiveGridSize *= 10;
    }
    while (effectiveGridSize > 200) {
      effectiveGridSize /= 10;
    }

    return effectiveGridSize;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveGridSize = _effectiveGridSize();

    // Calculate starting positions
    final startX = offset.dx % effectiveGridSize;
    final startY = offset.dy % effectiveGridSize;

    // Calculate which line index we're starting from for major line calculation
    final startIndexX = (offset.dx / effectiveGridSize).floor().abs();
    final startIndexY = (offset.dy / effectiveGridSize).floor().abs();

    // Batch grid lines into paths to reduce draw calls on web.
    final minorPath = Path();
    final majorPath = Path();

    // Vertical lines
    var indexX = 0;
    for (var x = startX; x < size.width; x += effectiveGridSize) {
      final isMajor = (startIndexX + indexX) % 10 == 0;
      final path = isMajor ? majorPath : minorPath;
      path
        ..moveTo(x, 0)
        ..lineTo(x, size.height);
      indexX++;
    }

    // Horizontal lines
    var indexY = 0;
    for (var y = startY; y < size.height; y += effectiveGridSize) {
      final isMajor = (startIndexY + indexY) % 10 == 0;
      final path = isMajor ? majorPath : minorPath;
      path
        ..moveTo(0, y)
        ..lineTo(size.width, y);
      indexY++;
    }

    canvas.drawPath(minorPath, _minorPaint);
    canvas.drawPath(majorPath, _majorPaint);

    // Draw origin crosshair if visible
    if (offset.dx >= 0 && offset.dx <= size.width) {
      canvas.drawLine(
        Offset(offset.dx, 0),
        Offset(offset.dx, size.height),
        _originPaint,
      );
    }
    if (offset.dy >= 0 && offset.dy <= size.height) {
      canvas.drawLine(
        Offset(0, offset.dy),
        Offset(size.width, offset.dy),
        _originPaint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return gridSize != oldDelegate.gridSize ||
        zoom != oldDelegate.zoom ||
        offset != oldDelegate.offset;
  }
}
