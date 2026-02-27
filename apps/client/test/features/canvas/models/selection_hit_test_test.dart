import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/features/canvas/models/handle_types.dart';
import 'package:vio_client/src/features/canvas/models/selection_handle_metrics.dart';
import 'package:vio_client/src/features/canvas/models/selection_hit_test.dart';

void main() {
  group('hitTestSelectionAffordance', () {
    test('keeps rotation handle offset constant in screen pixels across zoom',
        () {
      const bounds = Rect.fromLTWH(100, 200, 120, 80);
      const viewportOffset = Offset(40, -30);

      for (final zoom in [0.5, 1.0, 4.0]) {
        final centerX = bounds.center.dx * zoom + viewportOffset.dx;
        final rotationY = bounds.top * zoom +
            viewportOffset.dy -
            SelectionHandleMetrics.rotationOffset;

        final result = hitTestSelectionAffordance(
          screenPoint: Offset(centerX, rotationY),
          selectionBounds: bounds,
          zoom: zoom,
          viewportOffset: viewportOffset,
          isSingleTextSelection: false,
        );

        expect(result, isNotNull);
        expect(result!.isHandle, isTrue);
        expect(result.handle, HandlePosition.rotation);
      }
    });

    test('uses larger hit target than visible square handle', () {
      const bounds = Rect.fromLTWH(100, 100, 200, 100);
      const zoom = 2.0;
      const viewportOffset = Offset.zero;

      final topLeftCenter = Offset(bounds.left * zoom, bounds.top * zoom);
      final pointOutsideVisualButInsideHit =
          Offset(topLeftCenter.dx + 6.5, topLeftCenter.dy);

      final result = hitTestSelectionAffordance(
        screenPoint: pointOutsideVisualButInsideHit,
        selectionBounds: bounds,
        zoom: zoom,
        viewportOffset: viewportOffset,
        isSingleTextSelection: false,
      );

      expect(result, isNotNull);
      expect(result!.isHandle, isTrue);
      expect(result.handle, HandlePosition.topLeft);
    });
  });
}
