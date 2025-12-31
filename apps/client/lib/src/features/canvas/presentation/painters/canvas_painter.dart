import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'shape_painter.dart';

/// Main canvas painter for rendering shapes and selection
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.viewMatrix,
    required this.shapes,
    this.dragRect,
    this.selectedShapeIds = const [],
  });

  /// Transformation matrix for viewport
  final Matrix2D viewMatrix;

  /// All shapes to render
  final List<Shape> shapes;

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

    // Draw all shapes
    for (final shape in shapes) {
      ShapePainter.paintShape(canvas, shape);

      // Draw frame name labels
      if (shape.type == ShapeType.frame) {
        _drawFrameLabel(canvas, shape as FrameShape);
      }
    }

    // Draw selection outlines for selected shapes
    _drawSelectionOutlines(canvas);

    canvas.restore();

    // Draw selection rectangle (in screen coordinates)
    if (dragRect != null) {
      _drawSelectionRect(canvas, size);
    }
  }

  void _drawSelectionOutlines(Canvas canvas) {
    if (selectedShapeIds.isEmpty) return;

    final outlinePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final shape in shapes) {
      if (!selectedShapeIds.contains(shape.id)) continue;

      final bounds = shape.bounds;
      final rect = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        bounds.width,
        bounds.height,
      );

      canvas.save();
      // Apply shape transform for outline
      canvas.transform(
        Float64List.fromList([
          shape.transform.a,
          shape.transform.b,
          0,
          0,
          shape.transform.c,
          shape.transform.d,
          0,
          0,
          0,
          0,
          1,
          0,
          shape.transform.e,
          shape.transform.f,
          0,
          1,
        ]),
      );
      canvas.drawRect(rect, outlinePaint);
      canvas.restore();
    }
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

  void _drawFrameLabel(Canvas canvas, FrameShape frame) {
    final bounds = frame.bounds;
    final isSelected = selectedShapeIds.contains(frame.id);

    // Position label above the frame
    const labelHeight = 20.0;
    const labelPadding = 8.0;
    final labelY = bounds.top - labelHeight - 4; // 4px gap

    // Draw label text
    final textStyle = TextStyle(
      color: isSelected ? VioColors.canvasSelection : VioColors.textSecondary,
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    );

    final textSpan = TextSpan(
      text: frame.name,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background if selected
    if (isSelected) {
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bounds.left - 4,
          labelY,
          textPainter.width + labelPadding * 2,
          labelHeight,
        ),
        const Radius.circular(4),
      );
      final bgPaint = Paint()
        ..color = VioColors.canvasSelection.withValues(alpha: 0.15);
      canvas.drawRRect(bgRect, bgPaint);
    }

    // Draw text
    textPainter.paint(
      canvas,
      Offset(bounds.left, labelY + (labelHeight - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    // Use listEquals for proper deep comparison of lists
    return viewMatrix != oldDelegate.viewMatrix ||
        !listEquals(shapes, oldDelegate.shapes) ||
        dragRect != oldDelegate.dragRect ||
        !listEquals(selectedShapeIds, oldDelegate.selectedShapeIds);
  }
}
