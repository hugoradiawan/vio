import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Sentinel value for copyWith parameters where we need to distinguish between
/// "not provided" and "explicitly set to null".
///
/// Example: `shape.copyWith(frameId: null)` should clear the frameId, while
/// omitting `frameId` should keep the existing value.
const Object kUnset = Object();

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
    this.sortOrder = 0,
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

  /// Explicit z-order among siblings (lower renders behind higher).
  ///
  /// This is interpreted within the shape's effective container:
  /// - `parentId` when it points to a `GroupShape`
  /// - otherwise `frameId` when it points to a `FrameShape`
  /// - otherwise the root canvas
  final int sortOrder;

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
    Object? parentId = kUnset,
    Object? frameId = kUnset,
    int? sortOrder,
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

  /// Convert shape to JSON for serialization
  Map<String, dynamic> toJson();

  /// Create a shape from JSON data
  static Shape fromJson(Map<String, dynamic> json) {
    final type = ShapeType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ShapeType.rectangle,
    );

    switch (type) {
      case ShapeType.rectangle:
        return RectangleShape.fromJson(json);
      case ShapeType.ellipse:
        return EllipseShape.fromJson(json);
      case ShapeType.frame:
        return FrameShape.fromJson(json);
      case ShapeType.text:
        return TextShape.fromJson(json);
      case ShapeType.group:
        return GroupShape.fromJson(json);
      case ShapeType.path:
        return PathShape.fromJson(json);
      case ShapeType.image:
        return ImageShape.fromJson(json);
      case ShapeType.svg:
        return SvgShape.fromJson(json);
      case ShapeType.bool:
        return BoolShape.fromJson(json);
    }
  }

  /// Helper to serialize base shape properties
  Map<String, dynamic> baseToJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (parentId != null) 'parentId': parentId,
        if (frameId != null) 'frameId': frameId,
        'sortOrder': sortOrder,
        'transform': transform.toJson(),
        if (transformInverse != null)
          'transformInverse': transformInverse!.toJson(),
        if (selrect != null)
          'selrect': {
            'left': selrect!.left,
            'top': selrect!.top,
            'right': selrect!.right,
            'bottom': selrect!.bottom,
          },
        'fills': fills.map((f) => f.toJson()).toList(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'opacity': opacity,
        'hidden': hidden,
        'blocked': blocked,
        'rotation': rotation,
        if (constraints != null) 'constraints': constraints!.toJson(),
        if (shadow != null) 'shadow': shadow!.toJson(),
        if (blur != null) 'blur': blur!.toJson(),
      };

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        parentId,
        frameId,
        sortOrder,
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
    this.hidden = false,
    this.gradient,
    this.fillImage,
  });

  /// Solid color (hex)
  final int color;

  /// Fill opacity
  final double opacity;

  /// Whether this fill is hidden
  final bool hidden;

  /// Gradient fill (optional)
  final ShapeGradient? gradient;

  /// Image fill (optional)
  final ShapeFillImage? fillImage;

  /// Create a copy with updated properties
  ShapeFill copyWith({
    int? color,
    double? opacity,
    bool? hidden,
    ShapeGradient? gradient,
    ShapeFillImage? fillImage,
  }) {
    return ShapeFill(
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      hidden: hidden ?? this.hidden,
      gradient: gradient ?? this.gradient,
      fillImage: fillImage ?? this.fillImage,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color,
        'opacity': opacity,
        'hidden': hidden,
        if (gradient != null) 'gradient': gradient!.toJson(),
        if (fillImage != null) 'fillImage': fillImage!.toJson(),
      };

  factory ShapeFill.fromJson(Map<String, dynamic> json) => ShapeFill(
        color: json['color'] as int,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: json['hidden'] as bool? ?? false,
        gradient: json['gradient'] != null
            ? ShapeGradient.fromJson(json['gradient'] as Map<String, dynamic>)
            : null,
        fillImage: json['fillImage'] != null
            ? ShapeFillImage.fromJson(json['fillImage'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [color, opacity, hidden, gradient, fillImage];
}

/// Stroke style for shapes
class ShapeStroke extends Equatable {
  const ShapeStroke({
    required this.color,
    this.width = 1.0,
    this.opacity = 1.0,
    this.hidden = false,
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

  /// Whether this stroke is hidden
  final bool hidden;

  /// Stroke alignment (inside, center, outside)
  final StrokeAlignment alignment;

  /// Line cap style
  final StrokeCap cap;

  /// Line join style
  final StrokeJoin join;

  /// Create a copy with updated properties
  ShapeStroke copyWith({
    int? color,
    double? width,
    double? opacity,
    bool? hidden,
    StrokeAlignment? alignment,
    StrokeCap? cap,
    StrokeJoin? join,
  }) {
    return ShapeStroke(
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      hidden: hidden ?? this.hidden,
      alignment: alignment ?? this.alignment,
      cap: cap ?? this.cap,
      join: join ?? this.join,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color,
        'width': width,
        'opacity': opacity,
        'hidden': hidden,
        'alignment': alignment.name,
        'cap': cap.name,
        'join': join.name,
      };

  factory ShapeStroke.fromJson(Map<String, dynamic> json) => ShapeStroke(
        color: json['color'] as int,
        width: (json['width'] as num?)?.toDouble() ?? 1.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: json['hidden'] as bool? ?? false,
        alignment: StrokeAlignment.values.firstWhere(
          (e) => e.name == json['alignment'],
          orElse: () => StrokeAlignment.center,
        ),
        cap: StrokeCap.values.firstWhere(
          (e) => e.name == json['cap'],
          orElse: () => StrokeCap.round,
        ),
        join: StrokeJoin.values.firstWhere(
          (e) => e.name == json['join'],
          orElse: () => StrokeJoin.round,
        ),
      );

  @override
  List<Object?> get props =>
      [color, width, opacity, hidden, alignment, cap, join];
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

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'stops': stops.map((s) => s.toJson()).toList(),
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
      };

  factory ShapeGradient.fromJson(Map<String, dynamic> json) => ShapeGradient(
        type: GradientType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => GradientType.linear,
        ),
        stops: (json['stops'] as List)
            .map((s) => GradientStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        startX: (json['startX'] as num?)?.toDouble() ?? 0.0,
        startY: (json['startY'] as num?)?.toDouble() ?? 0.0,
        endX: (json['endX'] as num?)?.toDouble() ?? 1.0,
        endY: (json['endY'] as num?)?.toDouble() ?? 1.0,
      );

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

  Map<String, dynamic> toJson() => {
        'color': color,
        'offset': offset,
        'opacity': opacity,
      };

  factory GradientStop.fromJson(Map<String, dynamic> json) => GradientStop(
        color: json['color'] as int,
        offset: (json['offset'] as num).toDouble(),
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      );

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

  Map<String, dynamic> toJson() => {
        'id': id,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (mtype != null) 'mtype': mtype,
      };

  factory ShapeFillImage.fromJson(Map<String, dynamic> json) => ShapeFillImage(
        id: json['id'] as String,
        width: (json['width'] as num?)?.toDouble(),
        height: (json['height'] as num?)?.toDouble(),
        mtype: json['mtype'] as String?,
      );

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

  Map<String, dynamic> toJson() => {
        'horizontal': horizontal.name,
        'vertical': vertical.name,
      };

  factory ShapeConstraints.fromJson(Map<String, dynamic> json) =>
      ShapeConstraints(
        horizontal: ConstraintType.values.firstWhere(
          (e) => e.name == json['horizontal'],
          orElse: () => ConstraintType.left,
        ),
        vertical: ConstraintType.values.firstWhere(
          (e) => e.name == json['vertical'],
          orElse: () => ConstraintType.top,
        ),
      );

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

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'style': style.name,
        'color': color,
        'opacity': opacity,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'blur': blur,
        'spread': spread,
        'hidden': hidden,
      };

  factory ShapeShadow.fromJson(Map<String, dynamic> json) => ShapeShadow(
        id: json['id'] as String?,
        style: ShadowStyle.values.firstWhere(
          (e) => e.name == json['style'],
          orElse: () => ShadowStyle.dropShadow,
        ),
        color: json['color'] as int? ?? 0x000000,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.25,
        offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
        offsetY: (json['offsetY'] as num?)?.toDouble() ?? 4.0,
        blur: (json['blur'] as num?)?.toDouble() ?? 8.0,
        spread: (json['spread'] as num?)?.toDouble() ?? 0.0,
        hidden: json['hidden'] as bool? ?? false,
      );

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

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'type': type.name,
        'value': value,
        'hidden': hidden,
      };

  factory ShapeBlur.fromJson(Map<String, dynamic> json) => ShapeBlur(
        id: json['id'] as String?,
        type: BlurType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => BlurType.layer,
        ),
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        hidden: json['hidden'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, type, value, hidden];
}

/// Blur types
enum BlurType { layer, background }
