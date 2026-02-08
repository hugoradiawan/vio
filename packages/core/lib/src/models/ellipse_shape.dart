import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Ellipse shape (circles are ellipses with equal width/height)
class EllipseShape extends Shape {
  const EllipseShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.ellipseWidth,
    required this.ellipseHeight,
    super.parentId,
    super.frameId,
    super.sortOrder = 0,
    super.transform = Matrix2D.identity,
    super.transformInverse,
    super.selrect,
    super.fills,
    super.strokes,
    super.opacity,
    super.hidden,
    super.blocked,
    super.rotation,
    super.constraints,
    super.shadow,
    super.blur,
  }) : super(type: ShapeType.ellipse);

  /// X position (left edge)
  @override
  final double x;

  /// Y position (top edge)
  @override
  final double y;

  /// Width
  final double ellipseWidth;

  /// Height
  final double ellipseHeight;

  /// Whether this is a perfect circle
  bool get isCircle => ellipseWidth == ellipseHeight;

  /// Get the radius for circles (or horizontal radius for ellipses)
  double get radiusX => ellipseWidth / 2;

  /// Get the vertical radius
  double get radiusY => ellipseHeight / 2;

  /// Get the center X coordinate
  double get centerX => x + radiusX;

  /// Get the center Y coordinate
  double get centerY => y + radiusY;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, ellipseWidth, ellipseHeight);

  @override
  Offset get center => Offset(centerX, centerY);
  @override
  EllipseShape copyWith({
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
    Object? shadow = kUnset,
    Object? blur = kUnset,
    double? x,
    double? y,
    double? ellipseWidth,
    double? ellipseHeight,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;
    final resolvedShadow =
        identical(shadow, kUnset) ? this.shadow : shadow as ShapeShadow?;
    final resolvedBlur =
        identical(blur, kUnset) ? this.blur : blur as ShapeBlur?;

    return EllipseShape(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: resolvedParentId,
      frameId: resolvedFrameId,
      sortOrder: sortOrder ?? this.sortOrder,
      transform: transform ?? this.transform,
      transformInverse: transformInverse ?? this.transformInverse,
      selrect: selrect ?? this.selrect,
      fills: fills ?? this.fills,
      strokes: strokes ?? this.strokes,
      opacity: opacity ?? this.opacity,
      hidden: hidden ?? this.hidden,
      blocked: blocked ?? this.blocked,
      rotation: rotation ?? this.rotation,
      constraints: constraints ?? this.constraints,
      shadow: resolvedShadow,
      blur: resolvedBlur,
      x: x ?? this.x,
      y: y ?? this.y,
      ellipseWidth: ellipseWidth ?? this.ellipseWidth,
      ellipseHeight: ellipseHeight ?? this.ellipseHeight,
    );
  }

  @override
  EllipseShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'ellipseWidth': ellipseWidth,
        'ellipseHeight': ellipseHeight,
      };

  factory EllipseShape.fromJson(Map<String, dynamic> json) => EllipseShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        ellipseWidth: (json['ellipseWidth'] as num).toDouble(),
        ellipseHeight: (json['ellipseHeight'] as num).toDouble(),
        parentId: json['parentId'] as String?,
        frameId: json['frameId'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        transform: json['transform'] != null
            ? Matrix2D.fromJson(json['transform'] as Map<String, dynamic>)
            : Matrix2D.identity,
        transformInverse: json['transformInverse'] != null
            ? Matrix2D.fromJson(
                json['transformInverse'] as Map<String, dynamic>,
              )
            : null,
        fills: (json['fills'] as List?)
                ?.map((f) => ShapeFill.fromJson(f as Map<String, dynamic>))
                .toList() ??
            const [],
        strokes: (json['strokes'] as List?)
                ?.map((s) => ShapeStroke.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: json['hidden'] as bool? ?? false,
        blocked: json['blocked'] as bool? ?? false,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        constraints: json['constraints'] != null
            ? ShapeConstraints.fromJson(
                json['constraints'] as Map<String, dynamic>,
              )
            : null,
        shadow: json['shadow'] != null
            ? ShapeShadow.fromJson(json['shadow'] as Map<String, dynamic>)
            : null,
        blur: json['blur'] != null
            ? ShapeBlur.fromJson(json['blur'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [
        ...super.props,
        x,
        y,
        ellipseWidth,
        ellipseHeight,
      ];
}
