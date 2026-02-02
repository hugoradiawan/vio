import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Image scale mode within shape bounds.
enum ImageScaleMode {
  /// Scale to fill bounds, cropping if necessary.
  fill,

  /// Scale to fit entirely within bounds, letterboxing if necessary.
  fit,

  /// Stretch to exactly match bounds (may distort).
  stretch,

  /// Display at original size, cropping if larger than bounds.
  original,
}

/// Image shape for raster graphics.
///
/// Note: This is a stub implementation. Full image support
/// (upload, crop, filters) is planned for Phase 5.
class ImageShape extends Shape {
  const ImageShape({
    required super.id,
    required super.name,
    required this.x,
    required this.y,
    required this.imageWidth,
    required this.imageHeight,
    this.assetId = '',
    this.originalWidth = 0,
    this.originalHeight = 0,
    this.scaleMode = ImageScaleMode.fill,
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
  }) : super(type: ShapeType.image);

  /// X position
  @override
  final double x;

  /// Y position
  @override
  final double y;

  /// Display width of image
  final double imageWidth;

  /// Display height of image
  final double imageHeight;

  /// Reference ID to the uploaded image asset
  final String assetId;

  /// Original image width in pixels
  final double originalWidth;

  /// Original image height in pixels
  final double originalHeight;

  /// How the image is scaled within its bounds
  final ImageScaleMode scaleMode;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, imageWidth, imageHeight);

  @override
  ImageShape copyWith({
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
    double? imageWidth,
    double? imageHeight,
    String? assetId,
    double? originalWidth,
    double? originalHeight,
    ImageScaleMode? scaleMode,
  }) {
    final resolvedParentId =
        identical(parentId, kUnset) ? this.parentId : parentId as String?;
    final resolvedFrameId =
        identical(frameId, kUnset) ? this.frameId : frameId as String?;

    return ImageShape(
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
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      assetId: assetId ?? this.assetId,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      scaleMode: scaleMode ?? this.scaleMode,
    );
  }

  @override
  ImageShape moveBy(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseToJson(),
        'x': x,
        'y': y,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'assetId': assetId,
        'originalWidth': originalWidth,
        'originalHeight': originalHeight,
        'scaleMode': scaleMode.name,
      };

  factory ImageShape.fromJson(Map<String, dynamic> json) => ImageShape(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        imageWidth: (json['imageWidth'] as num).toDouble(),
        imageHeight: (json['imageHeight'] as num).toDouble(),
        assetId: json['assetId'] as String? ?? '',
        originalWidth: (json['originalWidth'] as num?)?.toDouble() ?? 0,
        originalHeight: (json['originalHeight'] as num?)?.toDouble() ?? 0,
        scaleMode: ImageScaleMode.values.firstWhere(
          (e) => e.name == json['scaleMode'],
          orElse: () => ImageScaleMode.fill,
        ),
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
        imageWidth,
        imageHeight,
        assetId,
        originalWidth,
        originalHeight,
        scaleMode,
      ];
}
