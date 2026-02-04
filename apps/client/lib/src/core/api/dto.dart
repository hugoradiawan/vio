import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Extension for converting Shape to/from JSON for API communication
extension ShapeDto on Shape {
  /// Convert shape to JSON map for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'parentId': parentId,
      'frameId': frameId,
      'sortOrder': sortOrder,
      'transformA': transform.a,
      'transformB': transform.b,
      'transformC': transform.c,
      'transformD': transform.d,
      'transformE': transform.e,
      'transformF': transform.f,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'fills': fills.map(_fillToJson).toList(),
      'strokes': strokes.map(_strokeToJson).toList(),
      'opacity': opacity,
      'hidden': hidden,
      'blocked': blocked,
      'properties': _getTypeSpecificProperties(),
    };
  }

  Map<String, dynamic> _fillToJson(ShapeFill fill) {
    return {
      'color': fill.color,
      'opacity': fill.opacity,
      'hidden': fill.hidden,
      if (fill.gradient != null) 'gradient': _gradientToJson(fill.gradient!),
    };
  }

  Map<String, dynamic> _strokeToJson(ShapeStroke stroke) {
    return {
      'color': stroke.color,
      'width': stroke.width,
      'opacity': stroke.opacity,
      'hidden': stroke.hidden,
      'alignment': stroke.alignment.name,
      'cap': stroke.cap.name,
      'join': stroke.join.name,
    };
  }

  Map<String, dynamic> _gradientToJson(ShapeGradient gradient) {
    return {
      'type': gradient.type.name,
      'stops': gradient.stops
          .map(
            (s) => <String, dynamic>{
              'color': s.color,
              'offset': s.offset,
              'opacity': s.opacity,
            },
          )
          .toList(),
      'startX': gradient.startX,
      'startY': gradient.startY,
      'endX': gradient.endX,
      'endY': gradient.endY,
    };
  }

  Map<String, dynamic> _getTypeSpecificProperties() {
    if (this is RectangleShape) {
      final rect = this as RectangleShape;
      return {
        'r1': rect.r1,
        'r2': rect.r2,
        'r3': rect.r3,
        'r4': rect.r4,
      };
    }
    if (this is TextShape) {
      final text = this as TextShape;
      return {
        'text': text.text,
        'fontSize': text.fontSize,
        if (text.fontFamily != null) 'fontFamily': text.fontFamily,
        if (text.fontWeight != null) 'fontWeight': text.fontWeight,
        'textAlign': text.textAlign.name,
      };
    }
    // EllipseShape has no extra properties beyond x, y, width, height
    return {};
  }
}

/// Factory for creating Shape from JSON API response
class ShapeFactory {
  ShapeFactory._();

  /// Create a Shape from JSON map
  static Shape fromJson(Map<String, dynamic> json) {
    final type = _parseShapeType(json['type'] as String);
    final sortOrder = (json['sortOrder'] as num?)?.toInt() ?? 0;

    VioLogger.debug(
      'ShapeFactory.fromJson: parsing shape ${json['id']} type=$type',
    );

    // Support both formats for transform:
    // 1. Flat format: transformA, transformB, etc. (from DB shapes table)
    // 2. Nested format: transform: { a, b, c, d, e, f } (from some snapshots)
    Matrix2D transform;
    final rawTransform = json['transform'];
    if (rawTransform != null && rawTransform is Map) {
      final nestedTransform = Map<String, dynamic>.from(rawTransform);
      transform = Matrix2D(
        a: (nestedTransform['a'] as num?)?.toDouble() ?? 1.0,
        b: (nestedTransform['b'] as num?)?.toDouble() ?? 0.0,
        c: (nestedTransform['c'] as num?)?.toDouble() ?? 0.0,
        d: (nestedTransform['d'] as num?)?.toDouble() ?? 1.0,
        e: (nestedTransform['e'] as num?)?.toDouble() ?? 0.0,
        f: (nestedTransform['f'] as num?)?.toDouble() ?? 0.0,
      );
    } else {
      transform = Matrix2D(
        a: (json['transformA'] as num?)?.toDouble() ?? 1.0,
        b: (json['transformB'] as num?)?.toDouble() ?? 0.0,
        c: (json['transformC'] as num?)?.toDouble() ?? 0.0,
        d: (json['transformD'] as num?)?.toDouble() ?? 1.0,
        e: (json['transformE'] as num?)?.toDouble() ?? 0.0,
        f: (json['transformF'] as num?)?.toDouble() ?? 0.0,
      );
    }

    final fills = _parseFills(json['fills']);
    final strokes = _parseStrokes(json['strokes']);

    // Properties may be Map<dynamic, dynamic> from jsonDecode, need to convert
    final rawProperties = json['properties'];
    final properties = rawProperties != null
        ? Map<String, dynamic>.from(rawProperties as Map)
        : <String, dynamic>{};

    // frameId can come from json directly or from properties (for shapes nested in frames)
    final frameId =
        json['frameId'] as String? ?? properties['frameId'] as String?;

    // Parse shadow from properties
    ShapeShadow? shadow;
    final rawShadow = properties['shadow'];
    if (rawShadow != null && rawShadow is Map) {
      try {
        shadow = ShapeShadow.fromJson(Map<String, dynamic>.from(rawShadow));
      } catch (_) {
        // Ignore malformed shadow data
      }
    }

    // Parse blur from properties
    ShapeBlur? blur;
    final rawBlur = properties['blur'];
    if (rawBlur != null && rawBlur is Map) {
      try {
        blur = ShapeBlur.fromJson(Map<String, dynamic>.from(rawBlur));
      } catch (_) {
        // Ignore malformed blur data
      }
    }

    switch (type) {
      case ShapeType.rectangle:
        return RectangleShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          rectWidth: (json['width'] as num).toDouble(),
          rectHeight: (json['height'] as num).toDouble(),
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
          r1: (properties['r1'] as num?)?.toDouble() ?? 0.0,
          r2: (properties['r2'] as num?)?.toDouble() ?? 0.0,
          r3: (properties['r3'] as num?)?.toDouble() ?? 0.0,
          r4: (properties['r4'] as num?)?.toDouble() ?? 0.0,
        );

      case ShapeType.ellipse:
        return EllipseShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          ellipseWidth: (json['width'] as num).toDouble(),
          ellipseHeight: (json['height'] as num).toDouble(),
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
        );

      case ShapeType.frame:
        // Support both width/height and frameWidth/frameHeight formats
        final frameWidth = (json['frameWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            100.0;
        final frameHeight = (json['frameHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            100.0;
        return FrameShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
          clipContent: properties['clipContent'] as bool? ?? true,
        );

      case ShapeType.text:
        return TextShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          textWidth: (json['width'] as num?)?.toDouble() ?? 1.0,
          textHeight: (json['height'] as num?)?.toDouble() ?? 1.0,
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          text: properties['text'] as String? ?? '',
          fontSize: (properties['fontSize'] as num?)?.toDouble() ?? 16.0,
          fontFamily: properties['fontFamily'] as String?,
          fontWeight: (properties['fontWeight'] as num?)?.toInt(),
          textAlign: TextAlign.values.firstWhere(
            (TextAlign e) => e.name == (properties['textAlign'] as String?),
            orElse: () => TextAlign.left,
          ),
          shadow: shadow,
          blur: blur,
        );

      case ShapeType.group:
        // Support both groupWidth/groupHeight and width/height formats
        final groupWidth = (json['groupWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            100.0;
        final groupHeight = (json['groupHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            100.0;
        return GroupShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          groupWidth: groupWidth,
          groupHeight: groupHeight,
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
        );

      case ShapeType.path:
        final pathWidth = (json['pathWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            100.0;
        final pathHeight = (json['pathHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            100.0;
        return PathShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          pathWidth: pathWidth,
          pathHeight: pathHeight,
          pathData: (properties['pathData'] as String?) ?? '',
          closed: properties['closed'] as bool? ?? false,
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
        );

      case ShapeType.image:
        final imageWidth = (json['imageWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            100.0;
        final imageHeight = (json['imageHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            100.0;
        return ImageShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          assetId: (properties['assetId'] as String?) ?? '',
          originalWidth:
              (properties['originalWidth'] as num?)?.toDouble() ?? 0,
          originalHeight:
              (properties['originalHeight'] as num?)?.toDouble() ?? 0,
          scaleMode: ImageScaleMode.values.firstWhere(
            (e) => e.name == properties['scaleMode'],
            orElse: () => ImageScaleMode.fill,
          ),
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
        );

      case ShapeType.svg:
        final svgWidth = (json['svgWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            100.0;
        final svgHeight = (json['svgHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            100.0;
        return SvgShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          svgWidth: svgWidth,
          svgHeight: svgHeight,
          svgContent: (properties['svgContent'] as String?) ?? '',
          viewBox: properties['viewBox'] as String?,
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
        );

      case ShapeType.bool:
        final boolWidth = (json['boolWidth'] as num?)?.toDouble() ??
            (json['width'] as num?)?.toDouble() ??
            100.0;
        final boolHeight = (json['boolHeight'] as num?)?.toDouble() ??
            (json['height'] as num?)?.toDouble() ??
            100.0;
        return BoolShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          boolWidth: boolWidth,
          boolHeight: boolHeight,
          operation: BoolOperation.values.firstWhere(
            (e) => e.name == properties['operation'],
            orElse: () => BoolOperation.union,
          ),
          sourceShapeIds: (properties['sourceShapeIds'] as List?)
                  ?.map((e) => e as String)
                  .toList() ??
              const [],
          parentId: json['parentId'] as String?,
          frameId: frameId,
          sortOrder: sortOrder,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          shadow: shadow,
          blur: blur,
        );
    }
  }

  static ShapeType _parseShapeType(String type) {
    return ShapeType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => ShapeType.rectangle,
    );
  }

  static List<ShapeFill> _parseFills(dynamic fillsJson) {
    if (fillsJson == null) return [];
    if (fillsJson is! List) return [];

    return fillsJson.map<ShapeFill>((f) {
      final fill = Map<String, dynamic>.from(f as Map);
      return ShapeFill(
        color: fill['color'] as int,
        opacity: (fill['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: fill['hidden'] as bool? ?? false,
        gradient: fill['gradient'] != null
            ? _parseGradient(Map<String, dynamic>.from(fill['gradient'] as Map))
            : null,
      );
    }).toList();
  }

  static List<ShapeStroke> _parseStrokes(dynamic strokesJson) {
    if (strokesJson == null) return [];
    if (strokesJson is! List) return [];

    return strokesJson.map<ShapeStroke>((s) {
      final stroke = Map<String, dynamic>.from(s as Map);
      return ShapeStroke(
        color: stroke['color'] as int,
        width: (stroke['width'] as num?)?.toDouble() ?? 1.0,
        opacity: (stroke['opacity'] as num?)?.toDouble() ?? 1.0,
        hidden: stroke['hidden'] as bool? ?? false,
        alignment: _parseStrokeAlignment(stroke['alignment'] as String?),
        cap: _parseStrokeCap(stroke['cap'] as String?),
        join: _parseStrokeJoin(stroke['join'] as String?),
      );
    }).toList();
  }

  static ShapeGradient _parseGradient(Map<String, dynamic> json) {
    return ShapeGradient(
      type: GradientType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => GradientType.linear,
      ),
      stops: (json['stops'] as List).map<GradientStop>((s) {
        final stop = Map<String, dynamic>.from(s as Map);
        return GradientStop(
          color: stop['color'] as int,
          offset: (stop['offset'] as num).toDouble(),
          opacity: (stop['opacity'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList(),
      startX: (json['startX'] as num?)?.toDouble() ?? 0.0,
      startY: (json['startY'] as num?)?.toDouble() ?? 0.0,
      endX: (json['endX'] as num?)?.toDouble() ?? 1.0,
      endY: (json['endY'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static StrokeAlignment _parseStrokeAlignment(String? alignment) {
    return StrokeAlignment.values.firstWhere(
      (a) => a.name == alignment,
      orElse: () => StrokeAlignment.center,
    );
  }

  static StrokeCap _parseStrokeCap(String? cap) {
    return StrokeCap.values.firstWhere(
      (c) => c.name == cap,
      orElse: () => StrokeCap.round,
    );
  }

  static StrokeJoin _parseStrokeJoin(String? join) {
    return StrokeJoin.values.firstWhere(
      (j) => j.name == join,
      orElse: () => StrokeJoin.round,
    );
  }
}

/// Project DTO for API communication
class ProjectDto {
  ProjectDto({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.isPublic,
    this.description,
    this.teamId,
    this.defaultBranchId,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectDto.fromJson(Map<String, dynamic> json) {
    return ProjectDto(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerId: json['ownerId'] as String,
      teamId: json['teamId'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
      defaultBranchId: json['defaultBranchId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String? teamId;
  final bool isPublic;
  final String? defaultBranchId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'teamId': teamId,
      'isPublic': isPublic,
      'defaultBranchId': defaultBranchId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Branch DTO for API communication
class BranchDto {
  BranchDto({
    required this.id,
    required this.projectId,
    required this.name,
    required this.isDefault,
    required this.isProtected,
    required this.createdById,
    this.description,
    this.headCommitId,
    this.createdAt,
    this.updatedAt,
  });

  factory BranchDto.fromJson(Map<String, dynamic> json) {
    return BranchDto(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      headCommitId: json['headCommitId'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      isProtected: json['isProtected'] as bool? ?? false,
      createdById: json['createdById'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  final String id;
  final String projectId;
  final String name;
  final String? description;
  final String? headCommitId;
  final bool isDefault;
  final bool isProtected;
  final String createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'name': name,
      'description': description,
      'headCommitId': headCommitId,
      'isDefault': isDefault,
      'isProtected': isProtected,
      'createdById': createdById,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Canvas state DTO representing the shapes on the canvas
class CanvasStateDto {
  CanvasStateDto({
    required this.shapes,
    this.version,
    this.lastModified,
  });

  factory CanvasStateDto.fromJson(Map<String, dynamic> json) {
    final shapesJson = json['shapes'] as List<dynamic>? ?? [];
    return CanvasStateDto(
      shapes: shapesJson
          .map((s) => ShapeFactory.fromJson(s as Map<String, dynamic>))
          .toList(),
      version: json['version'] as int?,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
    );
  }

  final List<Shape> shapes;
  final int? version;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() {
    return {
      'shapes': shapes.map((s) => s.toJson()).toList(),
      'version': version,
      'lastModified': lastModified?.toIso8601String(),
    };
  }
}

/// Sync request for auto-sync operations
class SyncRequestDto {
  SyncRequestDto({
    required this.shapes,
    required this.localVersion,
    required this.operations,
  });

  final List<Shape> shapes;
  final int localVersion;
  final List<SyncOperation> operations;

  Map<String, dynamic> toJson() {
    return {
      'shapes': shapes.map((s) => s.toJson()).toList(),
      'localVersion': localVersion,
      'operations': operations.map((o) => o.toJson()).toList(),
    };
  }
}

/// Sync response from server
class SyncResponseDto {
  SyncResponseDto({
    required this.success,
    required this.serverVersion,
    this.shapes,
    this.conflicts,
    this.message,
  });

  factory SyncResponseDto.fromJson(Map<String, dynamic> json) {
    final shapesJson = json['shapes'] as List<dynamic>?;
    return SyncResponseDto(
      success: json['success'] as bool,
      serverVersion: json['serverVersion'] as int,
      shapes: shapesJson
          ?.map((s) => ShapeFactory.fromJson(s as Map<String, dynamic>))
          .toList(),
      conflicts: json['conflicts'] as List<dynamic>?,
      message: json['message'] as String?,
    );
  }

  final bool success;
  final int serverVersion;
  final List<Shape>? shapes;
  final List<dynamic>? conflicts;
  final String? message;
}

/// Types of sync operations
enum SyncOperationType { create, update, delete }

/// Individual sync operation
class SyncOperation {
  SyncOperation({
    required this.type,
    required this.shapeId,
    required this.timestamp,
    this.shape,
  });

  final SyncOperationType type;
  final String shapeId;
  final Shape? shape;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'shapeId': shapeId,
      'shape': shape?.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================================
// Version Control DTOs
// ============================================================================

/// Commit data transfer object
class CommitDto {
  CommitDto({
    required this.id,
    required this.projectId,
    required this.branchId,
    required this.message,
    required this.authorId,
    required this.snapshotId,
    required this.createdAt,
    this.parentId,
    this.authorName,
    this.authorEmail,
  });

  factory CommitDto.fromJson(Map<String, dynamic> json) {
    return CommitDto(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      branchId: json['branchId'] as String,
      message: json['message'] as String,
      authorId: json['authorId'] as String,
      snapshotId: json['snapshotId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      parentId: json['parentId'] as String?,
      authorName: json['authorName'] as String?,
      authorEmail: json['authorEmail'] as String?,
    );
  }

  final String id;
  final String projectId;
  final String branchId;
  final String message;
  final String authorId;
  final String snapshotId;
  final DateTime createdAt;
  final String? parentId;
  final String? authorName;
  final String? authorEmail;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'branchId': branchId,
        'message': message,
        'authorId': authorId,
        'snapshotId': snapshotId,
        'createdAt': createdAt.toIso8601String(),
        if (parentId != null) 'parentId': parentId,
        if (authorName != null) 'authorName': authorName,
        if (authorEmail != null) 'authorEmail': authorEmail,
      };
}

/// Pull request status enum
enum PullRequestStatus { open, merged, closed }

/// Pull request data transfer object
class PullRequestDto {
  PullRequestDto({
    required this.id,
    required this.projectId,
    required this.sourceBranchId,
    required this.targetBranchId,
    required this.title,
    required this.authorId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.reviewerIds = const [],
    this.mergedAt,
    this.closedAt,
    this.sourceBranchName,
    this.targetBranchName,
  });

  factory PullRequestDto.fromJson(Map<String, dynamic> json) {
    return PullRequestDto(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      sourceBranchId: json['sourceBranchId'] as String,
      targetBranchId: json['targetBranchId'] as String,
      title: json['title'] as String,
      authorId: json['authorId'] as String,
      status: _parsePRStatus(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      description: json['description'] as String?,
      reviewerIds: (json['reviewers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mergedAt: json['mergedAt'] != null
          ? DateTime.parse(json['mergedAt'] as String)
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
      sourceBranchName: json['sourceBranchName'] as String?,
      targetBranchName: json['targetBranchName'] as String?,
    );
  }

  static PullRequestStatus _parsePRStatus(String status) {
    switch (status) {
      case 'merged':
        return PullRequestStatus.merged;
      case 'closed':
        return PullRequestStatus.closed;
      case 'open':
      default:
        return PullRequestStatus.open;
    }
  }

  final String id;
  final String projectId;
  final String sourceBranchId;
  final String targetBranchId;
  final String title;
  final String? description;
  final String authorId;
  final PullRequestStatus status;
  final List<String> reviewerIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? mergedAt;
  final DateTime? closedAt;
  final String? sourceBranchName;
  final String? targetBranchName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'sourceBranchId': sourceBranchId,
        'targetBranchId': targetBranchId,
        'title': title,
        'description': description,
        'authorId': authorId,
        'status': status.name,
        'reviewers': reviewerIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (mergedAt != null) 'mergedAt': mergedAt!.toIso8601String(),
        if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
      };
}

/// Pull request detail with additional context (branches, conflicts, etc.)
class PullRequestDetailDto {
  PullRequestDetailDto({
    required this.pullRequest,
    this.sourceBranch,
    this.targetBranch,
    this.mergeable = false,
    this.conflicts = const [],
    this.diffStats,
  });

  final PullRequestDto pullRequest;
  final BranchDto? sourceBranch;
  final BranchDto? targetBranch;
  final bool mergeable;
  final List<ShapeConflictDto> conflicts;
  final DiffStatsDto? diffStats;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Diff statistics
class DiffStatsDto {
  DiffStatsDto({
    this.shapesAdded = 0,
    this.shapesModified = 0,
    this.shapesDeleted = 0,
  });

  final int shapesAdded;
  final int shapesModified;
  final int shapesDeleted;
}

/// Merge strategy enum
enum MergeStrategy { fastForward, mergeCommit, squash }

/// Shape change type for diff visualization
enum ShapeChangeType { added, modified, deleted }

/// Individual shape change in a diff
class ShapeChangeDto {
  ShapeChangeDto({
    required this.shapeId,
    required this.shapeName,
    required this.changeType,
    this.beforeShape,
    this.afterShape,
    this.changedProperties = const [],
  });

  factory ShapeChangeDto.fromJson(Map<String, dynamic> json) {
    return ShapeChangeDto(
      shapeId: json['shapeId'] as String,
      shapeName: json['shapeName'] as String,
      changeType: _parseChangeType(json['changeType'] as String),
      beforeShape: json['beforeShape'] != null
          ? ShapeFactory.fromJson(json['beforeShape'] as Map<String, dynamic>)
          : null,
      afterShape: json['afterShape'] != null
          ? ShapeFactory.fromJson(json['afterShape'] as Map<String, dynamic>)
          : null,
      changedProperties: (json['changedProperties'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  static ShapeChangeType _parseChangeType(String type) {
    switch (type) {
      case 'added':
        return ShapeChangeType.added;
      case 'deleted':
        return ShapeChangeType.deleted;
      case 'modified':
      default:
        return ShapeChangeType.modified;
    }
  }

  final String shapeId;
  final String shapeName;
  final ShapeChangeType changeType;
  final Shape? beforeShape;
  final Shape? afterShape;
  final List<String> changedProperties;
}

/// Diff result between two commits or branches
class DiffResultDto {
  DiffResultDto({
    required this.changes,
    required this.addedCount,
    required this.modifiedCount,
    required this.deletedCount,
  });

  factory DiffResultDto.fromJson(Map<String, dynamic> json) {
    return DiffResultDto(
      changes: (json['changes'] as List<dynamic>?)
              ?.map((e) => ShapeChangeDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      addedCount: (json['addedCount'] as num?)?.toInt() ?? 0,
      modifiedCount: (json['modifiedCount'] as num?)?.toInt() ?? 0,
      deletedCount: (json['deletedCount'] as num?)?.toInt() ?? 0,
    );
  }

  final List<ShapeChangeDto> changes;
  final int addedCount;
  final int modifiedCount;
  final int deletedCount;

  int get totalChanges => addedCount + modifiedCount + deletedCount;
}

/// Property-level conflict information
class PropertyConflictDto {
  PropertyConflictDto({
    required this.propertyName,
    required this.baseValue,
    required this.sourceValue,
    required this.targetValue,
  });

  factory PropertyConflictDto.fromJson(Map<String, dynamic> json) {
    return PropertyConflictDto(
      propertyName: json['propertyName'] as String,
      baseValue: json['baseValue'],
      sourceValue: json['sourceValue'],
      targetValue: json['targetValue'],
    );
  }

  final String propertyName;
  final dynamic baseValue;
  final dynamic sourceValue;
  final dynamic targetValue;
}

/// Shape-level conflict with property details
class ShapeConflictDto {
  ShapeConflictDto({
    required this.shapeId,
    required this.shapeName,
    required this.propertyConflicts,
    this.baseShape,
    this.sourceShape,
    this.targetShape,
  });

  factory ShapeConflictDto.fromJson(Map<String, dynamic> json) {
    return ShapeConflictDto(
      shapeId: json['shapeId'] as String,
      shapeName: json['shapeName'] as String,
      propertyConflicts: (json['propertyConflicts'] as List<dynamic>?)
              ?.map(
                (e) => PropertyConflictDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      baseShape: json['baseShape'] != null
          ? ShapeFactory.fromJson(json['baseShape'] as Map<String, dynamic>)
          : null,
      sourceShape: json['sourceShape'] != null
          ? ShapeFactory.fromJson(json['sourceShape'] as Map<String, dynamic>)
          : null,
      targetShape: json['targetShape'] != null
          ? ShapeFactory.fromJson(json['targetShape'] as Map<String, dynamic>)
          : null,
    );
  }

  final String shapeId;
  final String shapeName;
  final List<PropertyConflictDto> propertyConflicts;
  final Shape? baseShape;
  final Shape? sourceShape;
  final Shape? targetShape;
}

/// Conflict resolution choice
enum ConflictResolutionChoice { source, target, custom }

/// Individual conflict resolution
class ConflictResolutionDto {
  ConflictResolutionDto({
    required this.shapeId,
    required this.choice,
    this.resolvedShape,
  });

  final String shapeId;
  final ConflictResolutionChoice choice;
  final Shape? resolvedShape;

  Map<String, dynamic> toJson() => {
        'shapeId': shapeId,
        'choice': choice.name.toUpperCase(),
        if (resolvedShape != null) 'resolvedShape': resolvedShape!.toJson(),
      };
}

/// Merge status check result
class MergeStatusDto {
  MergeStatusDto({
    required this.mergeable,
    required this.conflicts,
    required this.commitsAhead,
    required this.commitsBehind,
    this.reason,
  });

  factory MergeStatusDto.fromJson(Map<String, dynamic> json) {
    return MergeStatusDto(
      mergeable: json['mergeable'] as bool,
      conflicts: (json['conflicts'] as List<dynamic>?)
              ?.map((e) => ShapeConflictDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      commitsAhead: (json['commitsAhead'] as num?)?.toInt() ?? 0,
      commitsBehind: (json['commitsBehind'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
    );
  }

  final bool mergeable;
  final List<ShapeConflictDto> conflicts;
  final int commitsAhead;
  final int commitsBehind;
  final String? reason;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Branch comparison result
class BranchComparisonDto {
  BranchComparisonDto({
    required this.commitsAhead,
    required this.commitsBehind,
    required this.canFastForward,
    this.baseBranch,
    this.headBranch,
    this.baseBranchId,
    this.headBranchId,
    this.diff,
    this.conflicts = const [],
  });

  factory BranchComparisonDto.fromJson(Map<String, dynamic> json) {
    return BranchComparisonDto(
      baseBranch: json['baseBranch'] != null
          ? BranchDto.fromJson(json['baseBranch'] as Map<String, dynamic>)
          : null,
      headBranch: json['headBranch'] != null
          ? BranchDto.fromJson(json['headBranch'] as Map<String, dynamic>)
          : null,
      baseBranchId: json['baseBranchId'] as String?,
      headBranchId: json['headBranchId'] as String?,
      commitsAhead: (json['commitsAhead'] as num?)?.toInt() ?? 0,
      commitsBehind: (json['commitsBehind'] as num?)?.toInt() ?? 0,
      diff: json['diff'] != null
          ? DiffResultDto.fromJson(json['diff'] as Map<String, dynamic>)
          : null,
      conflicts: (json['conflicts'] as List<dynamic>?)
              ?.map((e) => ShapeConflictDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      canFastForward: json['canFastForward'] as bool? ?? false,
    );
  }

  /// Full branch objects (optional, used by REST API)
  final BranchDto? baseBranch;
  final BranchDto? headBranch;

  /// Branch IDs (optional, used by gRPC)
  final String? baseBranchId;
  final String? headBranchId;

  final int commitsAhead;
  final int commitsBehind;
  final DiffResultDto? diff;
  final List<ShapeConflictDto> conflicts;
  final bool canFastForward;

  bool get hasConflicts => conflicts.isNotEmpty;
}
