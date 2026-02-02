import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// SVG shape for vector graphics imported from SVG files.
///
/// Note: This is a stub implementation. Full SVG import/export
/// support is planned for Phase 5.
class SvgShape extends Shape {
  const SvgShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.svgWidth,
    required this.svgHeight,
    this.svgContent = '',
    this.viewBox,
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
  }) : super(type: ShapeType.svg);

  /// X position
  @override
  final double x;

  /// Y position
  @override
  final double y;

  /// Display width of SVG
  final double svgWidth;

  /// Display height of SVG
  final double svgHeight;

  /// Raw SVG content string
  final String svgContent;

  /// Original SVG viewBox (minX minY width height)
  final String? viewBox;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, svgWidth, svgHeight);

  @override
  SvgShape copyWith({
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
    double? x,
    double? y,
    double? svgWidth,
    double? svgHeight,
    String? svgContent,
    String? viewBox,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;

    return SvgShape(
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
      shadow: shadow ?? this.shadow,
      blur: blur ?? this.blur,
      x: x ?? this.x,
      y: y ?? this.y,
      svgWidth: svgWidth ?? this.svgWidth,
      svgHeight: svgHeight ?? this.svgHeight,
      svgContent: svgContent ?? this.svgContent,
      viewBox: viewBox ?? this.viewBox,
    );
  }

  @override
  SvgShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'svgWidth': svgWidth,
        'svgHeight': svgHeight,
        'svgContent': svgContent,
        if (viewBox != null) 'viewBox': viewBox,
      };

  factory SvgShape.fromJson(Map<String, dynamic> json) => SvgShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        svgWidth: (json['svgWidth'] as num).toDouble(),
        svgHeight: (json['svgHeight'] as num).toDouble(),
        svgContent: json['svgContent'] as String? ?? '',
        viewBox: json['viewBox'] as String?,
        parentId: json['parentId'] as String?,
        frameId: json['frameId'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
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
      );

  @override
  List<Object?> get props => [
        ...super.props,
        x,
        y,
        svgWidth,
        svgHeight,
        svgContent,
        viewBox,
      ];
}
