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

Future<void> _settleBloc() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  group('Frame selectByClick behavior', () {
    test('select click inside frame body selects child, not frame', () async {
      final bloc = CanvasBloc(repository: _TestCanvasRepository());

      const frame = FrameShape(
        id: 'frame-1',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 300,
        frameHeight: 220,
      );

      const rect = RectangleShape(
        id: 'rect-1',
        name: 'Rect',
        x: 140,
        y: 140,
        rectWidth: 120,
        rectHeight: 80,
        frameId: 'frame-1',
        sortOrder: 1,
      );

      bloc.add(const ShapesAdded([frame, rect]));
      await _settleBloc();

      bloc.add(
        const PointerDown(x: 170, y: 170),
      );
      await _settleBloc();

      expect(bloc.state.selectedShapeIds, equals(['rect-1']));

      await bloc.close();
    });

    test('frame title click selects frame', () async {
      final bloc = CanvasBloc(repository: _TestCanvasRepository());

      const frame = FrameShape(
        id: 'frame-1',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 300,
        frameHeight: 220,
      );

      const rect = RectangleShape(
        id: 'rect-1',
        name: 'Rect',
        x: 140,
        y: 140,
        rectWidth: 120,
        rectHeight: 80,
        frameId: 'frame-1',
        sortOrder: 1,
      );

      bloc.add(const ShapesAdded([frame, rect]));
      await _settleBloc();

      // Frame title area is above the frame top edge.
      bloc.add(
        const PointerDown(x: 110, y: 90),
      );
      await _settleBloc();

      expect(bloc.state.selectedShapeIds, equals(['frame-1']));

      await bloc.close();
    });

    test('direct select ignores frame body', () async {
      final bloc = CanvasBloc(repository: _TestCanvasRepository());

      const frame = FrameShape(
        id: 'frame-1',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 300,
        frameHeight: 220,
      );

      bloc.add(const ShapeAdded(frame));
      await _settleBloc();

      bloc.add(
        const PointerDown(
          x: 160,
          y: 160,
          tool: CanvasPointerTool.directSelect,
        ),
      );
      await _settleBloc();

      expect(bloc.state.selectedShapeIds, isEmpty);

      await bloc.close();
    });

    test('repeated click cycles non-frame targets (group then child)',
        () async {
      final bloc = CanvasBloc(repository: _TestCanvasRepository());

      const frame = FrameShape(
        id: 'frame-1',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 320,
        frameHeight: 260,
      );

      const group = GroupShape(
        id: 'group-1',
        name: 'Group',
        x: 120,
        y: 120,
        groupWidth: 240,
        groupHeight: 200,
        frameId: 'frame-1',
        sortOrder: 1,
      );

      const rect = RectangleShape(
        id: 'rect-1',
        name: 'Rect',
        x: 150,
        y: 150,
        rectWidth: 100,
        rectHeight: 100,
        parentId: 'group-1',
        frameId: 'frame-1',
        sortOrder: 2,
      );

      bloc.add(const ShapesAdded([frame, group, rect]));
      await _settleBloc();

      bloc.add(
        const PointerDown(x: 170, y: 170),
      );
      await _settleBloc();
      expect(bloc.state.selectedShapeIds, equals(['group-1']));

      bloc.add(const PointerUp(x: 170, y: 170));
      await _settleBloc();

      bloc.add(
        const PointerDown(x: 170, y: 170),
      );
      await _settleBloc();
      expect(bloc.state.selectedShapeIds, equals(['rect-1']));

      await bloc.close();
    });

    test(
        'inside entered frame, click resolves to direct child then cycles deeper',
        () async {
      final bloc = CanvasBloc(repository: _TestCanvasRepository());

      const frame = FrameShape(
        id: 'frame-1',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 320,
        frameHeight: 260,
      );

      const group = GroupShape(
        id: 'group-1',
        name: 'Group',
        x: 120,
        y: 120,
        groupWidth: 240,
        groupHeight: 200,
        frameId: 'frame-1',
        sortOrder: 1,
      );

      const rect = RectangleShape(
        id: 'rect-1',
        name: 'Rect',
        x: 150,
        y: 150,
        rectWidth: 100,
        rectHeight: 100,
        parentId: 'group-1',
        frameId: 'frame-1',
        sortOrder: 2,
      );

      bloc.add(const ShapesAdded([frame, group, rect]));
      await _settleBloc();

      // Select frame via title first.
      bloc.add(const PointerDown(x: 110, y: 90));
      await _settleBloc();
      expect(bloc.state.selectedShapeIds, equals(['frame-1']));

      // Double-click inside descendants to enter frame container mode.
      bloc.add(const CanvasDoubleClicked(x: 170, y: 170));
      await _settleBloc();
      expect(bloc.state.enteredContainerId, equals('frame-1'));
      expect(bloc.state.selectedShapeIds, equals(['group-1']));

      // First click in entered frame prefers direct child (group).
      bloc.add(const PointerDown(x: 170, y: 170));
      await _settleBloc();
      expect(bloc.state.selectedShapeIds, equals(['group-1']));
      expect(bloc.state.enteredContainerId, equals('frame-1'));

      // Second click cycles to nested non-frame target.
      bloc.add(const PointerUp(x: 170, y: 170));
      await _settleBloc();
      bloc.add(const PointerDown(x: 170, y: 170));
      await _settleBloc();
      expect(bloc.state.selectedShapeIds, equals(['rect-1']));
      expect(bloc.state.enteredContainerId, equals('frame-1'));

      await bloc.close();
    });

    test('clicking entered frame body clears entered container', () async {
      final bloc = CanvasBloc(repository: _TestCanvasRepository());

      const frame = FrameShape(
        id: 'frame-1',
        name: 'Frame',
        x: 100,
        y: 100,
        frameWidth: 320,
        frameHeight: 260,
      );

      const group = GroupShape(
        id: 'group-1',
        name: 'Group',
        x: 120,
        y: 120,
        groupWidth: 120,
        groupHeight: 120,
        frameId: 'frame-1',
      );

      bloc.add(const ShapesAdded([frame, group]));
      await _settleBloc();

      // Enter frame container mode.
      bloc.add(const PointerDown(x: 110, y: 90));
      await _settleBloc();
      bloc.add(const CanvasDoubleClicked(x: 140, y: 140));
      await _settleBloc();
      expect(bloc.state.enteredContainerId, equals('frame-1'));

      // Click frame body area with no descendant under cursor.
      bloc.add(const PointerDown(x: 380, y: 320));
      await _settleBloc();

      expect(bloc.state.enteredContainerId, isNull);
      expect(bloc.state.selectedShapeIds, isEmpty);
    });
  });
}
