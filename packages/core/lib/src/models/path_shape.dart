import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Path shape for vector graphics with bezier curves.
///
/// Note: This is a stub implementation. Full path editing support
/// (pen tool, bezier handles) is planned for Phase 5.
class PathShape extends Shape {
  const PathShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.pathWidth,
    required this.pathHeight,
    this.pathData = '',
    this.closed = false,
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
  }) : super(type: ShapeType.path);

  /// X position
  @override
  final double x;

  /// Y position
  @override
  final double y;

  /// Width of path bounding box
  final double pathWidth;

  /// Height of path bounding box
  final double pathHeight;

  /// SVG-like path data string (e.g., "M 0 0 L 100 100 Z")
  final String pathData;

  /// Whether the path is closed (end connects to start)
  final bool closed;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, pathWidth, pathHeight);

  @override
  PathShape copyWith({
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
    double? pathWidth,
    double? pathHeight,
    String? pathData,
    bool? closed,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;
    final resolvedShadow =
        identical(shadow, kUnset) ? this.shadow : shadow as ShapeShadow?;
    final resolvedBlur =
        identical(blur, kUnset) ? this.blur : blur as ShapeBlur?;

    return PathShape(
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
      pathWidth: pathWidth ?? this.pathWidth,
      pathHeight: pathHeight ?? this.pathHeight,
      pathData: pathData ?? this.pathData,
      closed: closed ?? this.closed,
    );
  }

  @override
  PathShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'pathWidth': pathWidth,
        'pathHeight': pathHeight,
        'pathData': pathData,
        'closed': closed,
      };

  factory PathShape.fromJson(Map<String, dynamic> json) => PathShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pathWidth: (json['pathWidth'] as num).toDouble(),
        pathHeight: (json['pathHeight'] as num).toDouble(),
        pathData: json['pathData'] as String? ?? '',
        closed: json['closed'] as bool? ?? false,
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
        pathWidth,
        pathHeight,
        pathData,
        closed,
      ];
}
