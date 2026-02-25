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

  final List<Shape> addedShapes = <Shape>[];

  @override
  void addShape(Shape shape) {
    addedShapes.add(shape);
  }
}

void main() {
  group('CanvasBloc duplicate persistence', () {
    test('duplicate frame enqueues repository create operation', () async {
      final repository = _TestCanvasRepository();
      final bloc = CanvasBloc(repository: repository);

      const originalFrame = FrameShape(
        id: 'frame-original',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 400,
        frameHeight: 300,
      );

      bloc.add(const ShapeAdded(originalFrame));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ShapeSelected('frame-original'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const DuplicateSelected());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final duplicatedFrameId = bloc.state.selectedShapeIds.single;
      expect(duplicatedFrameId, isNot(originalFrame.id));
      expect(bloc.state.shapes[duplicatedFrameId], isA<FrameShape>());

      expect(
        repository.addedShapes.any((shape) => shape.id == duplicatedFrameId),
        isTrue,
      );

      await bloc.close();
    });

    test('paste frame enqueues repository create operation', () async {
      final repository = _TestCanvasRepository();
      final bloc = CanvasBloc(repository: repository);

      const originalFrame = FrameShape(
        id: 'frame-original',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 400,
        frameHeight: 300,
      );

      bloc.add(const ShapeAdded(originalFrame));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ShapeSelected('frame-original'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const CopySelected());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const PasteShapes());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final pastedFrameId = bloc.state.selectedShapeIds.single;
      expect(pastedFrameId, isNot(originalFrame.id));
      expect(bloc.state.shapes[pastedFrameId], isA<FrameShape>());

      expect(
        repository.addedShapes.any((shape) => shape.id == pastedFrameId),
        isTrue,
      );

      await bloc.close();
    });
  });
}
