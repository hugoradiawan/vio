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
      if (fill.gradient != null) 'gradient': _gradientToJson(fill.gradient!),
    };
  }

  Map<String, dynamic> _strokeToJson(ShapeStroke stroke) {
    return {
      'color': stroke.color,
      'width': stroke.width,
      'opacity': stroke.opacity,
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
    final transform = Matrix2D(
      a: (json['transformA'] as num?)?.toDouble() ?? 1.0,
      b: (json['transformB'] as num?)?.toDouble() ?? 0.0,
      c: (json['transformC'] as num?)?.toDouble() ?? 0.0,
      d: (json['transformD'] as num?)?.toDouble() ?? 1.0,
      e: (json['transformE'] as num?)?.toDouble() ?? 0.0,
      f: (json['transformF'] as num?)?.toDouble() ?? 0.0,
    );
    final fills = _parseFills(json['fills']);
    final strokes = _parseStrokes(json['strokes']);
    final properties = json['properties'] as Map<String, dynamic>? ?? {};

    // frameId can come from json directly or from properties (for shapes nested in frames)
    final frameId =
        json['frameId'] as String? ?? properties['frameId'] as String?;

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
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
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
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
        );

      case ShapeType.frame:
        return FrameShape(
          id: json['id'] as String,
          name: json['name'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          frameWidth: (json['width'] as num).toDouble(),
          frameHeight: (json['height'] as num).toDouble(),
          parentId: json['parentId'] as String?,
          frameId: frameId,
          transform: transform,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          fills: fills,
          strokes: strokes,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
          hidden: json['hidden'] as bool? ?? false,
          blocked: json['blocked'] as bool? ?? false,
          clipContent: properties['clipContent'] as bool? ?? true,
        );

      case ShapeType.path:
      case ShapeType.text:
      case ShapeType.group:
      case ShapeType.image:
      case ShapeType.svg:
      case ShapeType.bool:
        // TODO: Implement other shape types as needed
        throw UnimplementedError('Shape type $type not yet implemented');
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
      final fill = f as Map<String, dynamic>;
      return ShapeFill(
        color: fill['color'] as int,
        opacity: (fill['opacity'] as num?)?.toDouble() ?? 1.0,
        gradient: fill['gradient'] != null
            ? _parseGradient(fill['gradient'] as Map<String, dynamic>)
            : null,
      );
    }).toList();
  }

  static List<ShapeStroke> _parseStrokes(dynamic strokesJson) {
    if (strokesJson == null) return [];
    if (strokesJson is! List) return [];

    return strokesJson.map<ShapeStroke>((s) {
      final stroke = s as Map<String, dynamic>;
      return ShapeStroke(
        color: stroke['color'] as int,
        width: (stroke['width'] as num?)?.toDouble() ?? 1.0,
        opacity: (stroke['opacity'] as num?)?.toDouble() ?? 1.0,
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
        final stop = s as Map<String, dynamic>;
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
