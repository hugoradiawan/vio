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

import 'canvas_status_widgets.dart';
import 'canvas_text_editor_overlay.dart';

class CanvasSurface extends StatelessWidget {
  const CanvasSurface({
    required this.canvasState,
    required this.workspaceState,
    required this.orderedShapes,
    required this.selectionRect,
    required this.editingTextShapeId,
    required this.textController,
    required this.textFocusNode,
    super.key,
  });

  final CanvasState canvasState;
  final WorkspaceState workspaceState;
  final List<Shape> orderedShapes;
  final Rect? selectionRect;
  final String? editingTextShapeId;
  final TextEditingController textController;
  final FocusNode textFocusNode;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: VioColors.canvasBackground,
            ),
          ),
          if (workspaceState.showGrid)
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
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: true,
                painter: CanvasPainter(
                  viewMatrix: canvasState.viewMatrix,
                  shapes: orderedShapes,
                  dragRect: canvasState.dragRect,
                  dragOffset: canvasState.dragOffset,
                  selectedShapeIds: canvasState.selectedShapeIds,
                  hoveredShapeId: canvasState.hoveredShapeId,
                  hoveredLayerId: canvasState.hoveredLayerId,
                  editingTextShapeId: editingTextShapeId,
                ),
              ),
            ),
          ),
          if (canvasState.hasSelection)
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
          if (canvasState.snapLines.isNotEmpty ||
              canvasState.snapPoints.isNotEmpty)
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
          if (canvasState.hasSelection && selectionRect != null)
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
          if (workspaceState.showRulers) ...[
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
      ),
    );
  }
}
