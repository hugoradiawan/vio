import 'package:vio_core/vio_core.dart';

import '../../rust/api/engine.dart';
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

  /// The underlying Rust canvas engine.
  ///
  /// Creates the engine on first access. After this call the engine is
  /// ready to receive shapes.
  CanvasEngine get engine {
    return _engine ??= CanvasEngine.create();
  }

  /// Whether the engine has been created yet.
  bool get isInitialized => _engine != null;

  // ---------------------------------------------------------------------------
  // Scene management
  // ---------------------------------------------------------------------------

  /// Bulk-load every shape into the Rust scene graph, replacing any previous
  /// content. Use this on initial project load or branch switch.
  Future<void> loadAllShapes(List<RenderShape> shapes) async {
    await engine.loadAllShapes(shapes: shapes);
    VioLogger.debug(
      'RustEngine: loaded ${shapes.length} shapes',
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
