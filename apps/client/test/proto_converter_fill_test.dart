import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/core/grpc/proto_converter.dart';
import 'package:vio_core/vio_core.dart';

void main() {
  group('ProtoConverter - Fill conversions', () {
    test('round-trips a shape with solid fill through proto', () {
      const shape = RectangleShape(
        id: 'test-1',
        name: 'Solid Fill Rect',
        x: 0,
        y: 0,
        rectWidth: 100,
        rectHeight: 100,
        fills: [
          ShapeFill(color: 0xFF3B82F6, opacity: 0.8, hidden: true),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      expect(restored.fills.length, 1);
      expect(restored.fills[0].color, 0xFF3B82F6);
      expect(restored.fills[0].opacity, 0.8);
      expect(restored.fills[0].hidden, true);
      expect(restored.fills[0].gradient, isNull);
      expect(restored.fills[0].fillImage, isNull);
    });

    test('round-trips a shape with linear gradient fill through proto', () {
      const shape = RectangleShape(
        id: 'test-gradient',
        name: 'Gradient Rect',
        x: 0,
        y: 0,
        rectWidth: 200,
        rectHeight: 200,
        fills: [
          ShapeFill(
            color: 0xFF000000,
            gradient: ShapeGradient(
              type: GradientType.linear,
              stops: [
                GradientStop(color: 0xFFFF0000, offset: 0.0),
                GradientStop(color: 0xFF0000FF, offset: 1.0, opacity: 0.5),
              ],
            ),
          ),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      expect(restored.fills.length, 1);
      final fill = restored.fills[0];
      expect(fill.gradient, isNotNull);
      expect(fill.gradient!.type, GradientType.linear);
      expect(fill.gradient!.stops.length, 2);
      expect(fill.gradient!.stops[0].color, 0xFFFF0000);
      expect(fill.gradient!.stops[0].offset, 0.0);
      expect(fill.gradient!.stops[0].opacity, 1.0);
      expect(fill.gradient!.stops[1].color, 0xFF0000FF);
      expect(fill.gradient!.stops[1].offset, 1.0);
      expect(fill.gradient!.stops[1].opacity, 0.5);
      expect(fill.gradient!.startX, 0.0);
      expect(fill.gradient!.startY, 0.0);
      expect(fill.gradient!.endX, 1.0);
      expect(fill.gradient!.endY, 1.0);
    });

    test('round-trips a shape with radial gradient fill through proto', () {
      const shape = EllipseShape(
        id: 'test-radial',
        name: 'Radial Gradient',
        x: 50,
        y: 50,
        ellipseWidth: 100,
        ellipseHeight: 100,
        fills: [
          ShapeFill(
            color: 0xFF000000,
            gradient: ShapeGradient(
              type: GradientType.radial,
              stops: [
                GradientStop(color: 0xFFFFFFFF, offset: 0.0),
                GradientStop(color: 0xFF000000, offset: 0.5),
                GradientStop(color: 0xFFFF00FF, offset: 1.0),
              ],
              startX: 0.5,
              startY: 0.5,
              endY: 0.5,
            ),
          ),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      final fill = restored.fills[0];
      expect(fill.gradient!.type, GradientType.radial);
      expect(fill.gradient!.stops.length, 3);
      expect(fill.gradient!.startX, 0.5);
      expect(fill.gradient!.startY, 0.5);
    });

    test('round-trips a shape with fillImage through proto', () {
      const shape = RectangleShape(
        id: 'test-fill-image',
        name: 'Image Fill Rect',
        x: 0,
        y: 0,
        rectWidth: 300,
        rectHeight: 200,
        fills: [
          ShapeFill(
            color: 0xFFFFFFFF,
            fillImage: ShapeFillImage(
              id: 'img-asset-123',
              width: 1920,
              height: 1080,
              mtype: 'image/png',
            ),
          ),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      final fill = restored.fills[0];
      expect(fill.fillImage, isNotNull);
      expect(fill.fillImage!.id, 'img-asset-123');
      expect(fill.fillImage!.width, 1920);
      expect(fill.fillImage!.height, 1080);
      expect(fill.fillImage!.mtype, 'image/png');
    });

    test('round-trips a shape with fillImage without optional fields', () {
      const shape = RectangleShape(
        id: 'test-fill-image-minimal',
        name: 'Minimal Image Fill',
        x: 0,
        y: 0,
        rectWidth: 100,
        rectHeight: 100,
        fills: [
          ShapeFill(
            color: 0xFF000000,
            fillImage: ShapeFillImage(id: 'img-minimal'),
          ),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      final fill = restored.fills[0];
      expect(fill.fillImage, isNotNull);
      expect(fill.fillImage!.id, 'img-minimal');
      expect(fill.fillImage!.width, isNull);
      expect(fill.fillImage!.height, isNull);
      expect(fill.fillImage!.mtype, isNull);
    });

    test('round-trips a shape with both gradient and fillImage', () {
      const shape = RectangleShape(
        id: 'test-both',
        name: 'Both Fills',
        x: 0,
        y: 0,
        rectWidth: 100,
        rectHeight: 100,
        fills: [
          ShapeFill(
            color: 0xFF000000,
            gradient: ShapeGradient(
              type: GradientType.linear,
              stops: [
                GradientStop(color: 0xFFFF0000, offset: 0.0),
                GradientStop(color: 0xFF00FF00, offset: 1.0),
              ],
            ),
            fillImage: ShapeFillImage(
              id: 'img-overlay',
              width: 512,
              height: 512,
              mtype: 'image/jpeg',
            ),
          ),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      final fill = restored.fills[0];
      expect(fill.gradient, isNotNull);
      expect(fill.gradient!.stops.length, 2);
      expect(fill.fillImage, isNotNull);
      expect(fill.fillImage!.id, 'img-overlay');
    });

    test('round-trips multiple fills with mixed types', () {
      const shape = RectangleShape(
        id: 'test-multi',
        name: 'Multi Fill',
        x: 0,
        y: 0,
        rectWidth: 100,
        rectHeight: 100,
        fills: [
          // Solid fill
          ShapeFill(color: 0xFFFF0000),
          // Gradient fill (hidden)
          ShapeFill(
            color: 0xFF000000,
            opacity: 0.5,
            hidden: true,
            gradient: ShapeGradient(
              type: GradientType.linear,
              stops: [
                GradientStop(color: 0xFF000000, offset: 0.0),
                GradientStop(color: 0xFFFFFFFF, offset: 1.0),
              ],
            ),
          ),
          // Image fill
          ShapeFill(
            color: 0xFFFFFFFF,
            opacity: 0.75,
            fillImage: ShapeFillImage(id: 'texture-1'),
          ),
        ],
      );

      final proto = ProtoConverter.shapeToProto(shape);
      final restored = ProtoConverter.shapeFromProto(proto);

      expect(restored.fills.length, 3);

      // First: solid
      expect(restored.fills[0].color, 0xFFFF0000);
      expect(restored.fills[0].gradient, isNull);
      expect(restored.fills[0].fillImage, isNull);

      // Second: gradient, hidden
      expect(restored.fills[1].hidden, true);
      expect(restored.fills[1].opacity, 0.5);
      expect(restored.fills[1].gradient, isNotNull);

      // Third: image fill
      expect(restored.fills[2].opacity, 0.75);
      expect(restored.fills[2].fillImage, isNotNull);
      expect(restored.fills[2].fillImage!.id, 'texture-1');
    });
  });
}
