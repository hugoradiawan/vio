import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Rectangle shape with optional corner radii
class RectangleShape extends Shape {
  const RectangleShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.rectWidth,
    required this.rectHeight,
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
    this.r1 = 0.0,
    this.r2 = 0.0,
    this.r3 = 0.0,
    this.r4 = 0.0,
  }) : super(type: ShapeType.rectangle);

  /// X position
  final double x;

  /// Y position
  final double y;

  /// Width
  final double rectWidth;

  /// Height
  final double rectHeight;

  /// Top-left corner radius
  final double r1;

  /// Top-right corner radius
  final double r2;

  /// Bottom-right corner radius
  final double r3;

  /// Bottom-left corner radius
  final double r4;

  /// Whether all corners have the same radius
  bool get hasUniformCorners => r1 == r2 && r2 == r3 && r3 == r4;

  /// Get uniform corner radius (or 0 if not uniform)
  double get cornerRadius => hasUniformCorners ? r1 : 0;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, rectWidth, rectHeight);

  @override
  RectangleShape copyWith({
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
    double? rectWidth,
    double? rectHeight,
    double? r1,
    double? r2,
    double? r3,
    double? r4,
  }) {
    return RectangleShape(
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
      rectWidth: rectWidth ?? this.rectWidth,
      rectHeight: rectHeight ?? this.rectHeight,
      r1: r1 ?? this.r1,
      r2: r2 ?? this.r2,
      r3: r3 ?? this.r3,
      r4: r4 ?? this.r4,
    );
  }

  @override
  RectangleShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'rectWidth': rectWidth,
        'rectHeight': rectHeight,
        'r1': r1,
        'r2': r2,
        'r3': r3,
        'r4': r4,
      };

  factory RectangleShape.fromJson(Map<String, dynamic> json) => RectangleShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        rectWidth: (json['rectWidth'] as num).toDouble(),
        rectHeight: (json['rectHeight'] as num).toDouble(),
        parentId: json['parentId'] as String?,
        frameId: json['frameId'] as String?,
        transform: json['transform'] != null
            ? Matrix2D.fromJson(json['transform'] as Map<String, dynamic>)
            : Matrix2D.identity,
        transformInverse: json['transformInverse'] != null
            ? Matrix2D.fromJson(
                json['transformInverse'] as Map<String, dynamic>)
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
                json['constraints'] as Map<String, dynamic>)
            : null,
        shadow: json['shadow'] != null
            ? ShapeShadow.fromJson(json['shadow'] as Map<String, dynamic>)
            : null,
        blur: json['blur'] != null
            ? ShapeBlur.fromJson(json['blur'] as Map<String, dynamic>)
            : null,
        r1: (json['r1'] as num?)?.toDouble() ?? 0.0,
        r2: (json['r2'] as num?)?.toDouble() ?? 0.0,
        r3: (json['r3'] as num?)?.toDouble() ?? 0.0,
        r4: (json['r4'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  List<Object?> get props => [
        ...super.props,
        x,
        y,
        rectWidth,
        rectHeight,
        r1,
        r2,
        r3,
        r4,
      ];
}
