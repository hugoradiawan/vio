import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:vio_core/vio_core.dart';

/// A graphic asset (image or SVG) stored in a project.
///
/// Assets represent binary media files that can be placed on the canvas
/// as ImageShape or SvgShape. They support path-based grouping
/// using "/" as separator (e.g., "Icons/Social").
class ProjectAsset extends Equatable {
  const ProjectAsset({
    required this.id,
    required this.projectId,
    required this.name,
    required this.mimeType,
    this.path = '',
    this.width = 0,
    this.height = 0,
    this.fileSize = 0,
    this.thumbnailBytes,
    this.dataBytes,
    this.createdAt,
    this.updatedAt,
  });

  /// Unique identifier.
  final String id;

  /// Project this asset belongs to.
  final String projectId;

  /// Display name of the asset.
  final String name;

  /// Group path using "/" separator (e.g., "Icons/Social").
  /// Empty string means ungrouped.
  final String path;

  /// MIME type (e.g., "image/png", "image/svg+xml").
  final String mimeType;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// File size in bytes.
  final int fileSize;

  /// Small thumbnail for panel display. May be null if not yet loaded.
  final Uint8List? thumbnailBytes;

  /// Full binary data. Only populated when needed for canvas rendering.
  final Uint8List? dataBytes;

  /// When this asset was created.
  final DateTime? createdAt;

  /// When this asset was last updated.
  final DateTime? updatedAt;

  /// Whether this is an SVG asset.
  bool get isSvg => mimeType == 'image/svg+xml';

  /// Whether this is a raster image (PNG, JPEG, GIF, WebP).
  bool get isRaster => !isSvg;

  /// The group name (last segment of path), or empty if ungrouped.
  String get groupName {
    if (path.isEmpty) return '';
    final parts = path.split('/');
    return parts.last;
  }

  /// The parent group path (everything before the last "/").
  String get parentPath {
    if (path.isEmpty) return '';
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash < 0) return '';
    return path.substring(0, lastSlash);
  }

  ProjectAsset copyWith({
    String? id,
    String? projectId,
    String? name,
    String? path,
    String? mimeType,
    int? width,
    int? height,
    int? fileSize,
    Uint8List? thumbnailBytes,
    Uint8List? dataBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectAsset(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      path: path ?? this.path,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      dataBytes: dataBytes ?? this.dataBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'name': name,
        'path': path,
        'mimeType': mimeType,
        'width': width,
        'height': height,
        'fileSize': fileSize,
      };

  factory ProjectAsset.fromJson(Map<String, dynamic> json) => ProjectAsset(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        name: json['name'] as String,
        path: (json['path'] as String?) ?? '',
        mimeType: json['mimeType'] as String,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        projectId,
        name,
        path,
        mimeType,
        width,
        height,
        fileSize,
      ];

  @override
  String toString() =>
      'ProjectAsset(id: $id, name: $name, path: $path, mimeType: $mimeType, '
      '${width}x$height, $fileSize bytes)';
}

/// A reusable color from the project palette.
///
/// Colors can be solid hex values or gradients. They support path-based
/// grouping using "/" as separator (e.g., "Brand/Primary").
///
/// When applied to shapes, the color is referenced by ID so that
/// updating a library color can propagate to all using shapes.
class ProjectColor extends Equatable {
  const ProjectColor({
    required this.id,
    required this.projectId,
    required this.name,
    this.path = '',
    this.color,
    this.opacity = 1.0,
    this.gradient,
    this.createdAt,
    this.updatedAt,
  });

  /// Unique identifier.
  final String id;

  /// Project this color belongs to.
  final String projectId;

  /// Display name (e.g., "Primary Blue", "Gray 100").
  final String name;

  /// Group path using "/" separator. Empty string means ungrouped.
  final String path;

  /// Hex color string (e.g., "#4C9AFF"). Null if gradient-only.
  final String? color;

  /// Color opacity from 0.0 to 1.0.
  final double opacity;

  /// Gradient definition. Null for solid colors.
  final ShapeGradient? gradient;

  /// When this color was created.
  final DateTime? createdAt;

  /// When this color was last updated.
  final DateTime? updatedAt;

  /// Whether this is a gradient color (vs solid).
  bool get isGradient => gradient != null;

  /// Whether this is a solid color.
  bool get isSolid => color != null && !isGradient;

  /// Parse the hex color string to an integer ARGB value.
  /// Returns null if [color] is null or invalid.
  int? get colorValue {
    if (color == null || color!.isEmpty) return null;
    final hex = color!.replaceFirst('#', '');
    if (hex.length == 6) {
      return int.tryParse('FF$hex', radix: 16);
    }
    if (hex.length == 8) {
      return int.tryParse(hex, radix: 16);
    }
    return null;
  }

  ProjectColor copyWith({
    String? id,
    String? projectId,
    String? name,
    String? path,
    String? color,
    double? opacity,
    ShapeGradient? gradient,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearGradient = false,
  }) {
    return ProjectColor(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      path: path ?? this.path,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      gradient: clearGradient ? null : (gradient ?? this.gradient),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'name': name,
        'path': path,
        if (color != null) 'color': color,
        'opacity': opacity,
        if (gradient != null) 'gradient': gradient!.toJson(),
      };

  factory ProjectColor.fromJson(Map<String, dynamic> json) => ProjectColor(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        name: json['name'] as String,
        path: (json['path'] as String?) ?? '',
        color: json['color'] as String?,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        gradient: json['gradient'] != null
            ? ShapeGradient.fromJson(
                json['gradient'] as Map<String, dynamic>,
              )
            : null,
      );

  @override
  List<Object?> get props => [
        id,
        projectId,
        name,
        path,
        color,
        opacity,
        gradient,
      ];

  @override
  String toString() =>
      'ProjectColor(id: $id, name: $name, color: $color, opacity: $opacity)';
}
