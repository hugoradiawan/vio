import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_client/src/core/repositories/grpc_canvas_repository.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/gen/vio/v1/canvas.pbgrpc.dart';
import 'package:vio_core/vio_core.dart';

class _TestCanvasRepository extends GrpcCanvasRepository {
  _TestCanvasRepository()
      : super(
          canvasClient: CanvasServiceClient(
            ClientChannel(
              'localhost',
              port: 0,
              options: const ChannelOptions(
                credentials: ChannelCredentials.insecure(),
              ),
            ),
          ),
        );

  @override
  void addShape(Shape shape) {}

  @override
  void updateShape(Shape shape) {}
}

void main() {
  group('Selection rotation', () {
    test('selectionRotation returns correct angle for rotated shape', () async {
      final repo = _TestCanvasRepository();
      final bloc = CanvasBloc(repository: repo);

      // Create a rectangle with a 45-degree rotation
      const angle = 45.0 * math.pi / 180.0;
      final rotatedTransform = Matrix2D.rotationAt(angle, 200, 175);

      final shape = RectangleShape(
        id: 'rect-1',
        name: 'Rect',
        x: 100,
        y: 100,
        rectWidth: 200,
        rectHeight: 150,
        transform: rotatedTransform,
      );

      bloc.add(ShapeAdded(shape));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ShapeSelected('rect-1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify the shape is in state with correct transform
      final storedShape = bloc.state.shapes['rect-1']!;
      expect(storedShape.transform.a, closeTo(math.cos(angle), 0.001));
      expect(storedShape.transform.b, closeTo(math.sin(angle), 0.001));

      // Verify selectionRotation returns ~45 degrees
      final selectionRot = bloc.state.selectionRotation;
      expect(selectionRot, closeTo(45.0, 0.1));

      // Verify unrotatedSelectionRect is non-null (OBB mode)
      final unrotatedRect = bloc.state.unrotatedSelectionRect;
      expect(unrotatedRect, isNotNull);

      await bloc.close();
    });

    test('selectionRotation returns 0 for non-rotated shape', () async {
      final repo = _TestCanvasRepository();
      final bloc = CanvasBloc(repository: repo);

      const shape = RectangleShape(
        id: 'rect-2',
        name: 'Rect',
        x: 100,
        y: 100,
        rectWidth: 200,
        rectHeight: 150,
      );

      bloc.add(const ShapeAdded(shape));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ShapeSelected('rect-2'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final selectionRot = bloc.state.selectionRotation;
      expect(selectionRot, closeTo(0.0, 0.01));
      expect(bloc.state.unrotatedSelectionRect, isNull);

      await bloc.close();
    });

    test('full rotation flow via PointerDown/Move/Up', () async {
      final repo = _TestCanvasRepository();
      final bloc = CanvasBloc(repository: repo);

      // 1. Add a rectangle at (100, 100) with size 200x150
      const shape = RectangleShape(
        id: 'rect-flow',
        name: 'Rect',
        x: 100,
        y: 100,
        rectWidth: 200,
        rectHeight: 150,
      );

      bloc.add(const ShapeAdded(shape));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 2. Select it
      bloc.add(const ShapeSelected('rect-flow'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify the shape starts with identity transform
      expect(bloc.state.shapes['rect-flow']!.transform.a, 1.0);
      expect(bloc.state.shapes['rect-flow']!.transform.b, 0.0);
      expect(bloc.state.selectionRotation, closeTo(0.0, 0.01));

      final selRect = bloc.state.selectionRect!;
      expect(selRect.left, closeTo(100.0, 0.1));
      expect(selRect.top, closeTo(100.0, 0.1));
      expect(selRect.width, closeTo(200.0, 0.1));
      expect(selRect.height, closeTo(150.0, 0.1));

      // Rotation handle at (centerX, top - rotationOffset) = (200, 80)
      bloc.add(const PointerDown(x: 200, y: 80));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      if (bloc.state.interactionMode != InteractionMode.rotating) {
        bloc.add(const PointerUp(x: 200, y: 80));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        bloc.add(const PointerDown(x: 200, y: 70));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      if (bloc.state.interactionMode == InteractionMode.rotating) {
        // Rotate ~45 degrees clockwise
        // Center (200,175), start point (200,80) → angle = -90°
        // Target angle = -90° + 45° = -45°, distance = 95
        // new x = 200 + 95 * cos(-45°) ≈ 267.18
        // new y = 175 + 95 * sin(-45°) ≈ 107.82
        bloc.add(const PointerMove(x: 267.18, y: 107.82));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Commit rotation
        bloc.add(const PointerUp(x: 267.18, y: 107.82));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // After commit, verify rotation is reflected in state
        expect(
          bloc.state.selectionRotation.abs(),
          greaterThan(1.0),
          reason: 'selectionRotation should be non-zero after rotation',
        );
        expect(
          bloc.state.unrotatedSelectionRect,
          isNotNull,
          reason:
              'unrotatedSelectionRect should be non-null for rotated shape',
        );
      } else {
        fail('Could not trigger rotation mode — try adjusting handle position');
      }

      await bloc.close();
    });

    test('selection box encloses shape after moving a rotated shape', () async {
      final repo = _TestCanvasRepository();
      final bloc = CanvasBloc(repository: repo);

      // Create a shape that's already rotated 45° (simulating post-rotation)
      const angle = 45.0 * math.pi / 180.0;
      final rotatedTransform = Matrix2D.rotationAt(angle, 200, 175);

      final shape = RectangleShape(
        id: 'rect-move',
        name: 'Rect',
        x: 100,
        y: 100,
        rectWidth: 200,
        rectHeight: 150,
        transform: rotatedTransform,
        rotation: 45,
      );

      bloc.add(ShapeAdded(shape));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ShapeSelected('rect-move'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify initial state: rotated shape with OBB
      expect(bloc.state.selectionRotation, closeTo(45.0, 0.1));
      expect(bloc.state.unrotatedSelectionRect, isNotNull);

      // Record the world-space corners before move
      final shapeBefore = bloc.state.shapes['rect-move']!;
      final boundsBefore = shapeBefore.bounds;
      final cornersBefore = [
        shapeBefore.transformPoint(
          Offset(boundsBefore.left, boundsBefore.top),
        ),
        shapeBefore.transformPoint(
          Offset(boundsBefore.right, boundsBefore.top),
        ),
        shapeBefore.transformPoint(
          Offset(boundsBefore.right, boundsBefore.bottom),
        ),
        shapeBefore.transformPoint(
          Offset(boundsBefore.left, boundsBefore.bottom),
        ),
      ];

      // Simulate move: apply movedBy logic manually (transform.e/f += delta)
      const moveX = 50.0;
      const moveY = 30.0;
      final movedTransform = shapeBefore.transform.copyWith(
        e: shapeBefore.transform.e + moveX,
        f: shapeBefore.transform.f + moveY,
      );
      final movedShape = shape.copyWith(transform: movedTransform);

      // Replace shape in bloc
      bloc.add(ShapesReplaced({'rect-move': movedShape}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Re-select after replacement (ShapesReplaced clears selection)
      bloc.add(const ShapeSelected('rect-move'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify rotation is preserved
      expect(bloc.state.selectionRotation, closeTo(45.0, 0.1));
      expect(bloc.state.unrotatedSelectionRect, isNotNull);

      // Verify that moved corners are offset by (50, 30)
      final shapeAfter = bloc.state.shapes['rect-move']!;
      final boundsAfter = shapeAfter.bounds;
      final cornersAfter = [
        shapeAfter.transformPoint(
          Offset(boundsAfter.left, boundsAfter.top),
        ),
        shapeAfter.transformPoint(
          Offset(boundsAfter.right, boundsAfter.top),
        ),
        shapeAfter.transformPoint(
          Offset(boundsAfter.right, boundsAfter.bottom),
        ),
        shapeAfter.transformPoint(
          Offset(boundsAfter.left, boundsAfter.bottom),
        ),
      ];

      for (var i = 0; i < 4; i++) {
        expect(
          cornersAfter[i].dx,
          closeTo(cornersBefore[i].dx + moveX, 0.01),
          reason: 'Corner $i x should shift by $moveX',
        );
        expect(
          cornersAfter[i].dy,
          closeTo(cornersBefore[i].dy + moveY, 0.01),
          reason: 'Corner $i y should shift by $moveY',
        );
      }

      // Verify the unrotatedSelectionRect encloses the shape properly:
      // After un-rotating the moved corners, we should get a tight AABB
      // matching the original shape dimensions (200x150)
      final unrotated = bloc.state.unrotatedSelectionRect!;
      expect(unrotated.width, closeTo(200.0, 1.0));
      expect(unrotated.height, closeTo(150.0, 1.0));

      await bloc.close();
    });
  });
}
