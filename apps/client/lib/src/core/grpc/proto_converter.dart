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
          // TODO: Parse r1-r4 from properties bytes
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
        );
      case ShapeType.text:
        return TextShape(
          id: proto.id,
          name: proto.name,
          x: proto.x,
          y: proto.y,
          textWidth: proto.width,
          textHeight: proto.height,
          text: '', // TODO: Parse from properties
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
        );
    }
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

    return proto;
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
      // TODO: Handle gradient and fillImage
    );
  }

  static pb_common.Fill _fillToProto(ShapeFill fill) {
    return pb_common.Fill()
      ..color = fill.color
      ..opacity = fill.opacity;
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
