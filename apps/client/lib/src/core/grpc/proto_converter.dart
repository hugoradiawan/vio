import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show TextAlign;

import 'package:vio_core/vio_core.dart';

import '../../gen/vio/v1/canvas.pb.dart' as pb_canvas;
import '../../gen/vio/v1/common.pb.dart' as pb_common;
import '../../gen/vio/v1/shape.pb.dart' as pb_shape;

/// Converts between protobuf types and domain model types
class ProtoConverter {
  ProtoConverter._();

  // ============================================================================
  // Shape Conversions
  // ============================================================================

  /// Convert proto Shape to domain Shape
  static Shape shapeFromProto(pb_shape.Shape proto) {
    final shapeType = _shapeTypeFromProto(proto.type);

    // Parse base properties
    final fills = proto.fills.map(_fillFromProto).toList();
    final strokes = proto.strokes.map(_strokeFromProto).toList();
    final transform = proto.hasTransform()
        ? _transformFromProto(proto.transform)
        : Matrix2D.identity;

    // Parse type-specific properties from bytes
    final props = _parseProperties(Uint8List.fromList(proto.properties));
    final shadow = _parseShadow(props);
    final blur = _parseBlur(props);

    switch (shapeType) {
      case ShapeType.rectangle:
        return RectangleShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          rectWidth: proto.width,
          rectHeight: proto.height,
          rotation: proto.rotation,
          transform: transform,
          fills: fills,
          strokes: strokes,
          opacity: proto.opacity,
          hidden: proto.hidden,
          blocked: proto.blocked,
          sortOrder: proto.sortOrder,
          frameId: proto.hasFrameId() ? proto.frameId : null,
          parentId: proto.hasParentId() ? proto.parentId : null,
          shadow: shadow,
          blur: blur,
          r1: (props['r1'] as num?)?.toDouble() ?? 0,
          r2: (props['r2'] as num?)?.toDouble() ?? 0,
          r3: (props['r3'] as num?)?.toDouble() ?? 0,
          r4: (props['r4'] as num?)?.toDouble() ?? 0,
        );
      case ShapeType.ellipse:
        return EllipseShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          ellipseWidth: proto.width,
          ellipseHeight: proto.height,
          rotation: proto.rotation,
          transform: transform,
          fills: fills,
          strokes: strokes,
          opacity: proto.opacity,
          hidden: proto.hidden,
          blocked: proto.blocked,
          sortOrder: proto.sortOrder,
          frameId: proto.hasFrameId() ? proto.frameId : null,
          parentId: proto.hasParentId() ? proto.parentId : null,
          shadow: shadow,
          blur: blur,
        );
      case ShapeType.frame:
        return FrameShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          frameWidth: proto.width,
          frameHeight: proto.height,
          rotation: proto.rotation,
          transform: transform,
          fills: fills,
          strokes: strokes,
          opacity: proto.opacity,
          hidden: proto.hidden,
          blocked: proto.blocked,
          sortOrder: proto.sortOrder,
          frameId: proto.hasFrameId() ? proto.frameId : null,
          parentId: proto.hasParentId() ? proto.parentId : null,
          shadow: shadow,
          blur: blur,
        );
      case ShapeType.text:
        return TextShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          textWidth: proto.width,
          textHeight: proto.height,
          text: (props['text'] as String?) ?? '',
          fontSize: (props['fontSize'] as num?)?.toDouble() ?? 16.0,
          fontFamily: props['fontFamily'] as String?,
          fontWeight: props['fontWeight'] as int?,
          lineHeight: (props['lineHeight'] as num?)?.toDouble(),
          letterSpacingPercent:
              (props['letterSpacingPercent'] as num?)?.toDouble() ?? 0,
          textAlign: _parseTextAlign(props['textAlign'] as String?),
          rotation: proto.rotation,
          transform: transform,
          fills: fills,
          strokes: strokes,
          opacity: proto.opacity,
          hidden: proto.hidden,
          blocked: proto.blocked,
          sortOrder: proto.sortOrder,
          frameId: proto.hasFrameId() ? proto.frameId : null,
          parentId: proto.hasParentId() ? proto.parentId : null,
          shadow: shadow,
          blur: blur,
        );
      case ShapeType.group:
        return GroupShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          groupWidth: proto.width,
          groupHeight: proto.height,
          rotation: proto.rotation,
          transform: transform,
          fills: fills,
          strokes: strokes,
          opacity: proto.opacity,
          hidden: proto.hidden,
          blocked: proto.blocked,
          sortOrder: proto.sortOrder,
          frameId: proto.hasFrameId() ? proto.frameId : null,
          parentId: proto.hasParentId() ? proto.parentId : null,
          shadow: shadow,
          blur: blur,
        );
      default:
        // Fallback to rectangle for unsupported types
        return RectangleShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          rectWidth: proto.width,
          rectHeight: proto.height,
          rotation: proto.rotation,
          transform: transform,
          fills: fills,
          strokes: strokes,
          opacity: proto.opacity,
          hidden: proto.hidden,
          blocked: proto.blocked,
          sortOrder: proto.sortOrder,
          frameId: proto.hasFrameId() ? proto.frameId : null,
          parentId: proto.hasParentId() ? proto.parentId : null,
          shadow: shadow,
          blur: blur,
        );
    }
  }

  /// Parse TextAlign from string
  static TextAlign _parseTextAlign(String? value) {
    if (value == null) return TextAlign.left;
    return switch (value) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      'center' => TextAlign.center,
      'justify' => TextAlign.justify,
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.left,
    };
  }

  /// Convert domain Shape to proto Shape
  static pb_shape.Shape shapeToProto(Shape shape, {String? projectId}) {
    final proto = pb_shape.Shape()
      ..id = shape.id
      ..name = shape.name
      ..type = _shapeTypeToProto(shape.type)
      ..x = shape.x
      ..y = shape.y
      ..width = shape.width
      ..height = shape.height
      ..rotation = shape.rotation
      ..transform = _transformToProto(shape.transform)
      ..opacity = shape.opacity
      ..hidden = shape.hidden
      ..blocked = shape.blocked
      ..sortOrder = shape.sortOrder;

    if (projectId != null) {
      proto.projectId = projectId;
    }

    if (shape.frameId != null) {
      proto.frameId = shape.frameId!;
    }

    if (shape.parentId != null) {
      proto.parentId = shape.parentId!;
    }

    proto.fills.addAll(shape.fills.map(_fillToProto));
    proto.strokes.addAll(shape.strokes.map(_strokeToProto));

    // Serialize type-specific properties including shadow/blur
    proto.properties = _serializeProperties(shape);

    return proto;
  }

  /// Serialize shape-specific properties to JSON bytes
  static Uint8List _serializeProperties(Shape shape) {
    final props = <String, dynamic>{};

    // Shadow
    if (shape.shadow != null) {
      props['shadow'] = shape.shadow!.toJson();
    }

    // Blur
    if (shape.blur != null) {
      props['blur'] = shape.blur!.toJson();
    }

    // Type-specific properties
    if (shape is RectangleShape) {
      props['r1'] = shape.r1;
      props['r2'] = shape.r2;
      props['r3'] = shape.r3;
      props['r4'] = shape.r4;
    } else if (shape is TextShape) {
      props['text'] = shape.text;
      props['fontSize'] = shape.fontSize;
      if (shape.fontFamily != null) props['fontFamily'] = shape.fontFamily;
      if (shape.fontWeight != null) props['fontWeight'] = shape.fontWeight;
      if (shape.lineHeight != null) props['lineHeight'] = shape.lineHeight;
      props['letterSpacingPercent'] = shape.letterSpacingPercent;
      props['textAlign'] = shape.textAlign.name;
    }

    if (props.isEmpty) {
      return Uint8List(0);
    }

    return Uint8List.fromList(utf8.encode(jsonEncode(props)));
  }

  /// Parse shape-specific properties from JSON bytes
  static Map<String, dynamic> _parseProperties(Uint8List bytes) {
    if (bytes.isEmpty) {
      return {};
    }
    try {
      final jsonStr = utf8.decode(bytes);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Parse shadow from properties map
  static ShapeShadow? _parseShadow(Map<String, dynamic> props) {
    final shadowJson = props['shadow'];
    if (shadowJson == null) return null;
    try {
      return ShapeShadow.fromJson(shadowJson as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Parse blur from properties map
  static ShapeBlur? _parseBlur(Map<String, dynamic> props) {
    final blurJson = props['blur'];
    if (blurJson == null) return null;
    try {
      return ShapeBlur.fromJson(blurJson as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // Transform Conversions
  // ============================================================================

  static Matrix2D _transformFromProto(pb_common.Transform proto) {
    return Matrix2D(
      a: proto.a,
      b: proto.b,
      c: proto.c,
      d: proto.d,
      e: proto.e,
      f: proto.f,
    );
  }

  static pb_common.Transform _transformToProto(Matrix2D transform) {
    return pb_common.Transform()
      ..a = transform.a
      ..b = transform.b
      ..c = transform.c
      ..d = transform.d
      ..e = transform.e
      ..f = transform.f;
  }

  // ============================================================================
  // Fill Conversions
  // ============================================================================

  static ShapeFill _fillFromProto(pb_common.Fill proto) {
    return ShapeFill(
      color: proto.color,
      opacity: proto.opacity,
      hidden: proto.hidden,
      gradient: proto.hasGradient()
          ? _gradientFromProto(proto.gradient)
          : null,
      fillImage: proto.hasFillImage()
          ? _fillImageFromProto(proto.fillImage)
          : null,
    );
  }

  static pb_common.Fill _fillToProto(ShapeFill fill) {
    final proto = pb_common.Fill()
      ..color = fill.color
      ..opacity = fill.opacity
      ..hidden = fill.hidden;
    if (fill.gradient != null) {
      proto.gradient = _gradientToProto(fill.gradient!);
    }
    if (fill.fillImage != null) {
      proto.fillImage = _fillImageToProto(fill.fillImage!);
    }
    return proto;
  }

  // ============================================================================
  // Gradient Conversions
  // ============================================================================

  static ShapeGradient _gradientFromProto(pb_common.Gradient proto) {
    return ShapeGradient(
      type: _gradientTypeFromProto(proto.type),
      stops: proto.stops.map(_gradientStopFromProto).toList(),
      startX: proto.startX,
      startY: proto.startY,
      endX: proto.endX,
      endY: proto.endY,
    );
  }

  static pb_common.Gradient _gradientToProto(ShapeGradient gradient) {
    return pb_common.Gradient()
      ..type = _gradientTypeToProto(gradient.type)
      ..stops.addAll(gradient.stops.map(_gradientStopToProto))
      ..startX = gradient.startX
      ..startY = gradient.startY
      ..endX = gradient.endX
      ..endY = gradient.endY;
  }

  static GradientStop _gradientStopFromProto(pb_common.GradientStop proto) {
    return GradientStop(
      color: proto.color,
      offset: proto.offset,
      opacity: proto.opacity,
    );
  }

  static pb_common.GradientStop _gradientStopToProto(GradientStop stop) {
    return pb_common.GradientStop()
      ..color = stop.color
      ..offset = stop.offset
      ..opacity = stop.opacity;
  }

  static GradientType _gradientTypeFromProto(pb_common.Gradient_Type proto) {
    return switch (proto) {
      pb_common.Gradient_Type.TYPE_LINEAR => GradientType.linear,
      pb_common.Gradient_Type.TYPE_RADIAL => GradientType.radial,
      _ => GradientType.linear,
    };
  }

  static pb_common.Gradient_Type _gradientTypeToProto(GradientType type) {
    return switch (type) {
      GradientType.linear => pb_common.Gradient_Type.TYPE_LINEAR,
      GradientType.radial => pb_common.Gradient_Type.TYPE_RADIAL,
    };
  }

  // ============================================================================
  // FillImage Conversions
  // ============================================================================

  static ShapeFillImage _fillImageFromProto(pb_common.FillImage proto) {
    return ShapeFillImage(
      id: proto.id,
      width: proto.hasWidth() ? proto.width : null,
      height: proto.hasHeight() ? proto.height : null,
      mtype: proto.hasMtype() ? proto.mtype : null,
    );
  }

  static pb_common.FillImage _fillImageToProto(ShapeFillImage fillImage) {
    final proto = pb_common.FillImage()..id = fillImage.id;
    if (fillImage.width != null) proto.width = fillImage.width!;
    if (fillImage.height != null) proto.height = fillImage.height!;
    if (fillImage.mtype != null) proto.mtype = fillImage.mtype!;
    return proto;
  }

  // ============================================================================
  // Stroke Conversions
  // ============================================================================

  static ShapeStroke _strokeFromProto(pb_common.Stroke proto) {
    return ShapeStroke(
      color: proto.color,
      width: proto.width,
      opacity: proto.opacity,
      alignment: _strokeAlignmentFromProto(proto.alignment),
      cap: _strokeCapFromProto(proto.cap),
      join: _strokeJoinFromProto(proto.join),
    );
  }

  static pb_common.Stroke _strokeToProto(ShapeStroke stroke) {
    return pb_common.Stroke()
      ..color = stroke.color
      ..width = stroke.width
      ..opacity = stroke.opacity
      ..alignment = _strokeAlignmentToProto(stroke.alignment)
      ..cap = _strokeCapToProto(stroke.cap)
      ..join = _strokeJoinToProto(stroke.join);
  }

  // ============================================================================
  // Enum Conversions
  // ============================================================================

  static ShapeType _shapeTypeFromProto(pb_shape.ShapeType proto) {
    return switch (proto) {
      pb_shape.ShapeType.SHAPE_TYPE_RECTANGLE => ShapeType.rectangle,
      pb_shape.ShapeType.SHAPE_TYPE_ELLIPSE => ShapeType.ellipse,
      pb_shape.ShapeType.SHAPE_TYPE_FRAME => ShapeType.frame,
      pb_shape.ShapeType.SHAPE_TYPE_TEXT => ShapeType.text,
      pb_shape.ShapeType.SHAPE_TYPE_GROUP => ShapeType.group,
      pb_shape.ShapeType.SHAPE_TYPE_PATH => ShapeType.path,
      pb_shape.ShapeType.SHAPE_TYPE_IMAGE => ShapeType.image,
      pb_shape.ShapeType.SHAPE_TYPE_SVG => ShapeType.svg,
      pb_shape.ShapeType.SHAPE_TYPE_BOOL => ShapeType.bool,
      _ => ShapeType.rectangle,
    };
  }

  static pb_shape.ShapeType _shapeTypeToProto(ShapeType type) {
    return switch (type) {
      ShapeType.rectangle => pb_shape.ShapeType.SHAPE_TYPE_RECTANGLE,
      ShapeType.ellipse => pb_shape.ShapeType.SHAPE_TYPE_ELLIPSE,
      ShapeType.frame => pb_shape.ShapeType.SHAPE_TYPE_FRAME,
      ShapeType.text => pb_shape.ShapeType.SHAPE_TYPE_TEXT,
      ShapeType.group => pb_shape.ShapeType.SHAPE_TYPE_GROUP,
      ShapeType.path => pb_shape.ShapeType.SHAPE_TYPE_PATH,
      ShapeType.image => pb_shape.ShapeType.SHAPE_TYPE_IMAGE,
      ShapeType.svg => pb_shape.ShapeType.SHAPE_TYPE_SVG,
      ShapeType.bool => pb_shape.ShapeType.SHAPE_TYPE_BOOL,
    };
  }

  static StrokeAlignment _strokeAlignmentFromProto(
    pb_common.StrokeAlignment proto,
  ) {
    return switch (proto) {
      pb_common.StrokeAlignment.STROKE_ALIGNMENT_INSIDE =>
        StrokeAlignment.inside,
      pb_common.StrokeAlignment.STROKE_ALIGNMENT_CENTER =>
        StrokeAlignment.center,
      pb_common.StrokeAlignment.STROKE_ALIGNMENT_OUTSIDE =>
        StrokeAlignment.outside,
      _ => StrokeAlignment.center,
    };
  }

  static pb_common.StrokeAlignment _strokeAlignmentToProto(
    StrokeAlignment alignment,
  ) {
    return switch (alignment) {
      StrokeAlignment.inside =>
        pb_common.StrokeAlignment.STROKE_ALIGNMENT_INSIDE,
      StrokeAlignment.center =>
        pb_common.StrokeAlignment.STROKE_ALIGNMENT_CENTER,
      StrokeAlignment.outside =>
        pb_common.StrokeAlignment.STROKE_ALIGNMENT_OUTSIDE,
    };
  }

  static StrokeCap _strokeCapFromProto(pb_common.StrokeCap proto) {
    return switch (proto) {
      pb_common.StrokeCap.STROKE_CAP_BUTT => StrokeCap.butt,
      pb_common.StrokeCap.STROKE_CAP_ROUND => StrokeCap.round,
      pb_common.StrokeCap.STROKE_CAP_SQUARE => StrokeCap.square,
      _ => StrokeCap.round,
    };
  }

  static pb_common.StrokeCap _strokeCapToProto(StrokeCap cap) {
    return switch (cap) {
      StrokeCap.butt => pb_common.StrokeCap.STROKE_CAP_BUTT,
      StrokeCap.round => pb_common.StrokeCap.STROKE_CAP_ROUND,
      StrokeCap.square => pb_common.StrokeCap.STROKE_CAP_SQUARE,
    };
  }

  static StrokeJoin _strokeJoinFromProto(pb_common.StrokeJoin proto) {
    return switch (proto) {
      pb_common.StrokeJoin.STROKE_JOIN_MITER => StrokeJoin.miter,
      pb_common.StrokeJoin.STROKE_JOIN_ROUND => StrokeJoin.round,
      pb_common.StrokeJoin.STROKE_JOIN_BEVEL => StrokeJoin.bevel,
      _ => StrokeJoin.round,
    };
  }

  static pb_common.StrokeJoin _strokeJoinToProto(StrokeJoin join) {
    return switch (join) {
      StrokeJoin.miter => pb_common.StrokeJoin.STROKE_JOIN_MITER,
      StrokeJoin.round => pb_common.StrokeJoin.STROKE_JOIN_ROUND,
      StrokeJoin.bevel => pb_common.StrokeJoin.STROKE_JOIN_BEVEL,
    };
  }

  // ============================================================================
  // SyncOperation Conversions
  // ============================================================================

  static pb_canvas.SyncOperation syncOperationToProto(
    SyncOperationType type,
    String shapeId,
    Shape? shape,
    DateTime timestamp,
    String? projectId,
  ) {
    final proto = pb_canvas.SyncOperation()
      ..type = _operationTypeToProto(type)
      ..shapeId = shapeId
      ..timestamp = timestamp.toIso8601String();

    if (shape != null) {
      proto.shape = shapeToProto(shape, projectId: projectId);
    }

    return proto;
  }

  static pb_canvas.OperationType _operationTypeToProto(SyncOperationType type) {
    return switch (type) {
      SyncOperationType.create => pb_canvas.OperationType.OPERATION_TYPE_CREATE,
      SyncOperationType.update => pb_canvas.OperationType.OPERATION_TYPE_UPDATE,
      SyncOperationType.delete => pb_canvas.OperationType.OPERATION_TYPE_DELETE,
    };
  }
}

/// Sync operation types (mirrors the local DTO)
enum SyncOperationType {
  create,
  update,
  delete,
}
