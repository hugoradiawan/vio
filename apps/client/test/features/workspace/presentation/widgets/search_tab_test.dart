import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_client/src/features/assets/bloc/asset_bloc.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/version_control/bloc/version_control_bloc.dart';
import 'package:vio_client/src/features/workspace/bloc/search_bloc.dart';
import 'package:vio_client/src/features/workspace/presentation/widgets/search_tab.dart';
import 'package:vio_client/src/gen/vio/v1/asset.pbgrpc.dart';
import 'package:vio_core/vio_core.dart';

void main() {
  group('SearchTab', () {
    late ClientChannel channel;
    late CanvasBloc canvasBloc;
    late AssetBloc assetBloc;
    late VersionControlBloc versionControlBloc;
    late SearchBloc searchBloc;

    String? tappedShapeId;
    String? hoveredShapeId;

    Future<void> initializeHarness() async {
      tappedShapeId = null;
      hoveredShapeId = null;

      channel = ClientChannel(
        'localhost',
        port: 0,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
      canvasBloc = CanvasBloc();
      assetBloc = AssetBloc(
        assetService: AssetServiceClient(channel),
        canvasBloc: canvasBloc,
      );
      versionControlBloc = VersionControlBloc();
      searchBloc = SearchBloc(
        canvasBloc: canvasBloc,
        assetBloc: assetBloc,
        versionControlBloc: versionControlBloc,
      );

      addTearDown(() async {
        await searchBloc.close();
        await assetBloc.close();
        await canvasBloc.close();
        await versionControlBloc.close();
        await channel.shutdown();
      });
    }

    Future<void> waitUntilReady(
      WidgetTester tester, {
      required bool Function(SearchState state) condition,
      Duration timeout = const Duration(seconds: 2),
    }) async {
      final started = DateTime.now();
      while (!condition(searchBloc.state)) {
        if (DateTime.now().difference(started) > timeout) {
          fail(
            'Timed out waiting for SearchBloc state. Current state: '
            '${searchBloc.state.status}, query=${searchBloc.state.query}',
          );
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
    }

    Widget buildWidget() {
      return MultiBlocProvider(
        providers: [
          BlocProvider<CanvasBloc>.value(value: canvasBloc),
          BlocProvider<AssetBloc>.value(value: assetBloc),
          BlocProvider<VersionControlBloc>.value(value: versionControlBloc),
          BlocProvider<SearchBloc>.value(value: searchBloc),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SearchTab(
              onLayerResultTap: ({required shapeId}) {
                tappedShapeId = shapeId;
              },
              onLayerResultHoverChanged: (shapeId) {
                hoveredShapeId = shapeId;
              },
            ),
          ),
        ),
      );
    }

    testWidgets('shows empty state when query is empty', (tester) async {
      await initializeHarness();

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.text(
          'Search layers, assets, colors, branches, commits, and pull requests',
        ),
        findsOneWidget,
      );
      expect(find.text('No results found'), findsNothing);
    });

    testWidgets('shows searching then no results for unmatched query', (
      tester,
    ) async {
      await initializeHarness();

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'nope');
      searchBloc.add(const SearchQueryChanged('nope'));
      await tester.pump(const Duration(milliseconds: 30));

      await waitUntilReady(
        tester,
        condition: (state) =>
            state.status == SearchStatus.ready && state.totalResults == 0,
      );

      expect(searchBloc.state.query, 'nope');
      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('tapping and hovering a layer result triggers callbacks', (
      tester,
    ) async {
      await initializeHarness();

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      const shape = RectangleShape(
        id: 'shape-layer-1',
        name: 'Layer Target',
        x: 5,
        y: 10,
        rectWidth: 100,
        rectHeight: 40,
      );

      canvasBloc.add(const ShapeAdded(shape));
      await tester.pump(const Duration(milliseconds: 30));

      await tester.enterText(find.byType(TextField), 'layer');
      searchBloc.add(const SearchQueryChanged('layer'));
      await tester.pump(const Duration(milliseconds: 30));

      await waitUntilReady(
        tester,
        condition: (state) =>
            state.status == SearchStatus.ready && state.layerResults.isNotEmpty,
      );

      expect(searchBloc.state.query, 'layer');

      final resultText = find.text('Layer Target');
      expect(resultText, findsOneWidget);

      await tester.tap(resultText);
      await tester.pump();

      expect(tappedShapeId, 'shape-layer-1');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(0, 0));
      await tester.pump();

      await mouse.moveTo(tester.getCenter(resultText));
      await tester.pump();

      expect(hoveredShapeId, 'shape-layer-1');

      await mouse.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pump();

      expect(hoveredShapeId, isNull);
    });
  });
}
