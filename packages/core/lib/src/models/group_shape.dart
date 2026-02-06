import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Group shape (folder) used to organize layers.
///
/// Groups are containers in the layer tree via `parentId` relationships.
///
/// Coordinates are kept absolute (like the rest of Vio currently). When a group
/// is moved, the CanvasBloc explicitly moves its descendants.
class GroupShape extends Shape {
  const GroupShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.groupWidth,
    required this.groupHeight,
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
  }) : super(type: ShapeType.group);

  /// X position
  @override
  final double x;

  /// Y position
  @override
  final double y;

  /// Width
  final double groupWidth;

  /// Height
  final double groupHeight;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, groupWidth, groupHeight);

  @override
  GroupShape copyWith({
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
    double? groupWidth,
    double? groupHeight,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;
    final resolvedShadow =
        identical(shadow, kUnset) ? this.shadow : shadow as ShapeShadow?;
    final resolvedBlur =
        identical(blur, kUnset) ? this.blur : blur as ShapeBlur?;

    return GroupShape(
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
      groupWidth: groupWidth ?? this.groupWidth,
      groupHeight: groupHeight ?? this.groupHeight,
    );
  }

  @override
  GroupShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'groupWidth': groupWidth,
        'groupHeight': groupHeight,
      };

  factory GroupShape.fromJson(Map<String, dynamic> json) => GroupShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        groupWidth: (json['groupWidth'] as num).toDouble(),
        groupHeight: (json['groupHeight'] as num).toDouble(),
        parentId: json['parentId'] as String?,
        frameId: json['frameId'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        transform: json['transform'] != null
            ? Matrix2D.fromJson(json['transform'] as Map<String, dynamic>)
            : Matrix2D.identity,
        transformInverse: json['transformInverse'] != null
            ? Matrix2D.fromJson(
                json['transformInverse'] as Map<String, dynamic>,)
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
                json['constraints'] as Map<String, dynamic>,)
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
        groupWidth,
        groupHeight,
      ];
}
