import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/services/rust_engine_service.dart';
import '../../../../rust/render/commands.dart';
import '../../bloc/canvas_bloc.dart';
import '../painters/rust_canvas_painter.dart';
import '../viewport_notifier.dart';

/// Stateful wrapper that manages asynchronous draw-command generation from the
/// Rust engine and feeds the result into [RustCanvasPainter].
///
/// **Viewport fast path:** The [viewportNotifier] drives repaint without
/// widget rebuild. Only shape/selection/hover changes trigger
/// `_regenerateCommands`. During pan/zoom the painter replays cached draw
/// commands with the updated view matrix — zero FFI calls per frame.
class RustCanvasLayer extends StatefulWidget {
  const RustCanvasLayer({
    required this.canvasState,
    required this.orderedShapes,
    required this.editingTextShapeId,
    required this.viewportNotifier,
    required this.interactionNotifier,
    this.skipTileRasterized = false,
    super.key,
  });

  final CanvasState canvasState;
  final List<Shape> orderedShapes;
  final String? editingTextShapeId;

  /// Lightweight notifier for viewport changes (zoom / offset).
  /// The painter listens to this as its `repaint` listenable so viewport-only
  /// changes repaint without crossing FFI or rebuilding widgets.
  final ViewportNotifier viewportNotifier;

  /// Separate notifier for interaction state. Fires only 2× per gesture
  /// (start/stop) — used by the painter to toggle simplification.
  final ValueNotifier<bool> interactionNotifier;

  /// When `true`, shapes that are rendered into cached tiles by the Rust engine
  /// are excluded from the draw command list (because they are painted by
  /// [TileCompositorLayer] underneath instead).
  final bool skipTileRasterized;

  @override
  State<RustCanvasLayer> createState() => _RustCanvasLayerState();
}

class _RustCanvasLayerState extends State<RustCanvasLayer> {
  List<DrawCommand> _commands = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // Listen for engine sync completions so we re-generate draw commands
    // even when loadAllShapes finishes *after* the widget's first build.
    RustEngineService.instance.syncGeneration.addListener(_onSyncGeneration);
    _regenerateCommands();
  }

  @override
  void dispose() {
    RustEngineService.instance.syncGeneration.removeListener(_onSyncGeneration);
    super.dispose();
  }

  void _onSyncGeneration() {
    // Engine just finished loading/syncing shapes — regenerate commands.
    _regenerateCommands();
  }

  @override
  void didUpdateWidget(RustCanvasLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only regenerate commands when non-viewport state changed (shapes,
    // selection, hover, etc.). Viewport changes are handled by
    // ViewportNotifier → repaint without FFI.
    final needsRegenerate = !identical(
          widget.canvasState.shapes,
          oldWidget.canvasState.shapes,
        ) ||
        widget.editingTextShapeId != oldWidget.editingTextShapeId ||
        widget.skipTileRasterized != oldWidget.skipTileRasterized;

    if (needsRegenerate) {
      _regenerateCommands();
    }
  }

  Future<void> _regenerateCommands() async {
    final gen = ++_generation;
    final vp = widget.viewportNotifier;
    final vm = vp.viewMatrix;
    final isInteracting = widget.interactionNotifier.value;

    // Use a very large viewport so ALL shapes are included in the command
    // list. Since commands are cached and replayed during pan/zoom, we
    // cannot cull to the current viewport — the user might pan beyond it.
    // Flutter's Canvas already clips to the screen, so off-screen draw
    // calls are essentially free. For very large canvases (10k+ shapes)
    // we can revisit with incremental re-culling.
    const double inf = 1e9;

    try {
      final commands = RustEngineService.instance.generateDrawCommands(
        viewportMinX: -inf,
        viewportMinY: -inf,
        viewportMaxX: inf,
        viewportMaxY: inf,
        viewMatrix: [vm.a, vm.b, vm.c, vm.d, vm.e, vm.f],
        simplify: isInteracting,
        skipTileRasterized: widget.skipTileRasterized,
      );

      // Discard stale results (a newer generation was already requested).
      if (gen != _generation || !mounted) return;

      setState(() {
        _commands = commands;
      });
    } catch (e, st) {
      VioLogger.error('RustCanvasLayer: command generation failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.canvasState;
    return RepaintBoundary(
      child: CustomPaint(
        willChange: true,
        painter: RustCanvasPainter(
          repaintNotifier: widget.viewportNotifier,
          drawCommands: _commands,
          shapes: widget.orderedShapes,
          shapesById: state.shapes,
          viewportNotifier: widget.viewportNotifier,
          interactionNotifier: widget.interactionNotifier,
          selectionColor: VioCanvasTheme.of(context).selectionColor,
          dragRect: state.dragRect,
          dragOffset: state.dragOffset,
          selectedShapeIds: state.selectedShapeIds,
          hoveredShapeId: state.hoveredShapeId,
          hoveredLayerId: state.hoveredLayerId,
          editingTextShapeId: widget.editingTextShapeId,
        ),
      ),
    );
  }
}
