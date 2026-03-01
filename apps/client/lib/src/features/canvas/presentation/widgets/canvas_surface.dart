import 'package:flutter/material.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/canvas_painter.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/grid_painter.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/horizontal_ruler_painter.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/selection_box_painter.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/size_indicator_painter.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/snap_guides_painter.dart';
import 'package:vio_client/src/features/canvas/presentation/painters/vertical_ruler_painter.dart';
import 'package:vio_client/src/features/workspace/bloc/workspace_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../../core/services/rust_engine_service.dart';
import '../viewport_notifier.dart';
import 'canvas_status_widgets.dart';
import 'canvas_text_editor_overlay.dart';
import 'rust_canvas_layer.dart';
import 'tile_compositor_layer.dart';

/// Feature flag: when `true`, the Rust engine generates draw commands and
/// [RustCanvasPainter] executes them instead of the Dart-only [CanvasPainter].
///
/// Toggle via `--dart-define=VIO_USE_RUST_CANVAS=true`.
///
/// At runtime this is combined with [RustEngineService.rustAvailable] so that
/// the canvas falls back to the Dart renderer when WASM fails to load.
const _useRustCanvasFlag = bool.fromEnvironment('VIO_USE_RUST_CANVAS');

/// Feature flag: when `true` (and `VIO_USE_RUST_CANVAS` is also `true`),
/// static shapes are pre-rendered into cached 512×512 tiles by tiny-skia in
/// Rust. Tiles are composited behind the live draw-command layer.
///
/// Toggle via `--dart-define=VIO_USE_RUST_TILES=true`.
const _useRustTilesFlag = bool.fromEnvironment('VIO_USE_RUST_TILES');

/// Whether to actually use Rust at runtime — requires both the compile-time
/// flag AND successful WASM/FFI initialisation.
bool get _useRustCanvas =>
    _useRustCanvasFlag && RustEngineService.instance.rustAvailable;
bool get _useRustTiles =>
    _useRustTilesFlag && RustEngineService.instance.rustAvailable;

class CanvasSurface extends StatelessWidget {
  const CanvasSurface({
    required this.canvasState,
    required this.workspaceState,
    required this.orderedShapes,
    required this.selectionRect,
    required this.editingTextShapeId,
    required this.textController,
    required this.textFocusNode,
    required this.viewportNotifier,
    required this.interactionNotifier,
    super.key,
  });

  final CanvasState canvasState;
  final WorkspaceState workspaceState;
  final List<Shape> orderedShapes;
  final Rect? selectionRect;
  final String? editingTextShapeId;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final ViewportNotifier viewportNotifier;

  /// Fires only when interaction starts/stops (2× per gesture).
  /// Used by ListenableBuilder to conditionally show/hide overlays.
  final ValueNotifier<bool> interactionNotifier;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // ListenableBuilder rebuilds only the Stack when ViewportNotifier
      // fires (interaction active/inactive). The parent widget tree is
      // NOT rebuilt — this eliminates the 256ms build cost during
      // pan/zoom gestures.
      child: ListenableBuilder(
        listenable: interactionNotifier,
        builder: (context, _) {
          final isInteracting = interactionNotifier.value;
          return Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: VioColors.canvasBackground,
            ),
          ),
          if (workspaceState.showGrid && !isInteracting)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: GridPainter(
                    gridSize: workspaceState.gridSize,
                    zoom: canvasState.zoom,
                    offset: Offset(
                      canvasState.viewportOffset.dx,
                      canvasState.viewportOffset.dy,
                    ),
                  ),
                ),
              ),
            ),
          // Tile layer: renders static shapes from cached tiles (behind draw cmds)
          if (_useRustCanvas && _useRustTiles)
            Positioned.fill(
              child: TileCompositorLayer(
                canvasState: canvasState,
              ),
            ),
          // Shape / draw-command layer
          Positioned.fill(
            child: _useRustCanvas
                ? RustCanvasLayer(
                    canvasState: canvasState,
                    orderedShapes: orderedShapes,
                    editingTextShapeId: editingTextShapeId,
                    viewportNotifier: viewportNotifier,
                    interactionNotifier: interactionNotifier,
                  )
                : RepaintBoundary(
                    child: CustomPaint(
                      isComplex: true,
                      willChange: true,
                      painter: CanvasPainter(
                        viewMatrix: canvasState.viewMatrix,
                        shapes: orderedShapes,
                        shapesById: canvasState.shapes,
                        containmentTree: canvasState.containmentTree,
                        dragRect: canvasState.dragRect,
                        dragOffset: canvasState.dragOffset,
                        selectedShapeIds: canvasState.selectedShapeIds,
                        hoveredShapeId: canvasState.hoveredShapeId,
                        hoveredLayerId: canvasState.hoveredLayerId,
                        editingTextShapeId: editingTextShapeId,
                        simplifyForInteraction: isInteracting,
                      ),
                    ),
                  ),
          ),
          if (canvasState.hasSelection && !isInteracting)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  willChange: true,
                  painter: SelectionBoxPainter(
                    selectedShapes: canvasState.selectedShapes,
                    viewMatrix: canvasState.viewMatrix,
                    dragOffset: canvasState.dragOffset,
                    activeCornerIndex: canvasState.activeCornerIndex,
                    hoveredCornerIndex: canvasState.hoveredCornerIndex,
                    showCornerRadiusHandles:
                        canvasState.selectedShapes.length == 1 &&
                            canvasState.selectedShapes.first is RectangleShape,
                  ),
                ),
              ),
            ),
          if (!isInteracting &&
              (canvasState.snapLines.isNotEmpty ||
                  canvasState.snapPoints.isNotEmpty))
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  willChange: true,
                  painter: SnapGuidesPainter(
                    snapLines: canvasState.snapLines,
                    snapPoints: canvasState.snapPoints,
                    viewMatrix: canvasState.viewMatrix,
                    zoom: canvasState.zoom,
                  ),
                ),
              ),
            ),
          if (!isInteracting &&
              canvasState.hasSelection &&
              selectionRect != null)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SizeIndicatorPainter(
                    selectionRect: selectionRect,
                    viewMatrix: canvasState.viewMatrix,
                    zoom: canvasState.zoom,
                  ),
                ),
              ),
            ),
          if (workspaceState.showRulers && !isInteracting) ...[
            Positioned(
              top: 0,
              left: 20,
              right: 0,
              height: 20,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: HorizontalRulerPainter(
                    offset: canvasState.viewportOffset.dx,
                    zoom: canvasState.zoom,
                    selectionRect: selectionRect,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 0,
              bottom: 0,
              width: 20,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: VerticalRulerPainter(
                    offset: canvasState.viewportOffset.dy,
                    zoom: canvasState.zoom,
                    selectionRect: selectionRect,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              width: 20,
              height: 20,
              child: Container(
                color: VioColors.surface2,
              ),
            ),
          ],
          Positioned(
            bottom: VioSpacing.sm,
            left: VioSpacing.xxl,
            child: CanvasCoordinatesDisplay(
              pointer: canvasState.currentPointer,
            ),
          ),
          Positioned(
            bottom: VioSpacing.sm,
            right: VioSpacing.sm,
            child: CanvasSyncStatusIndicator(
              syncStatus: canvasState.syncStatus,
              syncError: canvasState.syncError,
            ),
          ),
          if (editingTextShapeId != null)
            CanvasTextEditorOverlay(
              shapeId: editingTextShapeId!,
              controller: textController,
              focusNode: textFocusNode,
              canvasState: canvasState,
            ),
        ],
      );
        },
      ),
    );
  }
}
