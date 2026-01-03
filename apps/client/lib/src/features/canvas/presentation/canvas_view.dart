import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../core/core.dart';
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
  void initState() {
    super.initState();
    // Register global keyboard handler for shortcuts
    HardwareKeyboard.instance.addHandler(_handleKeyboardEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboardEvent);
    super.dispose();
  }

  /// Global keyboard event handler for shortcuts (works regardless of focus)
  bool _handleKeyboardEvent(KeyEvent event) {
    // Check if a text field is currently focused - if so, don't intercept
    // delete/backspace keys as they're needed for text editing
    final primaryFocus = FocusManager.instance.primaryFocus;
    final isTextFieldFocused = primaryFocus?.context?.widget is EditableText ||
        primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
            null;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() => _isSpacePressed = true);
        return true;
      }

      // Handle keyboard shortcuts
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isCtrlPressed) {
        final bloc = context.read<CanvasBloc>();

        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyC:
            // Ctrl+C: Copy
            bloc.add(const CopySelected());
            return true;
          case LogicalKeyboardKey.keyX:
            // Ctrl+X: Cut
            bloc.add(const CutSelected());
            return true;
          case LogicalKeyboardKey.keyV:
            // Ctrl+V: Paste
            bloc.add(const PasteShapes());
            return true;
          case LogicalKeyboardKey.keyD:
            // Ctrl+D: Duplicate
            bloc.add(const DuplicateSelected());
            return true;
          case LogicalKeyboardKey.keyZ:
            if (isShiftPressed) {
              // Ctrl+Shift+Z: Redo
              bloc.add(const Redo());
            } else {
              // Ctrl+Z: Undo
              bloc.add(const Undo());
            }
            return true;
          case LogicalKeyboardKey.keyY:
            // Ctrl+Y: Redo (alternative)
            bloc.add(const Redo());
            return true;
          default:
            break;
        }
      } else {
        // Non-Ctrl shortcuts
        switch (event.logicalKey) {
          case LogicalKeyboardKey.delete:
          case LogicalKeyboardKey.backspace:
            // Delete/Backspace: Delete selected (only if not in text field)
            if (!isTextFieldFocused) {
              context.read<CanvasBloc>().add(const DeleteSelected());
              return true;
            }
            return false;
          case LogicalKeyboardKey.escape:
            // Escape: Clear selection
            context.read<CanvasBloc>().add(const SelectionCleared());
            return true;
          default:
            break;
        }
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() {
          _isSpacePressed = false;
          _isPanning = false;
        });
        return true;
      }
    }
    return false; // Allow other handlers to process the event
  }

  @override
  Widget build(BuildContext context) {
    // Use CanvasBloc provided from parent (VioApp)
    return LayoutBuilder(
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
                                    canvasState.viewportOffset.dx,
                                    canvasState.viewportOffset.dy,
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
                                selectedShapeIds: canvasState.selectedShapeIds,
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
                                  showCornerRadiusHandles:
                                      canvasState.selectedShapes.length == 1 &&
                                          canvasState.selectedShapes.first
                                              is RectangleShape,
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
                                  offset: canvasState.viewportOffset.dx,
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
                                  offset: canvasState.viewportOffset.dy,
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

                          // Sync status indicator
                          Positioned(
                            bottom: VioSpacing.sm,
                            right: VioSpacing.sm,
                            child: _SyncStatusIndicator(
                              syncStatus: canvasState.syncStatus,
                              syncError: canvasState.syncError,
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
    );
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

  final Offset? pointer;

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
        'X: ${pointer!.dx.toStringAsFixed(0)}  Y: ${pointer!.dy.toStringAsFixed(0)}',
        style: VioTypography.caption.copyWith(
          color: VioColors.textSecondary,
          fontFamily: 'monospace',
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Sync status indicator widget
class _SyncStatusIndicator extends StatelessWidget {
  const _SyncStatusIndicator({
    required this.syncStatus,
    this.syncError,
  });

  final SyncStatus syncStatus;
  final String? syncError;

  @override
  Widget build(BuildContext context) {
    // Don't show indicator when idle (not connected to server)
    if (syncStatus == SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    final (icon, color, label) = _getStatusInfo();

    return Tooltip(
      message: syncError ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VioSpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: VioColors.surface2.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (syncStatus == SyncStatus.syncing)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: VioTypography.caption.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _getStatusInfo() {
    switch (syncStatus) {
      case SyncStatus.idle:
        return (Icons.cloud_off_outlined, VioColors.textSecondary, 'Offline');
      case SyncStatus.loading:
        return (Icons.cloud_download_outlined, VioColors.primary, 'Loading...');
      case SyncStatus.pending:
        return (Icons.cloud_upload_outlined, VioColors.warning, 'Pending');
      case SyncStatus.syncing:
        return (Icons.cloud_sync_outlined, VioColors.primary, 'Syncing...');
      case SyncStatus.synced:
        return (Icons.cloud_done_outlined, VioColors.success, 'Synced');
      case SyncStatus.error:
        return (Icons.cloud_off_outlined, VioColors.error, 'Sync Error');
    }
  }
}
