import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

/// Utility class for rendering shapes with fills and strokes
class ShapePainter {
  ShapePainter._();

  /// Paint a shape onto the canvas
  static void paintShape(Canvas canvas, Shape shape) {
    if (shape.hidden || shape.opacity <= 0) return;

    canvas.save();

    // Apply shape transform
    _applyTransform(canvas, shape.transform);

    // Apply opacity
    if (shape.opacity < 1.0) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: shape.opacity),
      );
    }

    // Get the shape's path
    final path = _getShapePath(shape);

    // Draw fills (bottom to top)
    for (final fill in shape.fills) {
      _paintFill(canvas, path, fill, shape);
    }

    // Draw strokes (bottom to top)
    for (final stroke in shape.strokes) {
      _paintStroke(canvas, path, stroke, shape);
    }

    // Restore opacity layer
    if (shape.opacity < 1.0) {
      canvas.restore();
    }

    canvas.restore();
  }

  /// Apply the shape's transformation matrix to the canvas
  static void _applyTransform(Canvas canvas, Matrix2D matrix) {
    canvas.transform(
      Float64List.fromList([
        matrix.a,
        matrix.b,
        0,
        0,
        matrix.c,
        matrix.d,
        0,
        0,
        0,
        0,
        1,
        0,
        matrix.e,
        matrix.f,
        0,
        1,
      ]),
    );
  }

  /// Get the path for a shape based on its type
  static Path _getShapePath(Shape shape) {
    final bounds = shape.bounds;
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );

    switch (shape.type) {
      case ShapeType.rectangle:
        return _getRectanglePath(shape as RectangleShape, rect);
      case ShapeType.ellipse:
        return _getEllipsePath(rect);
      case ShapeType.frame:
        return _getFramePath(shape as FrameShape, rect);
      case ShapeType.path:
      case ShapeType.text:
      case ShapeType.group:
      case ShapeType.image:
      case ShapeType.svg:
      case ShapeType.bool:
        // For now, just use a rectangle for unsupported types
        return Path()..addRect(rect);
    }
  }

  /// Get path for a rectangle shape (with optional corner radii)
  static Path _getRectanglePath(RectangleShape shape, Rect rect) {
    final path = Path();

    // Check if we have corner radii
    final hasRadii =
        shape.r1 > 0 || shape.r2 > 0 || shape.r3 > 0 || shape.r4 > 0;

    if (!hasRadii) {
      path.addRect(rect);
    } else {
      // Create rounded rectangle with per-corner radii
      path.addRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(shape.r1),
          topRight: Radius.circular(shape.r2),
          bottomRight: Radius.circular(shape.r3),
          bottomLeft: Radius.circular(shape.r4),
        ),
      );
    }

    return path;
  }

  /// Get path for an ellipse shape
  static Path _getEllipsePath(Rect rect) {
    return Path()..addOval(rect);
  }

  /// Get path for a frame shape
  static Path _getFramePath(FrameShape shape, Rect rect) {
    final path = Path();
    // Frames are always rectangular (no corner radius support yet)
    path.addRect(rect);
    return path;
  }

  /// Paint a fill onto a path
  static void _paintFill(
    Canvas canvas,
    Path path,
    ShapeFill fill,
    Shape shape,
  ) {
    if (fill.opacity <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Check for gradient first
    if (fill.gradient != null) {
      paint.shader = _createGradientShader(fill.gradient!, shape.bounds);
    } else {
      paint.color = Color(fill.color).withValues(alpha: fill.opacity);
    }

    canvas.drawPath(path, paint);
  }

  /// Paint a stroke onto a path
  static void _paintStroke(
    Canvas canvas,
    Path path,
    ShapeStroke stroke,
    Shape shape,
  ) {
    if (stroke.opacity <= 0 || stroke.width <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Color(stroke.color).withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.width
      ..strokeCap = _mapStrokeCap(stroke.cap)
      ..strokeJoin = _mapStrokeJoin(stroke.join);

    // Handle stroke alignment
    switch (stroke.alignment) {
      case StrokeAlignment.center:
        canvas.drawPath(path, paint);
      case StrokeAlignment.inside:
        canvas.save();
        canvas.clipPath(path);
        paint.strokeWidth = stroke.width * 2;
        canvas.drawPath(path, paint);
        canvas.restore();
      case StrokeAlignment.outside:
        canvas.save();
        // Create inverse clip (outside the path)
        final bounds = path.getBounds();
        final outerPath = Path()
          ..addRect(bounds.inflate(stroke.width * 2))
          ..addPath(path, Offset.zero);
        outerPath.fillType = PathFillType.evenOdd;
        canvas.clipPath(outerPath);
        paint.strokeWidth = stroke.width * 2;
        canvas.drawPath(path, paint);
        canvas.restore();
    }
  }

  /// Create a gradient shader from a ShapeGradient
  static ui.Shader _createGradientShader(
    ShapeGradient gradient,
    Rect bounds,
  ) {
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );

    final colors = gradient.stops.map((s) => Color(s.color)).toList();
    final stops = gradient.stops.map((s) => s.offset).toList();

    // Calculate gradient points in shape coordinates
    final startX = rect.left + gradient.startX * rect.width;
    final startY = rect.top + gradient.startY * rect.height;
    final endX = rect.left + gradient.endX * rect.width;
    final endY = rect.top + gradient.endY * rect.height;

    switch (gradient.type) {
      case GradientType.linear:
        return ui.Gradient.linear(
          Offset(startX, startY),
          Offset(endX, endY),
          colors,
          stops,
        );
      case GradientType.radial:
        final center = Offset(startX, startY);
        final radius = (Offset(endX, endY) - center).distance;
        return ui.Gradient.radial(
          center,
          radius,
          colors,
          stops,
        );
    }
  }

  /// Map our StrokeCap to Flutter's StrokeCap
  static ui.StrokeCap _mapStrokeCap(StrokeCap cap) {
    return switch (cap) {
      StrokeCap.butt => ui.StrokeCap.butt,
      StrokeCap.round => ui.StrokeCap.round,
      StrokeCap.square => ui.StrokeCap.square,
    };
  }

  /// Map our StrokeJoin to Flutter's StrokeJoin
  static ui.StrokeJoin _mapStrokeJoin(StrokeJoin join) {
    return switch (join) {
      StrokeJoin.miter => ui.StrokeJoin.miter,
      StrokeJoin.round => ui.StrokeJoin.round,
      StrokeJoin.bevel => ui.StrokeJoin.bevel,
    };
  }
}
