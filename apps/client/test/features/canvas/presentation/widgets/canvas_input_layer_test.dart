import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/features/canvas/presentation/widgets/canvas_input_layer.dart';
import 'package:vio_core/vio_core.dart';

void main() {
  testWidgets('accepts ProjectAsset drop via DragTarget', (tester) async {
    ProjectAsset? acceptedAsset;
    const asset = ProjectAsset(
      id: 'asset-1',
      projectId: 'project-1',
      name: 'icon.svg',
      mimeType: 'image/svg+xml',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: CanvasInputLayer(
                  cursor: SystemMouseCursors.basic,
                  onHover: (_) {},
                  onExit: () {},
                  onPointerDown: (_) {},
                  onPointerMove: (_) {},
                  onPointerUp: (_) {},
                  onPointerSignal: (_) {},
                  onPointerPanZoomStart: (_) {},
                  onPointerPanZoomUpdate: (_) {},
                  onPointerPanZoomEnd: (_) {},
                  onAssetAccept: (details) => acceptedAsset = details.data,
                  child: Container(
                    key: const Key('drop-target'),
                    color: Colors.transparent,
                  ),
                ),
              ),
              const Positioned(
                left: 16,
                top: 16,
                child: Draggable<ProjectAsset>(
                  data: asset,
                  feedback: SizedBox(
                    width: 24,
                    height: 24,
                    child: ColoredBox(color: Colors.red),
                  ),
                  child: SizedBox(
                    key: Key('drag-source'),
                    width: 24,
                    height: 24,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final source = find.byKey(const Key('drag-source'));
    final target = find.byKey(const Key('drop-target'));

    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(acceptedAsset, isNotNull);
    expect(acceptedAsset?.id, equals('asset-1'));
  });

  testWidgets('forwards pointer down event', (tester) async {
    PointerDownEvent? pointerDown;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasInputLayer(
            cursor: SystemMouseCursors.basic,
            onHover: (_) {},
            onExit: () {},
            onPointerDown: (event) => pointerDown = event,
            onPointerMove: (_) {},
            onPointerUp: (_) {},
            onPointerSignal: (_) {},
            onPointerPanZoomStart: (_) {},
            onPointerPanZoomUpdate: (_) {},
            onPointerPanZoomEnd: (_) {},
            onAssetAccept: (_) {},
                  child: Container(color: Colors.transparent),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CanvasInputLayer));
    await tester.pump();

    expect(pointerDown, isNotNull);
  });
}
