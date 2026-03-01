import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

import '../../../../core/services/rust_engine_service.dart';
import '../../../../rust/render/commands.dart';
import '../../bloc/canvas_bloc.dart';
import '../painters/rust_canvas_painter.dart';

/// Stateful wrapper that manages asynchronous draw-command generation from the
/// Rust engine and feeds the result into [RustCanvasPainter].
///
/// On every rebuild (triggered by new [CanvasState]) it kicks off
/// `generateDrawCommands` and, once the future completes, calls `setState` to
/// repaint with the fresh command list.
///
/// While the first frame is loading, a transparent placeholder is shown so
/// layout is not blocked.
class RustCanvasLayer extends StatefulWidget {
  const RustCanvasLayer({
    required this.canvasState,
    required this.orderedShapes,
    required this.editingTextShapeId,
    required this.isViewportInteractionActive,
    this.skipTileRasterized = false,
    super.key,
  });

  final CanvasState canvasState;
  final List<Shape> orderedShapes;
  final String? editingTextShapeId;
  final bool isViewportInteractionActive;

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
    // Always regenerate — draw commands depend on shapes, viewport, zoom, etc.
    _regenerateCommands();
  }

  Future<void> _regenerateCommands() async {
    final gen = ++_generation;
    final state = widget.canvasState;
    final vm = state.viewMatrix;
    final size = state.viewportSize;

    // Compute visible canvas rect (inverse of view matrix)
    final zoom = vm.a.abs();
    final effectiveZoom = zoom <= 0 ? 1.0 : zoom;
    final canvasLeft = -vm.e / effectiveZoom;
    final canvasTop = -vm.f / effectiveZoom;
    final canvasRight = canvasLeft + size.width / effectiveZoom;
    final canvasBottom = canvasTop + size.height / effectiveZoom;

    // Inflate a bit to include partially-visible shapes
    final inflate = widget.isViewportInteractionActive ? 320.0 : 160.0;
    final inflatedZoom = inflate / effectiveZoom;

    try {
      final commands = await RustEngineService.instance.generateDrawCommands(
        viewportMinX: canvasLeft - inflatedZoom,
        viewportMinY: canvasTop - inflatedZoom,
        viewportMaxX: canvasRight + inflatedZoom,
        viewportMaxY: canvasBottom + inflatedZoom,
        viewMatrix: [vm.a, vm.b, vm.c, vm.d, vm.e, vm.f],
        simplify: widget.isViewportInteractionActive,
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
        isComplex: true,
        willChange: true,
        painter: RustCanvasPainter(
          drawCommands: _commands,
          shapes: widget.orderedShapes,
          shapesById: state.shapes,
          viewMatrix: state.viewMatrix,
          dragRect: state.dragRect,
          dragOffset: state.dragOffset,
          selectedShapeIds: state.selectedShapeIds,
          hoveredShapeId: state.hoveredShapeId,
          hoveredLayerId: state.hoveredLayerId,
          editingTextShapeId: widget.editingTextShapeId,
          simplifyForInteraction: widget.isViewportInteractionActive,
        ),
      ),
    );
  }
}
