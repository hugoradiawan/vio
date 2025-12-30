import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Paints the infinite grid pattern on the canvas
class GridPainter extends CustomPainter {
  GridPainter({
    required this.gridSize,
    required this.zoom,
    required this.offset,
  });

  /// Base grid cell size in logical pixels
  final double gridSize;

  /// Current zoom level
  final double zoom;

  /// Current viewport offset
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate effective grid size based on zoom
    double effectiveGridSize = gridSize * zoom;

    // If grid is too small or too large, adjust
    while (effectiveGridSize < 10) {
      effectiveGridSize *= 10;
    }
    while (effectiveGridSize > 200) {
      effectiveGridSize /= 10;
    }

    // Minor grid paint
    final minorPaint = Paint()
      ..color = VioColors.canvasGrid.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    // Major grid paint (every 10th line)
    final majorPaint = Paint()
      ..color = VioColors.canvasGrid.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // Calculate starting positions
    final startX = offset.dx % effectiveGridSize;
    final startY = offset.dy % effectiveGridSize;

    // Calculate which line index we're starting from for major line calculation
    final startIndexX = (offset.dx / effectiveGridSize).floor().abs();
    final startIndexY = (offset.dy / effectiveGridSize).floor().abs();

    // Draw vertical lines
    int indexX = 0;
    for (double x = startX; x < size.width; x += effectiveGridSize) {
      final isMajor = (startIndexX + indexX) % 10 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );
      indexX++;
    }

    // Draw horizontal lines
    int indexY = 0;
    for (double y = startY; y < size.height; y += effectiveGridSize) {
      final isMajor = (startIndexY + indexY) % 10 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
      indexY++;
    }

    // Draw origin crosshair if visible
    if (offset.dx >= 0 && offset.dx <= size.width) {
      final originPaint = Paint()
        ..color = VioColors.error.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(offset.dx, 0),
        Offset(offset.dx, size.height),
        originPaint,
      );
    }
    if (offset.dy >= 0 && offset.dy <= size.height) {
      final originPaint = Paint()
        ..color = VioColors.error.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, offset.dy),
        Offset(size.width, offset.dy),
        originPaint,
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
