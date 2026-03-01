part of 'canvas_bloc.dart';

/// Mixin that keeps the Rust [CanvasEngine] in sync with the canvas state
/// and delegates hit-testing / spatial queries to Rust when enabled.
///
/// Listens to every BLoC emission; when the shapes map changes it computes
/// a diff and pushes (added, updated, removed) to the engine.
///
/// Hit-testing is toggled via [useRustHitTest]. When `true`, hit-test calls
/// go through Rust's R-tree spatial index. When `false`, the existing Dart
/// [HitTest] utility is used (default during migration).
mixin _CanvasRustMixin on Bloc<CanvasEvent, CanvasState> {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Whether to use Rust for hit testing. Toggle via `--dart-define`
  /// `VIO_USE_RUST_HIT_TEST=true` or flip at runtime for A/B debugging.
  bool useRustHitTest = const bool.fromEnvironment(
    'VIO_USE_RUST_HIT_TEST',
  );

  // ---------------------------------------------------------------------------
  // State tracking for diff-based sync
  // ---------------------------------------------------------------------------

  /// The last shapes map synced to Rust. Used to compute diffs.
  Map<String, Shape> _lastRustSyncedShapes = const {};

  /// Whether the initial bulk load has been performed.
  bool _rustEngineLoaded = false;

  // ---------------------------------------------------------------------------
  // Service accessor
  // ---------------------------------------------------------------------------

  RustEngineService get _rustEngine => RustEngineService.instance;

  // ---------------------------------------------------------------------------
  // Sync logic
  // ---------------------------------------------------------------------------

  /// Should be called from the BLoC constructor's `onChange` (or by each
  /// event handler that changes shapes).
  ///
  /// Compares [newShapes] with the last synced snapshot and pushes the diff
  /// to the Rust engine.
  Future<void> _syncShapesToRust(Map<String, Shape> newShapes) async {
    // Skip if shapes map is the same reference (no change)
    if (identical(newShapes, _lastRustSyncedShapes)) return;

    try {
      if (!_rustEngineLoaded) {
        // First time — bulk-load all shapes
        final renderShapes = RenderShapeConverter.toRenderShapes(newShapes);
        await _rustEngine.loadAllShapes(renderShapes);
        _rustEngineLoaded = true;
        _lastRustSyncedShapes = newShapes;
        VioLogger.debug(
          'Rust engine: initial load of ${renderShapes.length} shapes, '
          'tree has ${_rustEngine.shapeCount} shapes',
        );
        return;
      }

      // Incremental diff sync
      final diff = RenderShapeConverter.diffShapes(
        _lastRustSyncedShapes,
        newShapes,
      );

      if (diff.added.isNotEmpty ||
          diff.updated.isNotEmpty ||
          diff.removed.isNotEmpty) {
        await _rustEngine.syncShapes(
          added: diff.added,
          updated: diff.updated,
          removed: diff.removed,
        );
        VioLogger.debug(
          'Rust engine sync: +${diff.added.length} ~${diff.updated.length} -${diff.removed.length}',
        );
      }

      _lastRustSyncedShapes = newShapes;
    } catch (e, st) {
      VioLogger.error('Rust engine sync failed', e, st);
    }
  }

  /// Force a full reload of the Rust engine (e.g. after branch switch).
  // Future<void> _reloadRustEngine(Map<String, Shape> shapes) async {
  //   try {
  //     _rustEngine.reset();
  //     _rustEngineLoaded = false;
  //     await _syncShapesToRust(shapes);
  //   } catch (e, st) {
  //     VioLogger.error('Rust engine reload failed', e, st);
  //   }
  // }

  // ---------------------------------------------------------------------------
  // Hit testing — delegates to Rust or Dart based on feature flag
  // ---------------------------------------------------------------------------

  /// Find the topmost shape at [canvasPoint].
  ///
  /// When [useRustHitTest] is `true`, queries the Rust R-tree spatial index.
  /// Otherwise falls back to the existing O(n) Dart scan.
  Shape? findTopShapeAtPoint(Offset canvasPoint, List<Shape> shapeList) {
    if (!useRustHitTest || !_rustEngineLoaded) {
      return HitTest.findTopShapeAtPoint(canvasPoint, shapeList);
    }

    final hitIds = _rustEngine.hitTestPoint(canvasPoint.dx, canvasPoint.dy);
    if (hitIds.isEmpty) return null;

    // hitIds are topmost-first. Find the first matching Shape that isn't
    // hidden/blocked (Rust already filters hidden but not blocked).
    for (final id in hitIds) {
      final shape = state.shapes[id];
      if (shape != null && !shape.blocked) return shape;
    }
    return null;
  }

  /// Find all shapes intersecting [rect] (marquee selection).
  ///
  /// When [useRustHitTest] is `true`, queries the Rust R-tree.
  /// Otherwise falls back to the existing Dart scan.
  List<Shape> findShapesInRect(Rect rect, List<Shape> shapeList) {
    if (!useRustHitTest || !_rustEngineLoaded) {
      return HitTest.findShapesInRect(rect, shapeList);
    }

    final hitIds = _rustEngine.hitTestRect(
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    );

    // Filter out frames (same behaviour as Dart HitTest.findShapesInRect)
    // and blocked shapes.
    final results = <Shape>[];
    for (final id in hitIds) {
      final shape = state.shapes[id];
      if (shape == null) continue;
      if (shape.hidden || shape.blocked) continue;
      if (shape.type == ShapeType.frame) continue;
      results.add(shape);
    }
    return results;
  }
}
