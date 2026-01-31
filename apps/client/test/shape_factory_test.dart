import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/core/api/dto.dart';
import 'package:vio_core/vio_core.dart';

void main() {
  group('ShapeFactory', () {
    test('parses rectangle with flat transform format (from DB)', () {
      final json = {
        'id': 'test-rect-1',
        'type': 'rectangle',
        'name': 'Rectangle 1',
        'x': 100.0,
        'y': 100.0,
        'width': 200.0,
        'height': 150.0,
        'transformA': 1.0,
        'transformB': 0.0,
        'transformC': 0.0,
        'transformD': 1.0,
        'transformE': 50.0,
        'transformF': 50.0,
        'fills': [{'color': 0xFF3B82F6, 'opacity': 1.0}],
        'strokes': <dynamic>[],
        'opacity': 1.0,
        'hidden': false,
        'blocked': false,
        'rotation': 0.0,
        'sortOrder': 0,
        'properties': {'r1': 8.0, 'r2': 8.0, 'r3': 8.0, 'r4': 8.0},
      };

      final shape = ShapeFactory.fromJson(json);

      expect(shape, isA<RectangleShape>());
      expect(shape.id, 'test-rect-1');
      expect(shape.name, 'Rectangle 1');
      expect(shape.x, 100.0);
      expect(shape.y, 100.0);
      expect(shape.transform.a, 1.0);
      expect(shape.transform.e, 50.0);
      expect(shape.transform.f, 50.0);

      final rect = shape as RectangleShape;
      expect(rect.rectWidth, 200.0);
      expect(rect.rectHeight, 150.0);
      expect(rect.r1, 8.0);
    });

    test('parses rectangle with nested transform format (from seed data)', () {
      final json = {
        'id': 'test-rect-2',
        'type': 'rectangle',
        'name': 'Rectangle 2',
        'x': 100.0,
        'y': 100.0,
        'width': 200.0,
        'height': 150.0,
        'transform': {
          'a': 1.0,
          'b': 0.0,
          'c': 0.0,
          'd': 1.0,
          'e': 25.0,
          'f': 25.0,
        },
        'fills': <dynamic>[],
        'strokes': <dynamic>[],
        'opacity': 1.0,
        'hidden': false,
        'blocked': false,
        'rotation': 0.0,
        'sortOrder': 0,
        'properties': <String, dynamic>{},
      };

      final shape = ShapeFactory.fromJson(json);

      expect(shape, isA<RectangleShape>());
      expect(shape.transform.a, 1.0);
      expect(shape.transform.e, 25.0);
      expect(shape.transform.f, 25.0);
    });

    test('parses frame with frameWidth/frameHeight format', () {
      final json = {
        'id': 'test-frame-1',
        'type': 'frame',
        'name': 'Frame 1',
        'x': 0.0,
        'y': 0.0,
        'frameWidth': 800.0,
        'frameHeight': 600.0,
        'transform': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 0, 'f': 0},
        'fills': <dynamic>[],
        'strokes': <dynamic>[],
        'opacity': 1.0,
        'hidden': false,
        'blocked': false,
        'rotation': 0.0,
        'sortOrder': 0,
        'properties': <String, dynamic>{},
      };

      final shape = ShapeFactory.fromJson(json);

      expect(shape, isA<FrameShape>());
      final frame = shape as FrameShape;
      expect(frame.frameWidth, 800.0);
      expect(frame.frameHeight, 600.0);
    });

    test('parses frame with width/height format (from DB)', () {
      final json = {
        'id': 'test-frame-2',
        'type': 'frame',
        'name': 'Frame 2',
        'x': 0.0,
        'y': 0.0,
        'width': 1024.0,
        'height': 768.0,
        'transformA': 1,
        'transformB': 0,
        'transformC': 0,
        'transformD': 1,
        'transformE': 0,
        'transformF': 0,
        'fills': <dynamic>[],
        'strokes': <dynamic>[],
        'opacity': 1.0,
        'hidden': false,
        'blocked': false,
        'rotation': 0.0,
        'sortOrder': 0,
        'properties': <String, dynamic>{},
      };

      final shape = ShapeFactory.fromJson(json);

      expect(shape, isA<FrameShape>());
      final frame = shape as FrameShape;
      expect(frame.frameWidth, 1024.0);
      expect(frame.frameHeight, 768.0);
    });

    test('parses ellipse correctly', () {
      final json = {
        'id': 'test-ellipse-1',
        'type': 'ellipse',
        'name': 'Circle 1',
        'x': 400.0,
        'y': 300.0,
        'width': 100.0,
        'height': 100.0,
        'transformA': 1,
        'transformB': 0,
        'transformC': 0,
        'transformD': 1,
        'transformE': 0,
        'transformF': 0,
        'fills': [{'color': 0xFFFF0000, 'opacity': 1.0}],
        'strokes': <dynamic>[],
        'opacity': 1.0,
        'hidden': false,
        'blocked': false,
        'rotation': 0.0,
        'sortOrder': 1,
        'properties': <String, dynamic>{},
      };

      final shape = ShapeFactory.fromJson(json);

      expect(shape, isA<EllipseShape>());
      final ellipse = shape as EllipseShape;
      expect(ellipse.x, 400.0);
      expect(ellipse.y, 300.0);
      expect(ellipse.ellipseWidth, 100.0);
      expect(ellipse.ellipseHeight, 100.0);
    });
  });
}
