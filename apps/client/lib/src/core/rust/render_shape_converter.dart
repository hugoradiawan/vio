import 'dart:ui' as ui;

import 'package:vio_core/vio_core.dart';

import '../../rust/math/matrix2d.dart' as frb;
import '../../rust/scene_graph/shape.dart' as frb;

/// Converts core [Shape] objects to FRB-generated [frb.RenderShape] objects
/// for use with the Rust canvas engine.
///
/// This is a pure, stateless converter — every call is independent.
class RenderShapeConverter {
  const RenderShapeConverter._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Convert a single core [Shape] to a Rust [frb.RenderShape].
  ///
  /// The Dart model stores position in **both** `shape.x`/`shape.y` (local
  /// bounding-box origin) and `shape.transform` (affine matrix with `e`/`f`
  /// translation). The Rust pipeline draws everything at local origin
  /// `(0, 0, w, h)`, so we must bake the `(x, y)` offset into the transform.
  ///
  /// Composed transform = original_transform × translation(x, y):
  ///   new_e = a·x + c·y + e
  ///   new_f = b·x + d·y + f
  static frb.RenderShape toRenderShape(Shape shape) {
    return frb.RenderShape(
      id: shape.id,
      shapeType: _convertShapeType(shape.type),
      transform: _convertMatrixWithOffset(shape.transform, shape.x, shape.y),
      parentId: shape.parentId,
      frameId: shape.frameId,
      sortOrder: shape.sortOrder,
      opacity: shape.opacity,
      hidden: shape.hidden,
      rotation: shape.rotation,
      fills: shape.fills.map(_convertFill).toList(),
      strokes: shape.strokes.map(_convertStroke).toList(),
      shadow: shape.shadow != null ? _convertShadow(shape.shadow!) : null,
      blur: shape.blur != null ? _convertBlur(shape.blur!) : null,
      geometry: _convertGeometry(shape),
    );
  }

  /// Convert a map of shapes to a list of [frb.RenderShape].
  static List<frb.RenderShape> toRenderShapes(Map<String, Shape> shapes) {
    return shapes.values.map(toRenderShape).toList();
  }

  /// Compute the diff between two shape maps and return (added, updated, removed).
  ///
  /// This is the core delta-sync logic: given old and new shape maps, it
  /// produces the minimal set of changes to send to Rust.
  static ({
    List<frb.RenderShape> added,
    List<frb.RenderShape> updated,
    List<String> removed,
  }) diffShapes(
    Map<String, Shape> oldShapes,
    Map<String, Shape> newShapes,
  ) {
    final added = <frb.RenderShape>[];
    final updated = <frb.RenderShape>[];
    final removed = <String>[];

    // Find added and updated
    for (final entry in newShapes.entries) {
      final oldShape = oldShapes[entry.key];
      if (oldShape == null) {
        added.add(toRenderShape(entry.value));
      } else if (oldShape != entry.value) {
        updated.add(toRenderShape(entry.value));
      }
    }

    // Find removed
    for (final key in oldShapes.keys) {
      if (!newShapes.containsKey(key)) {
        removed.add(key);
      }
    }

    return (added: added, updated: updated, removed: removed);
  }

  // ---------------------------------------------------------------------------
  // Type conversions
  // ---------------------------------------------------------------------------

  // static frb.Matrix2D _convertMatrix(Matrix2D m) {
  //   return frb.Matrix2D(a: m.a, b: m.b, c: m.c, d: m.d, e: m.e, f: m.f);
  // }

  /// Convert a [Matrix2D] while composing an additional (x, y) translation.
  ///
  /// Rust draws at `(0, 0)`, so shape.x/y must be folded into the matrix.
  /// Result = transform × translate(x, y):
  ///   e' = a·x + c·y + e,  f' = b·x + d·y + f
  static frb.Matrix2D _convertMatrixWithOffset(
    Matrix2D m,
    double x,
    double y,
  ) {
    return frb.Matrix2D(
      a: m.a,
      b: m.b,
      c: m.c,
      d: m.d,
      e: m.a * x + m.c * y + m.e,
      f: m.b * x + m.d * y + m.f,
    );
  }

  static frb.ShapeType _convertShapeType(ShapeType type) {
    return switch (type) {
      ShapeType.rectangle => frb.ShapeType.rectangle,
      ShapeType.ellipse => frb.ShapeType.ellipse,
      ShapeType.text => frb.ShapeType.text,
      ShapeType.frame => frb.ShapeType.frame,
      ShapeType.group => frb.ShapeType.group,
      ShapeType.path => frb.ShapeType.path,
      ShapeType.image => frb.ShapeType.image,
      ShapeType.svg => frb.ShapeType.svg,
      ShapeType.bool => frb.ShapeType.bool,
    };
  }

  static frb.ShapeFill _convertFill(ShapeFill fill) {
    return frb.ShapeFill(
      color: fill.color,
      opacity: fill.opacity,
      hidden: fill.hidden,
      gradient:
          fill.gradient != null ? _convertGradient(fill.gradient!) : null,
    );
  }

  static frb.ShapeStroke _convertStroke(ShapeStroke stroke) {
    return frb.ShapeStroke(
      color: stroke.color,
      width: stroke.width,
      opacity: stroke.opacity,
      hidden: stroke.hidden,
      alignment: _convertStrokeAlignment(stroke.alignment),
      cap: _convertStrokeCap(stroke.cap),
      join: _convertStrokeJoin(stroke.join),
    );
  }

  static frb.ShapeShadow _convertShadow(ShapeShadow shadow) {
    return frb.ShapeShadow(
      style: _convertShadowStyle(shadow.style),
      color: shadow.color,
      opacity: shadow.opacity,
      offsetX: shadow.offsetX,
      offsetY: shadow.offsetY,
      blur: shadow.blur,
      spread: shadow.spread,
      hidden: shadow.hidden,
    );
  }

  static frb.ShapeBlur _convertBlur(ShapeBlur blur) {
    return frb.ShapeBlur(
      blurType: _convertBlurType(blur.type),
      value: blur.value,
      hidden: blur.hidden,
    );
  }

  static frb.ShapeGradient _convertGradient(ShapeGradient gradient) {
    return frb.ShapeGradient(
      gradientType: _convertGradientType(gradient.type),
      stops: gradient.stops.map(_convertGradientStop).toList(),
      startX: gradient.startX,
      startY: gradient.startY,
      endX: gradient.endX,
      endY: gradient.endY,
    );
  }

  static frb.GradientStop _convertGradientStop(GradientStop stop) {
    // Core GradientStop has `offset`, `color`, `opacity`.
    // FRB GradientStop only has `offset`, `color`.
    // We bake opacity into the alpha channel of the color.
    final alpha = (stop.opacity * ((stop.color >> 24) & 0xFF)).round();
    final colorWithOpacity = (alpha << 24) | (stop.color & 0x00FFFFFF);
    return frb.GradientStop(
      offset: stop.offset,
      color: colorWithOpacity,
    );
  }

  // ---------------------------------------------------------------------------
  // Enum conversions
  // ---------------------------------------------------------------------------

  static frb.StrokeAlignment _convertStrokeAlignment(
    StrokeAlignment alignment,
  ) {
    return switch (alignment) {
      StrokeAlignment.center => frb.StrokeAlignment.center,
      StrokeAlignment.inside => frb.StrokeAlignment.inside,
      StrokeAlignment.outside => frb.StrokeAlignment.outside,
    };
  }

  static frb.StrokeCap _convertStrokeCap(StrokeCap cap) {
    return switch (cap) {
      StrokeCap.butt => frb.StrokeCap.butt,
      StrokeCap.round => frb.StrokeCap.round,
      StrokeCap.square => frb.StrokeCap.square,
    };
  }

  static frb.StrokeJoin _convertStrokeJoin(StrokeJoin join) {
    return switch (join) {
      StrokeJoin.miter => frb.StrokeJoin.miter,
      StrokeJoin.round => frb.StrokeJoin.round,
      StrokeJoin.bevel => frb.StrokeJoin.bevel,
    };
  }

  static frb.ShadowStyle _convertShadowStyle(ShadowStyle style) {
    return switch (style) {
      ShadowStyle.dropShadow => frb.ShadowStyle.drop,
      ShadowStyle.innerShadow => frb.ShadowStyle.inner,
    };
  }

  static frb.BlurType _convertBlurType(BlurType type) {
    return switch (type) {
      BlurType.layer => frb.BlurType.layer,
      BlurType.background => frb.BlurType.background,
    };
  }

  static frb.GradientType _convertGradientType(GradientType type) {
    return switch (type) {
      GradientType.linear => frb.GradientType.linear,
      GradientType.radial => frb.GradientType.radial,
    };
  }

  static frb.TextAlign _convertTextAlign(ui.TextAlign align) {
    return switch (align) {
      ui.TextAlign.left => frb.TextAlign.left,
      ui.TextAlign.center => frb.TextAlign.center,
      ui.TextAlign.right => frb.TextAlign.right,
      ui.TextAlign.justify => frb.TextAlign.justify,
      // Map start/end to left/right (LTR default)
      ui.TextAlign.start => frb.TextAlign.left,
      ui.TextAlign.end => frb.TextAlign.right,
    };
  }

  static frb.BoolOp _convertBoolOperation(BoolOperation op) {
    return switch (op) {
      BoolOperation.union => frb.BoolOp.union,
      BoolOperation.subtract => frb.BoolOp.subtract,
      BoolOperation.intersect => frb.BoolOp.intersect,
      BoolOperation.exclude => frb.BoolOp.exclude,
    };
  }

  // ---------------------------------------------------------------------------
  // Geometry conversion (dispatch by concrete Shape type)
  // ---------------------------------------------------------------------------

  static frb.ShapeGeometry _convertGeometry(Shape shape) {
    return switch (shape) {
      final RectangleShape s => frb.ShapeGeometry.rectangle(
          width: s.rectWidth,
          height: s.rectHeight,
          r1: s.r1,
          r2: s.r2,
          r3: s.r3,
          r4: s.r4,
        ),
      final EllipseShape s => frb.ShapeGeometry.ellipse(
          width: s.ellipseWidth,
          height: s.ellipseHeight,
        ),
      final TextShape s => frb.ShapeGeometry.text(
          width: s.textWidth,
          height: s.textHeight,
          text: s.text,
          fontSize: s.fontSize,
          fontFamily: s.fontFamily ?? 'Inter',
          fontWeight: s.fontWeight ?? 400,
          lineHeight: s.lineHeight ?? 1.2,
          letterSpacingPercent: s.letterSpacingPercent,
          textAlign: _convertTextAlign(s.textAlign),
        ),
      final FrameShape s => frb.ShapeGeometry.frame(
          width: s.frameWidth,
          height: s.frameHeight,
          clipContent: s.clipContent,
        ),
      final GroupShape s => frb.ShapeGeometry.group(
          width: s.groupWidth,
          height: s.groupHeight,
        ),
      final PathShape s => frb.ShapeGeometry.path(
          width: s.pathWidth,
          height: s.pathHeight,
          pathData: s.pathData,
          closed: s.closed,
        ),
      final ImageShape s => frb.ShapeGeometry.image(
          width: s.imageWidth,
          height: s.imageHeight,
          assetId: s.assetId,
        ),
      final SvgShape s => frb.ShapeGeometry.svg(
          width: s.svgWidth,
          height: s.svgHeight,
          svgContent: s.svgContent,
        ),
      final BoolShape s => frb.ShapeGeometry.bool(
          width: s.boolWidth,
          height: s.boolHeight,
          operation: _convertBoolOperation(s.operation),
        ),
      _ => throw ArgumentError(
          'Unknown shape type: ${shape.runtimeType}',
        ),
    };
  }
}
