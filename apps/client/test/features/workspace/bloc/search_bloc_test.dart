import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_client/src/features/assets/bloc/asset_bloc.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/version_control/bloc/version_control_bloc.dart';
import 'package:vio_client/src/features/workspace/bloc/search_bloc.dart';
import 'package:vio_client/src/gen/vio/v1/asset.pbgrpc.dart';
import 'package:vio_core/vio_core.dart';

void main() {
  group('SearchBloc', () {
    late ClientChannel channel;
    late CanvasBloc canvasBloc;
    late AssetBloc assetBloc;
    late VersionControlBloc versionControlBloc;
    late SearchBloc searchBloc;

    Future<void> waitForBlocTick() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    setUp(() {
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
    });

    tearDown(() async {
      await searchBloc.close();
      await assetBloc.close();
      await canvasBloc.close();
      await versionControlBloc.close();
      await channel.shutdown();
    });

    test('debounces query and emits filtered layer results', () async {
      const shape = RectangleShape(
        id: 'shape-1',
        name: 'Button Primary',
        x: 10,
        y: 20,
        rectWidth: 120,
        rectHeight: 36,
      );

      canvasBloc.add(const ShapeAdded(shape));
      await waitForBlocTick();

      searchBloc.add(const SearchQueryChanged('  button  '));
      await waitForBlocTick();

      expect(searchBloc.state.query, 'button');
      expect(searchBloc.state.status, SearchStatus.searching);
      expect(searchBloc.state.layerResults, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(searchBloc.state.status, SearchStatus.ready);
      expect(searchBloc.state.layerResults, hasLength(1));
      expect(searchBloc.state.layerResults.single.shapeId, 'shape-1');
      expect(searchBloc.state.layerResults.single.title, 'Button Primary');
    });

    test('recomputes results after source updates while query is active',
        () async {
      const alphaShape = RectangleShape(
        id: 'shape-alpha',
        name: 'Alpha',
        x: 0,
        y: 0,
        rectWidth: 20,
        rectHeight: 20,
      );

      canvasBloc.add(const ShapeAdded(alphaShape));
      await waitForBlocTick();

      searchBloc.add(const SearchQueryChanged('alpha'));
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(searchBloc.state.status, SearchStatus.ready);
      expect(searchBloc.state.layerResults, hasLength(1));

      const betaShape = RectangleShape(
        id: 'shape-beta',
        name: 'Beta',
        x: 5,
        y: 5,
        rectWidth: 30,
        rectHeight: 30,
      );

      canvasBloc.add(const ShapesReplaced({'shape-beta': betaShape}));
      await waitForBlocTick();

      expect(searchBloc.state.status, SearchStatus.searching);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(searchBloc.state.status, SearchStatus.ready);
      expect(searchBloc.state.layerResults, isEmpty);
      expect(searchBloc.state.totalResults, 0);
    });

    test('limits each section to 30 results', () async {
      final shapes = <String, Shape>{
        for (int i = 0; i < 35; i++)
          'shape-$i': RectangleShape(
            id: 'shape-$i',
            name: 'Match $i',
            x: i.toDouble(),
            y: i.toDouble(),
            rectWidth: 10,
            rectHeight: 10,
          ),
      };

      canvasBloc.add(ShapesReplaced(shapes));
      await waitForBlocTick();

      searchBloc.add(const SearchQueryChanged('match'));
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(searchBloc.state.status, SearchStatus.ready);
      expect(searchBloc.state.layerResults.length, 30);
      expect(searchBloc.state.totalResults, 30);
    });
  });
}
