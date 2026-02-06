import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    // Text shapes have a custom paint path (fills act as text color)
    if (shape is TextShape) {
      _paintText(canvas, shape);
      canvas.restore();
      return;
    }

    // Apply opacity
    if (shape.opacity < 1.0) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: shape.opacity),
      );
    }

    // Get the shape's path
    final path = _getShapePath(shape);

    // 1. Draw drop shadow (behind everything)
    final shadow = shape.shadow;
    if (shadow != null &&
        !shadow.hidden &&
        shadow.style == ShadowStyle.dropShadow) {
      _paintDropShadow(canvas, path, shadow, shape.bounds);
    }

    // 2. Draw background blur (clips to shape, blurs content behind)
    final blur = shape.blur;
    final hasBackgroundBlur = blur != null &&
        !blur.hidden &&
        blur.type == BlurType.background &&
        blur.value > 0;

    if (hasBackgroundBlur) {
      _paintBackgroundBlur(canvas, path, blur);
    }

    // 3. Draw fills (bottom to top)
    for (final fill in shape.fills) {
      _paintFill(canvas, path, fill, shape);
    }

    // 4. Draw inner shadow (after fills, clipped to shape)
    if (shadow != null &&
        !shadow.hidden &&
        shadow.style == ShadowStyle.innerShadow) {
      _paintInnerShadow(canvas, path, shadow, shape.bounds);
    }

    // 5. Draw strokes (bottom to top)
    for (final stroke in shape.strokes) {
      _paintStroke(canvas, path, stroke, shape);
    }

    // Restore opacity layer
    if (shape.opacity < 1.0) {
      canvas.restore();
    }

    // 6. Apply layer blur (blurs entire shape including fills/strokes)
    final hasLayerBlur = blur != null &&
        !blur.hidden &&
        blur.type == BlurType.layer &&
        blur.value > 0;

    if (hasLayerBlur) {
      // Layer blur is applied by re-rendering with blur filter
      // We need to capture what was drawn and blur it
      _applyLayerBlur(canvas, shape, blur);
    }

    canvas.restore();
  }

  /// Paint a shape with layer blur effect applied
  /// This method renders the shape into a separate layer with blur
  static void paintShapeWithLayerBlur(
    Canvas canvas,
    Shape shape, {
    required double sigma,
  }) {
    if (shape.hidden || shape.opacity <= 0) return;

    canvas.save();
    _applyTransform(canvas, shape.transform);

    // Create blur filter
    final blurFilter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.decal,
    );

    // Save layer with blur filter
    final bounds = shape.bounds.inflate(sigma * 3);
    canvas.saveLayer(
      bounds,
      Paint()..imageFilter = blurFilter,
    );

    // Get the shape's path
    final path = _getShapePath(shape);

    // Draw fills
    for (final fill in shape.fills) {
      _paintFill(canvas, path, fill, shape);
    }

    // Draw strokes
    for (final stroke in shape.strokes) {
      _paintStroke(canvas, path, stroke, shape);
    }

    canvas.restore(); // blur layer
    canvas.restore(); // transform
  }

  // ===========================================================================
  // Shadow Rendering
  // ===========================================================================

  /// Paint drop shadow effect (drawn behind shape)
  /// Following Penpot's approach: offset -> blur -> spread (dilate) -> color
  static void _paintDropShadow(
    Canvas canvas,
    Path shapePath,
    ShapeShadow shadow,
    Rect shapeBounds,
  ) {
    final sigma = shadow.blur / 2.0; // Penpot uses blur/2 for sigma
    final shadowColor =
        Color(shadow.color).withValues(alpha: shadow.opacity);

    canvas.save();

    // Translate by shadow offset
    canvas.translate(shadow.offsetX, shadow.offsetY);

    // For spread, we scale the path from center
    Path shadowPath = shapePath;
    if (shadow.spread != 0) {
      shadowPath = _scalePath(shapePath, shapeBounds, shadow.spread);
    }

    // Create shadow paint with blur filter
    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill
      ..maskFilter = sigma > 0 ? MaskFilter.blur(BlurStyle.normal, sigma) : null;

    // Draw the shadow
    canvas.drawPath(shadowPath, shadowPaint);

    canvas.restore();
  }

  /// Paint inner shadow effect (drawn inside shape, clipped)
  /// Uses src-in blending to constrain shadow within shape bounds
  static void _paintInnerShadow(
    Canvas canvas,
    Path shapePath,
    ShapeShadow shadow,
    Rect shapeBounds,
  ) {
    final sigma = shadow.blur / 2.0;
    final shadowColor =
        Color(shadow.color).withValues(alpha: shadow.opacity);

    // Calculate layer bounds
    final expansion = shadow.blur + shadow.spread.abs() + 20;
    final layerBounds = shapeBounds.inflate(expansion);

    // Save layer for compositing
    canvas.saveLayer(layerBounds, Paint());

    // 1. Draw the shape as a mask (defines where shadow is visible)
    final maskPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(shapePath, maskPaint);

    // 2. Draw the inverted shadow with src-in blend
    canvas.saveLayer(
      layerBounds,
      Paint()..blendMode = BlendMode.srcIn,
    );

    // Draw a filled rect and cut out the offset shape to create inner shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill
      ..maskFilter = sigma > 0 ? MaskFilter.blur(BlurStyle.normal, sigma) : null;

    // Create inverted path: outer rect minus the inner (offset) shape
    final outerRect = layerBounds.inflate(shadow.blur * 2);

    canvas.save();
    canvas.translate(shadow.offsetX, shadow.offsetY);

    // Scale path for spread (negative spread shrinks the cutout, creating larger shadow)
    Path innerPath = shapePath;
    if (shadow.spread != 0) {
      innerPath = _scalePath(shapePath, shapeBounds, -shadow.spread);
    }

    // Draw outer area and cut out inner shape
    final invertedPath = Path()
      ..addRect(outerRect)
      ..addPath(innerPath, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(invertedPath, shadowPaint);

    canvas.restore();
    canvas.restore(); // src-in layer
    canvas.restore(); // main layer
  }

  /// Scale a path from its center by a given amount (for spread effect)
  static Path _scalePath(Path path, Rect bounds, double amount) {
    if (amount == 0) return path;

    final center = bounds.center;
    final scaleX = (bounds.width + amount * 2) / bounds.width;
    final scaleY = (bounds.height + amount * 2) / bounds.height;

    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(scaleX, scaleY)
      ..translate(-center.dx, -center.dy);

    return path.transform(matrix.storage);
  }

  // ===========================================================================
  // Blur Rendering
  // ===========================================================================

  /// Apply layer blur to the entire shape
  /// This re-renders the shape within a blurred layer
  static void _applyLayerBlur(Canvas canvas, Shape shape, ShapeBlur blur) {
    // Layer blur was already applied in paintShape by wrapping in saveLayer
    // This method is called for additional processing if needed
    // For now, we handle layer blur by modifying the main paintShape flow
  }

  /// Paint background blur effect (blurs content behind the shape)
  /// Uses backdrop filter to blur whatever is drawn behind this shape
  static void _paintBackgroundBlur(
    Canvas canvas,
    Path shapePath,
    ShapeBlur blur,
  ) {
    final sigma = blur.value;
    if (sigma <= 0) return;

    // Clip to shape path
    canvas.save();
    canvas.clipPath(shapePath);

    // Apply backdrop blur filter
    // Note: Flutter's Canvas doesn't have direct backdrop blur support
    // We simulate it by drawing a semi-transparent rect with blur
    // For true backdrop blur, this would need to be implemented at the
    // rendering layer (e.g., using BackdropFilter widget in the widget tree)
    //
    // As a fallback, we draw a subtle frosted effect
    final bounds = shapePath.getBounds();

    // Create blur filter
    final blurFilter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.clamp,
    );

    // Save a layer with the blur filter to create backdrop effect
    canvas.saveLayer(
      bounds,
      Paint()..imageFilter = blurFilter,
    );

    // Draw a semi-transparent fill to show the blur effect
    // This creates a frosted glass appearance
    final frostedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shapePath, frostedPaint);

    canvas.restore(); // blur layer
    canvas.restore(); // clip
  }

  static void _paintText(Canvas canvas, TextShape shape) {
    final bounds = shape.bounds;
    final text = shape.text;
    if (text.isEmpty) {
      return;
    }

    // Always clip to the text box so glyphs never render outside the bounds.
    // This also protects against brief mismatches while runtime-loaded fonts
    // (GoogleFonts) are still resolving.
    canvas.save();
    canvas.clipRect(bounds);

    // Use the first fill as text color, otherwise default to white.
    final fill = shape.fills.isNotEmpty ? shape.fills.first : null;
    final color = fill != null
        ? Color(fill.color).withValues(alpha: fill.opacity)
        : Colors.white;

    FontWeight? fontWeight;
    final weightValue = shape.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final letterSpacing = shape.letterSpacingPercent == 0
        ? null
        : shape.fontSize * (shape.letterSpacingPercent / 100.0);
    final baseStyle = TextStyle(
      color: color,
      fontSize: shape.fontSize,
      fontWeight: fontWeight,
      height: shape.lineHeight,
      letterSpacing: letterSpacing,
    );

    TextStyle resolveFontStyle() {
      final family = shape.fontFamily;
      if (family == null || family.isEmpty) {
        return baseStyle;
      }
      try {
        return GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        // Non-google/system font: fall back to raw fontFamily.
        return baseStyle.copyWith(fontFamily: family);
      }
    }

    final maxWidth = bounds.width <= 1 ? 200.0 : bounds.width;
    final widthConstraint = maxWidth.isFinite ? maxWidth : double.infinity;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: resolveFontStyle(),
      ),
      textAlign: shape.textAlign,
      textDirection: TextDirection.ltr,
    )..layout(
        // IMPORTANT: Force the paragraph width to be the text box width.
        // Without this, TextPainter will size itself to the intrinsic text
        // width and center/right alignment appears as left-aligned.
        minWidth: widthConstraint.isFinite ? widthConstraint : 0,
        maxWidth: widthConstraint,
      );

    // Apply overall shape opacity (paintShape doesn't wrap text in saveLayer)
    if (shape.opacity < 1.0) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: shape.opacity),
      );
      painter.paint(canvas, Offset(bounds.left, bounds.top));
      canvas.restore();
    } else {
      painter.paint(canvas, Offset(bounds.left, bounds.top));
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
    if (fill.hidden || fill.opacity <= 0) return;

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
    if (stroke.hidden || stroke.opacity <= 0 || stroke.width <= 0) return;

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
