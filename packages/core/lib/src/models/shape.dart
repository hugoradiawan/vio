import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Base class for all shape types on the canvas
///
/// This mirrors Penpot's shape model from common/src/app/common/types/shape.cljc
/// All shapes have:
/// - Unique ID
/// - Transform matrix for position/rotation/scale
/// - Selection rectangle (selrect)
/// - Fill and stroke properties
/// - Parent frame reference
abstract class Shape extends Equatable {
  const Shape({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.frameId,
    this.transform = Matrix2D.identity,
    this.transformInverse,
    this.selrect,
    this.fills = const [],
    this.strokes = const [],
    this.opacity = 1.0,
    this.hidden = false,
    this.blocked = false,
    this.rotation = 0.0,
    this.constraints,
    this.shadow,
    this.blur,
  });

  /// Unique identifier for this shape
  final String id;

  /// Display name of the shape
  final String name;

  /// Type discriminator (rectangle, ellipse, path, text, frame, etc.)
  final ShapeType type;

  /// Parent shape ID (for groups/frames)
  final String? parentId;

  /// Frame this shape belongs to
  final String? frameId;

  /// Transformation matrix (position, rotation, scale, skew)
  final Matrix2D transform;

  /// Cached inverse of transform matrix
  final Matrix2D? transformInverse;

  /// Selection rectangle in parent coordinates
  final Rect? selrect;

  /// Fill styles
  final List<ShapeFill> fills;

  /// Stroke styles
  final List<ShapeStroke> strokes;

  /// Opacity (0.0 - 1.0)
  final double opacity;

  /// Whether shape is hidden
  final bool hidden;

  /// Whether shape is locked from editing
  final bool blocked;

  /// Rotation in degrees
  final double rotation;

  /// Layout constraints
  final ShapeConstraints? constraints;

  /// Shadow effect
  final ShapeShadow? shadow;

  /// Blur effect
  final ShapeBlur? blur;

  /// Get the bounds of this shape in local coordinates
  Rect get bounds;

  /// X position (abstract - implemented by concrete shape types)
  double get x;

  /// Y position (abstract - implemented by concrete shape types)
  double get y;

  /// Create a copy of this shape moved by the given delta
  Shape moveBy(double dx, double dy);

  /// Create a duplicate of this shape with a new ID and optional position offset
  /// Used for copy/paste and duplicate operations
  Shape duplicate({
    required String newId,
    double offsetX = 0,
    double offsetY = 0,
    String? newName,
  }) {
    final baseDuplicate = copyWith(
      id: newId,
      name: newName ?? '$name Copy',
    );
    if (offsetX != 0 || offsetY != 0) {
      return baseDuplicate.moveBy(offsetX, offsetY);
    }
    return baseDuplicate;
  }

  /// Get the center point in local coordinates
  Offset get center => bounds.center;

  /// Get the width
  double get width => bounds.width;

  /// Get the height
  double get height => bounds.height;

  /// Get position (top-left)
  Offset get position => bounds.topLeft;

  /// Transform a point from local to parent coordinates
  Offset transformPoint(Offset local) {
    final result = transform.transformPoint(local.dx, local.dy);
    return Offset(result.x, result.y);
  }

  /// Transform a point from parent to local coordinates
  Offset inverseTransformPoint(Offset parent) {
    final inverse = transformInverse ?? transform.inverse;
    if (inverse == null) return parent;
    final result = inverse.transformPoint(parent.dx, parent.dy);
    return Offset(result.x, result.y);
  }

  /// Create a copy with updated properties
  Shape copyWith({
    String? id,
    String? name,
    String? parentId,
    String? frameId,
    Matrix2D? transform,
    Matrix2D? transformInverse,
    Rect? selrect,
    List<ShapeFill>? fills,
    List<ShapeStroke>? strokes,
    double? opacity,
    bool? hidden,
    bool? blocked,
    double? rotation,
    ShapeConstraints? constraints,
    ShapeShadow? shadow,
    ShapeBlur? blur,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        parentId,
        frameId,
        transform,
        selrect,
        fills,
        strokes,
        opacity,
        hidden,
        blocked,
        rotation,
        constraints,
        shadow,
        blur,
      ];
}

/// Shape type discriminator
enum ShapeType {
  rectangle,
  ellipse,
  path,
  text,
  frame,
  group,
  image,
  svg,
  bool,
}

/// Fill style for shapes
class ShapeFill extends Equatable {
  const ShapeFill({
    required this.color,
    this.opacity = 1.0,
    this.gradient,
    this.fillImage,
  });

  /// Solid color (hex)
  final int color;

  /// Fill opacity
  final double opacity;

  /// Gradient fill (optional)
  final ShapeGradient? gradient;

  /// Image fill (optional)
  final ShapeFillImage? fillImage;

  @override
  List<Object?> get props => [color, opacity, gradient, fillImage];
}

/// Stroke style for shapes
class ShapeStroke extends Equatable {
  const ShapeStroke({
    required this.color,
    this.width = 1.0,
    this.opacity = 1.0,
    this.alignment = StrokeAlignment.center,
    this.cap = StrokeCap.round,
    this.join = StrokeJoin.round,
  });

  /// Stroke color (hex)
  final int color;

  /// Stroke width
  final double width;

  /// Stroke opacity
  final double opacity;

  /// Stroke alignment (inside, center, outside)
  final StrokeAlignment alignment;

  /// Line cap style
  final StrokeCap cap;

  /// Line join style
  final StrokeJoin join;

  @override
  List<Object?> get props => [color, width, opacity, alignment, cap, join];
}

/// Stroke alignment options
enum StrokeAlignment { inside, center, outside }

/// Stroke cap styles
enum StrokeCap { butt, round, square }

/// Stroke join styles
enum StrokeJoin { miter, round, bevel }

/// Gradient definition
class ShapeGradient extends Equatable {
  const ShapeGradient({
    required this.type,
    required this.stops,
    this.startX = 0.0,
    this.startY = 0.0,
    this.endX = 1.0,
    this.endY = 1.0,
  });

  final GradientType type;
  final List<GradientStop> stops;
  final double startX;
  final double startY;
  final double endX;
  final double endY;

  @override
  List<Object?> get props => [type, stops, startX, startY, endX, endY];
}

/// Gradient types
enum GradientType { linear, radial }

/// Gradient color stop
class GradientStop extends Equatable {
  const GradientStop({
    required this.color,
    required this.offset,
    this.opacity = 1.0,
  });

  final int color;
  final double offset;
  final double opacity;

  @override
  List<Object?> get props => [color, offset, opacity];
}

/// Image fill definition
class ShapeFillImage extends Equatable {
  const ShapeFillImage({required this.id, this.width, this.height, this.mtype});

  final String id;
  final double? width;
  final double? height;
  final String? mtype;

  @override
  List<Object?> get props => [id, width, height, mtype];
}

/// Layout constraints
class ShapeConstraints extends Equatable {
  const ShapeConstraints({
    this.horizontal = ConstraintType.left,
    this.vertical = ConstraintType.top,
  });

  final ConstraintType horizontal;
  final ConstraintType vertical;

  @override
  List<Object?> get props => [horizontal, vertical];
}

/// Constraint types
enum ConstraintType {
  left,
  right,
  leftAndRight,
  center,
  scale,
  top,
  bottom,
  topAndBottom,
}

/// Shadow effect
class ShapeShadow extends Equatable {
  const ShapeShadow({
    this.id,
    this.style = ShadowStyle.dropShadow,
    this.color = 0x000000,
    this.opacity = 0.25,
    this.offsetX = 0.0,
    this.offsetY = 4.0,
    this.blur = 8.0,
    this.spread = 0.0,
    this.hidden = false,
  });

  final String? id;
  final ShadowStyle style;
  final int color;
  final double opacity;
  final double offsetX;
  final double offsetY;
  final double blur;
  final double spread;
  final bool hidden;

  @override
  List<Object?> get props => [
        id,
        style,
        color,
        opacity,
        offsetX,
        offsetY,
        blur,
        spread,
        hidden,
      ];
}

/// Shadow styles
enum ShadowStyle { dropShadow, innerShadow }

/// Blur effect
class ShapeBlur extends Equatable {
  const ShapeBlur({
    this.id,
    this.type = BlurType.layer,
    this.value = 0.0,
    this.hidden = false,
  });

  final String? id;
  final BlurType type;
  final double value;
  final bool hidden;

  @override
  List<Object?> get props => [id, type, value, hidden];
}

/// Blur types
enum BlurType { layer, background }
