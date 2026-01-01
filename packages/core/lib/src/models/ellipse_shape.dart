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
  final double x;

  /// Y position (top edge)
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
  Rect get bounds =>
      Rect.fromLTWH(x, y, ellipseWidth, ellipseHeight);

  @override
  Offset get center => Offset(centerX, centerY);
  @override
  EllipseShape copyWith({
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
    double? x,
    double? y,
    double? ellipseWidth,
    double? ellipseHeight,
  }) {
    return EllipseShape(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      frameId: frameId ?? this.frameId,
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
      shadow: shadow ?? this.shadow,
      blur: blur ?? this.blur,
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
  List<Object?> get props => [
    ...super.props,
    x,
    y,
    ellipseWidth,
    ellipseHeight,
  ];
}
