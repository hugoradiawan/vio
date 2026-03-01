import 'package:flutter/foundation.dart';
import 'package:vio_core/vio_core.dart';

import '../../rust/api/engine.dart';
import '../../rust/render/commands.dart';
import '../../rust/scene_graph/shape.dart';

/// Service wrapping the Rust [CanvasEngine] for the Flutter layer.
///
/// Provides a Dart-friendly API over the FFI-generated bindings.
/// Initialised eagerly at startup; the underlying engine is created lazily
/// on first access.
class RustEngineService {
  RustEngineService._();

  static final RustEngineService instance = RustEngineService._();

  CanvasEngine? _engine;

  /// Whether `RustLib.init()` completed successfully at startup.
  ///
  /// When `false`, the Rust FFI bridge is not available — callers should
  /// fall back to the pure-Dart code path even if compile-time flags like
  /// `VIO_USE_RUST_CANVAS` are set.
  bool rustAvailable = false;

  /// The underlying Rust canvas engine.
  ///
  /// Creates the engine on first access. After this call the engine is
  /// ready to receive shapes.
  CanvasEngine get engine {
    return _engine ??= CanvasEngine.create();
  }

  /// Whether the engine has been created yet.
  bool get isInitialized => _engine != null;

  /// Notifier bumped after every successful shape sync (loadAllShapes /
  /// syncShapes). Widgets can listen to this to regenerate draw commands
  /// once the engine has been updated, avoiding a race where
  /// `generateDrawCommands` runs before `loadAllShapes` completes.
  final ValueNotifier<int> syncGeneration = ValueNotifier(0);

  // ---------------------------------------------------------------------------
  // Scene management
  // ---------------------------------------------------------------------------

  /// Bulk-load every shape into the Rust scene graph, replacing any previous
  /// content. Use this on initial project load or branch switch.
  Future<void> loadAllShapes(List<RenderShape> shapes) async {
    await engine.loadAllShapes(shapes: shapes);
    syncGeneration.value++;
    VioLogger.debug(
      'RustEngine: loaded ${shapes.length} shapes (gen=${syncGeneration.value})',
    );
  }

  /// Push incremental shape changes (add / update / remove).
  /// Call this whenever [CanvasBloc] emits a new state.
  Future<void> syncShapes({
    List<RenderShape> added = const [],
    List<RenderShape> updated = const [],
    List<String> removed = const [],
  }) async {
    if (added.isEmpty && updated.isEmpty && removed.isEmpty) return;
    await engine.syncShapes(
      added: added,
      updated: updated,
      removed: removed,
    );
    syncGeneration.value++;
  }

  // ---------------------------------------------------------------------------
  // Queries (sync — no Future)
  // ---------------------------------------------------------------------------

  /// Return IDs of shapes visible inside [viewport] (minX, minY, maxX, maxY).
  List<String> queryVisible(
    double minX,
    double minY,
    double maxX,
    double maxY,
  ) {
    return engine.queryVisible(
      viewportMinX: minX,
      viewportMinY: minY,
      viewportMaxX: maxX,
      viewportMaxY: maxY,
    );
  }

  /// Hit-test a single point. Returns shape IDs topmost-first.
  List<String> hitTestPoint(double x, double y) {
    return engine.hitTestPoint(x: x, y: y);
  }

  /// Hit-test a rectangle (drag-select). Returns shape IDs.
  List<String> hitTestRect(double x, double y, double w, double h) {
    return engine.hitTestRect(x: x, y: y, w: w, h: h);
  }

  /// Paint order: depth-first shape IDs.
  List<String> paintOrder() => engine.paintOrder();

  /// Generate draw commands for the visible area.
  ///
  /// [viewMatrix] is the 6-element affine `[a, b, c, d, e, f]`.
  /// [viewportMinX..maxY] is the visible rect in canvas (world) coordinates.
  /// When [simplify] is true, shadows/blurs/gradients are elided.
  /// When [skipTileRasterized] is true, shapes already rendered into tiles are
  /// excluded from the returned command list.
  Future<List<DrawCommand>> generateDrawCommands({
    required double viewportMinX,
    required double viewportMinY,
    required double viewportMaxX,
    required double viewportMaxY,
    required List<double> viewMatrix,
    required bool simplify,
    bool skipTileRasterized = false,
  }) {
    return engine.generateDrawCommands(
      viewportMinX: viewportMinX,
      viewportMinY: viewportMinY,
      viewportMaxX: viewportMaxX,
      viewportMaxY: viewportMaxY,
      viewMatrix: viewMatrix,
      simplify: simplify,
      skipTileRasterized: skipTileRasterized,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 3: Tile rasterization
  // ---------------------------------------------------------------------------

  /// Rasterize dirty tiles in the viewport.
  ///
  /// Returns a list of [TileResult]s containing the tile's pixel data and
  /// grid position. After rasterization the tiles are cached internally;
  /// subsequent calls only re-render tiles whose shapes have changed.
  Future<List<TileResult>> rasterizeDirtyTiles({
    required double viewportMinX,
    required double viewportMinY,
    required double viewportMaxX,
    required double viewportMaxY,
    required double zoom,
  }) {
    return engine.rasterizeDirtyTiles(
      viewportMinX: viewportMinX,
      viewportMinY: viewportMinY,
      viewportMaxX: viewportMaxX,
      viewportMaxY: viewportMaxY,
      zoom: zoom,
    );
  }

  /// Mark all cached tiles as dirty (e.g. after branch switch).
  Future<void> markAllTilesDirty() => engine.markAllTilesDirty();

  /// Tile cache stats: [cached, dirty, occupied].
  Int32List get tileCacheStats => engine.tileCacheStats();

  /// Number of shapes that are tile-rasterized.
  int get tileRasterizedCount => engine.tileRasterizedCount().toInt();

  /// Total shape count.
  int get shapeCount => engine.shapeCount().toInt();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Reset the engine (e.g. on project close / branch switch).
  void reset() {
    _engine = null;
  }
}
