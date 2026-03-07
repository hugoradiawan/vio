import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

/// Painter for displaying size indicators on selected shapes
class SizeIndicatorPainter extends CustomPainter {
  SizeIndicatorPainter({
    required this.viewMatrix,
    required this.selectionRect,
    required this.zoom,
    required this.chipColor,
    required this.onChipColor,
  });

  final Matrix2D viewMatrix;
  final Rect? selectionRect;
  final double zoom;
  final Color chipColor;
  final Color onChipColor;
  static const double pillHeight = 18.0;
  static const double pillPadding = 8.0;
  static const double pillRadius = 4.0;
  static const double fontSize = 11.0;
  static const double offsetFromBottom = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect == null) return;
    if (selectionRect!.width <= 0 || selectionRect!.height <= 0) return;

    // Format size text
    final width = selectionRect!.width.round();
    final height = selectionRect!.height.round();
    final sizeText = '$width × $height';

    // Create text painter
    final textPainter = TextPainter(
      text: TextSpan(
        text: sizeText,
        style: TextStyle(
          color: onChipColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Calculate pill dimensions
    final pillWidth = textPainter.width + pillPadding * 2;
    const scaledPillHeight = pillHeight;

    // Position at bottom center of selection (in screen coordinates)
    final centerX = selectionRect!.center.dx * zoom + viewMatrix.e;
    final bottomY = selectionRect!.bottom * zoom + viewMatrix.f;

    final pillX = centerX - pillWidth / 2;
    final pillY = bottomY + offsetFromBottom;

    // Check if within visible bounds
    if (pillY < 0 ||
        pillY > size.height ||
        pillX + pillWidth < 0 ||
        pillX > size.width) {
      return;
    }

    // Draw background pill
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillX, pillY, pillWidth, scaledPillHeight),
      const Radius.circular(pillRadius),
    );

    final bgPaint = Paint()
      ..color = chipColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(pillRect, bgPaint);

    // Draw text centered in pill
    textPainter.paint(
      canvas,
      Offset(
        pillX + pillPadding,
        pillY + (scaledPillHeight - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(SizeIndicatorPainter oldDelegate) {
    return selectionRect != oldDelegate.selectionRect ||
        chipColor != oldDelegate.chipColor ||
        onChipColor != oldDelegate.onChipColor ||
        viewMatrix != oldDelegate.viewMatrix ||
        zoom != oldDelegate.zoom;
  }
}

/// Painter for distance measurements between shapes or to edges
class DistanceIndicatorPainter extends CustomPainter {
  DistanceIndicatorPainter({
    required this.viewMatrix,
    required this.selectionRect,
    required this.zoom,
    this.frameRect,
  });

  final Matrix2D viewMatrix;
  final Rect? selectionRect;
  final double zoom;
  final Rect? frameRect;

  // Distance indicator constants
  static const Color lineColor = Color(0xFFE53935); // Red
  static const Color textBgColor = Colors.white;
  static const Color textColor = Color(0xFFE53935);
  static const double lineWidth = 1.0;
  static const double arrowSize = 4.0;
  static const double fontSize = 10.0;
  static const double minDistance = 10.0; // Min distance to show indicator

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect == null || frameRect == null) return;

    canvas.save();

    // Apply view transformation for canvas-space drawing
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

    final scaledLineWidth = lineWidth / zoom;

    // Calculate distances to frame edges
    final leftDistance = selectionRect!.left - frameRect!.left;
    final rightDistance = frameRect!.right - selectionRect!.right;
    final topDistance = selectionRect!.top - frameRect!.top;
    final bottomDistance = frameRect!.bottom - selectionRect!.bottom;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = scaledLineWidth
      ..style = PaintingStyle.stroke;

    // Draw horizontal distance lines
    if (leftDistance > minDistance) {
      _drawHorizontalDistance(
        canvas,
        linePaint,
        frameRect!.left,
        selectionRect!.left,
        selectionRect!.center.dy,
        leftDistance,
      );
    }

    if (rightDistance > minDistance) {
      _drawHorizontalDistance(
        canvas,
        linePaint,
        selectionRect!.right,
        frameRect!.right,
        selectionRect!.center.dy,
        rightDistance,
      );
    }

    // Draw vertical distance lines
    if (topDistance > minDistance) {
      _drawVerticalDistance(
        canvas,
        linePaint,
        frameRect!.top,
        selectionRect!.top,
        selectionRect!.center.dx,
        topDistance,
      );
    }

    if (bottomDistance > minDistance) {
      _drawVerticalDistance(
        canvas,
        linePaint,
        selectionRect!.bottom,
        frameRect!.bottom,
        selectionRect!.center.dx,
        bottomDistance,
      );
    }

    canvas.restore();
  }

  void _drawHorizontalDistance(
    Canvas canvas,
    Paint paint,
    double x1,
    double x2,
    double y,
    double distance,
  ) {
    // Draw line
    canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);

    // Draw arrows
    final scaledArrowSize = arrowSize / zoom;
    canvas.drawLine(
      Offset(x1, y),
      Offset(x1 + scaledArrowSize, y - scaledArrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x1, y),
      Offset(x1 + scaledArrowSize, y + scaledArrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x2, y),
      Offset(x2 - scaledArrowSize, y - scaledArrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x2, y),
      Offset(x2 - scaledArrowSize, y + scaledArrowSize),
      paint,
    );

    // Draw distance label
    _drawDistanceLabel(canvas, distance.round().toString(), (x1 + x2) / 2, y);
  }

  void _drawVerticalDistance(
    Canvas canvas,
    Paint paint,
    double y1,
    double y2,
    double x,
    double distance,
  ) {
    // Draw line
    canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);

    // Draw arrows
    final scaledArrowSize = arrowSize / zoom;
    canvas.drawLine(
      Offset(x, y1),
      Offset(x - scaledArrowSize, y1 + scaledArrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x, y1),
      Offset(x + scaledArrowSize, y1 + scaledArrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x, y2),
      Offset(x - scaledArrowSize, y2 - scaledArrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x, y2),
      Offset(x + scaledArrowSize, y2 - scaledArrowSize),
      paint,
    );

    // Draw distance label
    _drawDistanceLabel(canvas, distance.round().toString(), x, (y1 + y2) / 2);
  }

  void _drawDistanceLabel(Canvas canvas, String text, double x, double y) {
    final scaledFontSize = fontSize / zoom;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: scaledFontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Background
    final padding = 2 / zoom;
    final bgRect = Rect.fromCenter(
      center: Offset(x, y),
      width: textPainter.width + padding * 2,
      height: textPainter.height + padding * 2,
    );

    final bgPaint = Paint()
      ..color = textBgColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(bgRect, bgPaint);

    // Text
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(DistanceIndicatorPainter oldDelegate) {
    return selectionRect != oldDelegate.selectionRect ||
        frameRect != oldDelegate.frameRect ||
        viewMatrix != oldDelegate.viewMatrix ||
        zoom != oldDelegate.zoom;
  }
}
