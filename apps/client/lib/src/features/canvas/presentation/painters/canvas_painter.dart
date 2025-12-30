import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Main canvas painter for rendering shapes and selection
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.viewMatrix,
    this.dragRect,
    this.selectedShapeIds = const [],
  });

  /// Transformation matrix for viewport
  final Matrix2D viewMatrix;

  /// Current drag selection rectangle (in canvas coordinates)
  final Rect2D? dragRect;

  /// IDs of selected shapes
  final List<String> selectedShapeIds;

  @override
  void paint(Canvas canvas, Size size) {
    // Apply view transformation
    canvas.save();
    canvas.transform(
      Float64List.fromList([
        viewMatrix.a,
        viewMatrix.b,
        0,
        0,
        viewMatrix.c,
        viewMatrix.d,
        0,
        0,
        0,
        0,
        1,
        0,
        viewMatrix.e,
        viewMatrix.f,
        0,
        1,
      ]),
    );

    // TODO: Draw shapes here
    // For now, draw a sample rectangle to show canvas is working
    _drawSampleContent(canvas);

    canvas.restore();

    // Draw selection rectangle (in screen coordinates)
    if (dragRect != null) {
      _drawSelectionRect(canvas, size);
    }
  }

  void _drawSampleContent(Canvas canvas) {
    // Draw a sample frame to show the canvas is working
    final framePaint = Paint()
      ..color = VioColors.surface2
      ..style = PaintingStyle.fill;

    final frameBorderPaint = Paint()
      ..color = VioColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Sample artboard/frame at origin
    const frameRect = Rect.fromLTWH(0, 0, 800, 600);
    canvas.drawRect(frameRect, framePaint);
    canvas.drawRect(frameRect, frameBorderPaint);

    // Frame label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Frame 1',
        style: VioTypography.caption.copyWith(
          color: VioColors.textSecondary,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, -18));

    // Draw origin marker
    final originPaint = Paint()
      ..color = VioColors.primary.withValues(alpha: 0.5)
      ..strokeWidth = 2;

    canvas.drawLine(
      const Offset(-10, 0),
      const Offset(10, 0),
      originPaint,
    );
    canvas.drawLine(
      const Offset(0, -10),
      const Offset(0, 10),
      originPaint,
    );
  }

  void _drawSelectionRect(Canvas canvas, Size size) {
    if (dragRect == null) return;

    // Convert drag rect from canvas to screen coordinates
    final topLeft = _canvasToScreen(Point2D(dragRect!.left, dragRect!.top));
    final bottomRight =
        _canvasToScreen(Point2D(dragRect!.right, dragRect!.bottom));

    final rect = Rect.fromPoints(
      Offset(topLeft.x, topLeft.y),
      Offset(bottomRight.x, bottomRight.y),
    );

    // Fill
    final fillPaint = Paint()
      ..color = VioColors.canvasSelection.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, strokePaint);
  }

  Point2D _canvasToScreen(Point2D canvasPoint) {
    final result = viewMatrix.transformPoint(canvasPoint.x, canvasPoint.y);
    return Point2D(result.x, result.y);
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return viewMatrix != oldDelegate.viewMatrix ||
        dragRect != oldDelegate.dragRect ||
        selectedShapeIds != oldDelegate.selectedShapeIds;
  }
}
