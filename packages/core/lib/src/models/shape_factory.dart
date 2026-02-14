import 'package:flutter/rendering.dart';

import '../../vio_core.dart';

/// Factory for creating Shape from JSON API response or snapshot data.
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
          originalWidth: (properties['originalWidth'] as num?)?.toDouble() ?? 0,
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
