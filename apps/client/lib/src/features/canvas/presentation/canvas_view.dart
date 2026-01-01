import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../workspace/bloc/workspace_bloc.dart';
import '../bloc/canvas_bloc.dart';
import 'painters/canvas_painter.dart';
import 'painters/grid_painter.dart';
import 'painters/ruler_painter.dart';
import 'painters/selection_box_painter.dart';
import 'painters/size_indicator_painter.dart';
import 'painters/snap_guides_painter.dart';

/// Main canvas view with infinite pan/zoom capability
class CanvasView extends StatefulWidget {
  const CanvasView({super.key});

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  bool _isSpacePressed = false;
  bool _isPanning = false;
  Offset? _lastPanPosition;
  double _lastScale = 1.0;

  /// Timestamp of last pointer move event (for throttling during drag)
  int _lastMoveTimestamp = 0;

  /// Throttle interval in milliseconds (~60fps)
  static const int _throttleMs = 16;

  @override
  Widget build(BuildContext context) {
    // Use CanvasBloc provided from parent (VioApp)
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleRawKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize canvas with size
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<CanvasBloc>().add(
                  CanvasInitialized(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                );
          });
          return BlocBuilder<CanvasBloc, CanvasState>(
            builder: (context, canvasState) {
              return BlocBuilder<WorkspaceBloc, WorkspaceState>(
                buildWhen: (prev, curr) =>
                    prev.showGrid != curr.showGrid ||
                    prev.showRulers != curr.showRulers ||
                    prev.gridSize != curr.gridSize ||
                    prev.activeTool != curr.activeTool,
                builder: (context, workspaceState) {
                  return MouseRegion(
                    cursor: _getCursor(workspaceState.activeTool),
                    onHover: (event) =>
                        _handlePointerHover(context, event, workspaceState),
                    onExit: (_) => _handlePointerExit(context),
                    child: Listener(
                      onPointerDown: (event) =>
                          _handlePointerDown(context, event, workspaceState),
                      onPointerMove: (event) =>
                          _handlePointerMove(context, event, workspaceState),
                      onPointerUp: (event) => _handlePointerUp(context, event),
                      onPointerSignal: (event) =>
                          _handlePointerSignal(context, event),
                      onPointerPanZoomStart: (event) {
                        // Trackpad pan/zoom gesture started
                        _lastScale = 1.0;
                      },
                      onPointerPanZoomUpdate: (event) {
                        // Handle trackpad pan and zoom
                        if (event.scale != 1.0) {
                          // Pinch zoom on trackpad
                          // When zooming, do NOT apply panDelta separately
                          // The focal point zoom already handles keeping the
                          // focal point stationary
                          final scaleChange = event.scale / _lastScale;
                          _lastScale = event.scale;
                          context.read<CanvasBloc>().add(
                                ViewportZoomed(
                                  scaleFactor: scaleChange,
                                  focalX: event.localPosition.dx,
                                  focalY: event.localPosition.dy,
                                ),
                              );
                        } else if (event.panDelta != Offset.zero) {
                          // Only pan when NOT zooming
                          // This prevents the pan from interfering with
                          // zoom focal point calculations
                          context.read<CanvasBloc>().add(
                                ViewportPanned(
                                  deltaX: event.panDelta.dx,
                                  deltaY: event.panDelta.dy,
                                ),
                              );
                        }
                      },
                      onPointerPanZoomEnd: (event) {
                        _lastScale = 1.0;
                      },
                      child: ClipRect(
                        child: Stack(
                          children: [
                            // Background
                            Positioned.fill(
                              child: Container(
                                color: VioColors.canvasBackground,
                              ),
                            ),

                            // Grid layer
                            if (workspaceState.showGrid)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GridPainter(
                                    gridSize: workspaceState.gridSize,
                                    zoom: canvasState.zoom,
                                    offset: Offset(
                                      canvasState.viewportOffset.x,
                                      canvasState.viewportOffset.y,
                                    ),
                                  ),
                                ),
                              ),

                            // Canvas content layer
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CanvasPainter(
                                  viewMatrix: canvasState.viewMatrix,
                                  shapes: canvasState.shapeList,
                                  dragRect: canvasState.dragRect,
                                  dragOffset: canvasState.dragOffset,
                                  selectedShapeIds:
                                      canvasState.selectedShapeIds,
                                  hoveredShapeId: canvasState.hoveredShapeId,
                                  hoveredLayerId: canvasState.hoveredLayerId,
                                ),
                              ),
                            ),

                            // Selection box layer
                            if (canvasState.hasSelection)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SelectionBoxPainter(
                                    selectedShapes: canvasState.selectedShapes,
                                    viewMatrix: canvasState.viewMatrix,
                                    dragOffset: canvasState.dragOffset,
                                  ),
                                ),
                              ),

                            // Snap guides layer
                            if (canvasState.snapLines.isNotEmpty ||
                                canvasState.snapPoints.isNotEmpty)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SnapGuidesPainter(
                                    snapLines: canvasState.snapLines,
                                    snapPoints: canvasState.snapPoints,
                                    viewMatrix: canvasState.viewMatrix,
                                    zoom: canvasState.zoom,
                                  ),
                                ),
                              ),

                            // Size indicator layer
                            if (canvasState.hasSelection &&
                                canvasState.selectionRect != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SizeIndicatorPainter(
                                    selectionRect: canvasState.selectionRect,
                                    viewMatrix: canvasState.viewMatrix,
                                    zoom: canvasState.zoom,
                                  ),
                                ),
                              ),

                            // Rulers
                            if (workspaceState.showRulers) ...[
                              // Horizontal ruler
                              Positioned(
                                top: 0,
                                left: 20,
                                right: 0,
                                height: 20,
                                child: CustomPaint(
                                  painter: HorizontalRulerPainter(
                                    offset: canvasState.viewportOffset.x,
                                    zoom: canvasState.zoom,
                                    selectionRect: canvasState.selectionRect,
                                  ),
                                ),
                              ),
                              // Vertical ruler
                              Positioned(
                                top: 20,
                                left: 0,
                                bottom: 0,
                                width: 20,
                                child: CustomPaint(
                                  painter: VerticalRulerPainter(
                                    offset: canvasState.viewportOffset.y,
                                    zoom: canvasState.zoom,
                                    selectionRect: canvasState.selectionRect,
                                  ),
                                ),
                              ),
                              // Corner
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

                            // Coordinates display
                            Positioned(
                              bottom: VioSpacing.sm,
                              left: VioSpacing.sm,
                              child: _CoordinatesDisplay(
                                pointer: canvasState.currentPointer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _handleRawKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() => _isSpacePressed = true);
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() {
          _isSpacePressed = false;
          _isPanning = false;
        });
      }
    }
  }

  MouseCursor _getCursor(CanvasTool tool) {
    if (_isSpacePressed || _isPanning) {
      return SystemMouseCursors.grab;
    }

    return switch (tool) {
      CanvasTool.select => SystemMouseCursors.basic,
      CanvasTool.directSelect => SystemMouseCursors.basic,
      CanvasTool.rectangle => SystemMouseCursors.precise,
      CanvasTool.ellipse => SystemMouseCursors.precise,
      CanvasTool.path => SystemMouseCursors.precise,
      CanvasTool.text => SystemMouseCursors.text,
      CanvasTool.frame => SystemMouseCursors.precise,
      CanvasTool.hand => SystemMouseCursors.grab,
      CanvasTool.zoom => SystemMouseCursors.zoomIn,
      CanvasTool.comment => SystemMouseCursors.basic,
    };
  }

  void _handlePointerDown(
    BuildContext context,
    PointerDownEvent event,
    WorkspaceState workspaceState,
  ) {
    // Middle mouse button or space+left click = pan
    if (event.buttons == kMiddleMouseButton ||
        (_isSpacePressed && event.buttons == kPrimaryButton) ||
        workspaceState.activeTool == CanvasTool.hand) {
      setState(() {
        _isPanning = true;
        _lastPanPosition = event.localPosition;
      });
      return;
    }

    context.read<CanvasBloc>().add(
          PointerDown(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
            button: event.buttons,
            shiftPressed: HardwareKeyboard.instance.isShiftPressed,
          ),
        );
  }

  void _handlePointerMove(
    BuildContext context,
    PointerMoveEvent event,
    WorkspaceState workspaceState,
  ) {
    // Handle panning
    if (_isPanning && _lastPanPosition != null) {
      final delta = event.localPosition - _lastPanPosition!;
      context.read<CanvasBloc>().add(
            ViewportPanned(
              deltaX: delta.dx,
              deltaY: delta.dy,
            ),
          );
      _lastPanPosition = event.localPosition;
      return;
    }

    // Throttle pointer move events during shape dragging for better performance
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMoveTimestamp < _throttleMs) {
      return; // Skip this event
    }
    _lastMoveTimestamp = now;

    context.read<CanvasBloc>().add(
          PointerMove(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
          ),
        );
  }

  void _handlePointerUp(BuildContext context, PointerUpEvent event) {
    if (_isPanning) {
      setState(() {
        _isPanning = false;
        _lastPanPosition = null;
      });
      return;
    }

    context.read<CanvasBloc>().add(
          PointerUp(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
          ),
        );
  }

  void _handlePointerHover(
    BuildContext context,
    PointerHoverEvent event,
    WorkspaceState workspaceState,
  ) {
    // Send hover event for hit testing (shape hover detection)
    context.read<CanvasBloc>().add(
          PointerMove(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
          ),
        );
  }

  void _handlePointerExit(BuildContext context) {
    // Clear hovered shape when mouse leaves canvas
    context.read<CanvasBloc>().add(const CanvasPointerExited());
  }

  void _handlePointerSignal(BuildContext context, PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Check if this is a zoom gesture (Ctrl+scroll or trackpad pinch)
      // On web, trackpad pinch zoom comes as scroll events with ctrlKey
      final isZoomGesture = HardwareKeyboard.instance.isControlPressed;

      if (isZoomGesture) {
        // Zoom towards mouse position
        // Use exponential scaling for smoother zoom
        // scrollDelta.dy is typically ~100 per wheel notch
        const zoomSensitivity = 0.002;
        final scaleFactor = 1.0 - (event.scrollDelta.dy * zoomSensitivity);

        // Clamp scale factor to reasonable range
        final clampedScale = scaleFactor.clamp(0.5, 2.0);

        context.read<CanvasBloc>().add(
              ViewportZoomed(
                scaleFactor: clampedScale,
                focalX: event.localPosition.dx,
                focalY: event.localPosition.dy,
              ),
            );
      } else {
        // Regular scroll/pan - trackpad two-finger scroll or mouse wheel
        context.read<CanvasBloc>().add(
              ViewportPanned(
                deltaX: -event.scrollDelta.dx,
                deltaY: -event.scrollDelta.dy,
              ),
            );
      }
    } else if (event is PointerScaleEvent) {
      // Direct scale event (some platforms send this for pinch)
      context.read<CanvasBloc>().add(
            ViewportZoomed(
              scaleFactor: event.scale,
              focalX: event.localPosition.dx,
              focalY: event.localPosition.dy,
            ),
          );
    }
  }
}

/// Coordinates display widget
class _CoordinatesDisplay extends StatelessWidget {
  const _CoordinatesDisplay({
    required this.pointer,
  });

  final dynamic pointer;

  @override
  Widget build(BuildContext context) {
    if (pointer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VioSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: VioColors.surface2.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
      ),
      child: Text(
        'X: ${pointer.x.toStringAsFixed(0)}  Y: ${pointer.y.toStringAsFixed(0)}',
        style: VioTypography.caption.copyWith(
          color: VioColors.textSecondary,
          fontFamily: 'monospace',
          fontSize: 10,
        ),
      ),
    );
  }
}
