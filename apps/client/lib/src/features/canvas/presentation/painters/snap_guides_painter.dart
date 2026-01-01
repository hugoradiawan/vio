import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

/// Painter for snap guide lines and markers
class SnapGuidesPainter extends CustomPainter {
  SnapGuidesPainter({
    required this.viewMatrix,
    required this.snapLines,
    required this.snapPoints,
    required this.zoom,
  });

  final Matrix2D viewMatrix;
  final List<SnapLine> snapLines;
  final List<SnapPoint> snapPoints;
  final double zoom;

  // Snap guide colors
  static const Color snapLineColor = Color(0xFFE53935); // Red
  static const Color snapCenterColor = Color(0xFF43A047); // Green for centers
  static const double lineWidth = 1.0;
  static const double dashLength = 4.0;
  static const double dashGap = 4.0;
  static const double crossSize = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (snapLines.isEmpty && snapPoints.isEmpty) return;

    canvas.save();

    // Apply view transformation
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

    // Draw snap lines
    for (final line in snapLines) {
      _drawSnapLine(canvas, line);
    }

    // Draw snap point markers
    for (final point in snapPoints) {
      _drawSnapPoint(canvas, point);
    }

    canvas.restore();
  }

  void _drawSnapLine(Canvas canvas, SnapLine line) {
    final color = line.isCenter ? snapCenterColor : snapLineColor;
    final scaledLineWidth = lineWidth / zoom;

    final paint = Paint()
      ..color = color
      ..strokeWidth = scaledLineWidth
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    final path = ui.Path();
    path.moveTo(line.start.dx, line.start.dy);
    path.lineTo(line.end.dx, line.end.dy);

    // Calculate dash pattern scaled by zoom
    final scaledDashLength = dashLength / zoom;
    final scaledDashGap = dashGap / zoom;

    _drawDashedPath(canvas, path, paint, scaledDashLength, scaledDashGap);
  }

  void _drawDashedPath(
    Canvas canvas,
    ui.Path path,
    Paint paint,
    double dashLength,
    double dashGap,
  ) {
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;

      while (distance < metric.length) {
        final length = draw ? dashLength : dashGap;
        final end = (distance + length).clamp(0.0, metric.length);

        if (draw) {
          final extractPath = metric.extractPath(distance, end);
          canvas.drawPath(extractPath, paint);
        }

        distance = end;
        draw = !draw;
      }
    }
  }

  void _drawSnapPoint(Canvas canvas, SnapPoint point) {
    final color =
        point.type == SnapPointType.center ? snapCenterColor : snapLineColor;
    final scaledCrossSize = crossSize / zoom;
    final scaledLineWidth = lineWidth / zoom;

    final paint = Paint()
      ..color = color
      ..strokeWidth = scaledLineWidth
      ..style = PaintingStyle.stroke;

    // Draw X cross marker
    canvas.drawLine(
      Offset(point.x - scaledCrossSize, point.y - scaledCrossSize),
      Offset(point.x + scaledCrossSize, point.y + scaledCrossSize),
      paint,
    );
    canvas.drawLine(
      Offset(point.x - scaledCrossSize, point.y + scaledCrossSize),
      Offset(point.x + scaledCrossSize, point.y - scaledCrossSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(SnapGuidesPainter oldDelegate) {
    return snapLines != oldDelegate.snapLines ||
        snapPoints != oldDelegate.snapPoints ||
        viewMatrix != oldDelegate.viewMatrix ||
        zoom != oldDelegate.zoom;
  }
}
