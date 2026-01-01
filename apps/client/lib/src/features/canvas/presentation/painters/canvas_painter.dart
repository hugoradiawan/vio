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
    this.dragOffset,
    this.selectedShapeIds = const [],
    this.hoveredShapeId,
    this.hoveredLayerId,
  });

  /// Transformation matrix for viewport
  final Matrix2D viewMatrix;

  /// All shapes to render
  final List<Shape> shapes;

  /// Current drag selection rectangle (in canvas coordinates)
  final Rect2D? dragRect;

  /// Current drag offset for moving shapes (applied at render time)
  final Point2D? dragOffset;

  /// IDs of selected shapes
  final List<String> selectedShapeIds;

  /// ID of shape hovered on canvas
  final String? hoveredShapeId;

  /// ID of layer hovered in layers panel
  final String? hoveredLayerId;

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
      final isSelected = selectedShapeIds.contains(shape.id);
      final isDragging = isSelected && dragOffset != null;

      if (isDragging) {
        // Apply drag offset translation for selected shapes during drag
        canvas.save();
        canvas.translate(dragOffset!.x, dragOffset!.y);
        ShapePainter.paintShape(canvas, shape);
        canvas.restore();
      } else {
        ShapePainter.paintShape(canvas, shape);
      }

      // Draw frame name labels
      if (shape.type == ShapeType.frame) {
        if (isDragging) {
          canvas.save();
          canvas.translate(dragOffset!.x, dragOffset!.y);
          _drawFrameLabel(canvas, shape as FrameShape);
          canvas.restore();
        } else {
          _drawFrameLabel(canvas, shape as FrameShape);
        }
      }
    }

    // Draw hover outline (from canvas or layer panel)
    _drawHoverOutline(canvas);

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
      // Apply drag offset if dragging
      if (dragOffset != null) {
        canvas.translate(dragOffset!.x, dragOffset!.y);
      }
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

  void _drawHoverOutline(Canvas canvas) {
    // Get the hovered shape ID (prefer layer hover over canvas hover)
    final hoveredId = hoveredLayerId ?? hoveredShapeId;
    if (hoveredId == null) return;

    // Don't draw hover if already selected
    if (selectedShapeIds.contains(hoveredId)) return;

    final shape = shapes.where((s) => s.id == hoveredId).firstOrNull;
    if (shape == null) return;

    final hoverPaint = Paint()
      ..color = VioColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final bounds = shape.bounds;
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );

    canvas.save();
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
    canvas.drawRect(rect, hoverPaint);
    canvas.restore();
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
    // Fast path: if only dragOffset changed, repaint
    // This is the most frequent change during dragging
    if (dragOffset != oldDelegate.dragOffset) return true;
    
    // Use identity comparison for shapes (they don't change during drag)
    if (!identical(shapes, oldDelegate.shapes)) return true;
    
    return viewMatrix != oldDelegate.viewMatrix ||
        dragRect != oldDelegate.dragRect ||
        !listEquals(selectedShapeIds, oldDelegate.selectedShapeIds) ||
        hoveredShapeId != oldDelegate.hoveredShapeId ||
        hoveredLayerId != oldDelegate.hoveredLayerId;
  }
}
