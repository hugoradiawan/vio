import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../core/core.dart';
import '../../workspace/bloc/workspace_bloc.dart';
import '../bloc/canvas_bloc.dart';
import '../models/frame_presets.dart';
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

  // Double-click tracking (for text edit activation)
  int _lastPrimaryClickMs = 0;
  Offset? _lastPrimaryClickPosition;
  String? _lastPrimaryClickShapeId;

  static const int _doubleClickThresholdMs = 350;
  static const double _doubleClickMaxDistancePx = 6.0;

  String? _editingTextShapeId;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  Timer? _textLayoutDebounce;
  double? _lastSentTextWidth;
  double? _lastSentTextHeight;

  /// When we explicitly commit/cancel an edit and then unfocus the field,
  /// the FocusNode listener would otherwise fire and enqueue a second
  /// commit (which can turn into a cancel after the shape is removed).
  String? _suppressBlurCommitForShapeId;

  /// Timestamp of last pointer move event (for throttling during drag)
  int _lastMoveTimestamp = 0;

  /// Throttle interval in milliseconds (~60fps)
  static const int _throttleMs = 16;

  @override
  void initState() {
    super.initState();
    // Register global keyboard handler for shortcuts
    HardwareKeyboard.instance.addHandler(_handleKeyboardEvent);

    _textController.addListener(_onTextControllerChanged);

    _textFocusNode.addListener(() {
      final id = _editingTextShapeId;
      if (!_textFocusNode.hasFocus && id != null) {
        if (_suppressBlurCommitForShapeId == id) {
          _suppressBlurCommitForShapeId = null;
          return;
        }
        _commitTextEdit(shapeId: id);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboardEvent);

    _textLayoutDebounce?.cancel();
    _textController.removeListener(_onTextControllerChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _onTextControllerChanged() {
    final shapeId = _editingTextShapeId;
    if (shapeId == null) {
      return;
    }

    // Debounce to avoid spamming bloc with events for every keystroke.
    _textLayoutDebounce?.cancel();
    _textLayoutDebounce = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;

      final bloc = context.read<CanvasBloc>();
      final shape = bloc.state.shapes[shapeId];
      if (shape is! TextShape) return;

      final (measuredWidth, measuredHeight) =
          _measureText(_textController.text, shape);

      // Keep a minimum editor size (Penpot-like default).
      final width = math.max(200.0, measuredWidth);
      final height = math.max(24.0, measuredHeight);

      // Tiny threshold to reduce no-op updates.
      const eps = 0.5;
      if (_lastSentTextWidth != null &&
          _lastSentTextHeight != null &&
          (width - _lastSentTextWidth!).abs() < eps &&
          (height - _lastSentTextHeight!).abs() < eps) {
        return;
      }

      _lastSentTextWidth = width;
      _lastSentTextHeight = height;

      bloc.add(
        TextEditLayoutChanged(
          shapeId: shapeId,
          width: width,
          height: height,
        ),
      );
    });
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
        // Space is used for temporary pan mode, but must not override typing
        // spaces inside the inline text editor.
        if (isTextFieldFocused || _editingTextShapeId != null) {
          return false;
        }

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
            // Escape: Cancel text edit (if editing), otherwise clear selection
            if (isTextFieldFocused && _editingTextShapeId != null) {
              _cancelTextEdit();
              return true;
            }
            context.read<CanvasBloc>().add(const SelectionCleared());
            return true;
          default:
            break;
        }
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        // Don't interfere with text input. If we didn't capture the key-down,
        // we also shouldn't capture the key-up.
        if (isTextFieldFocused || _editingTextShapeId != null) {
          return false;
        }

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
                return MultiBlocListener(
                  listeners: [
                    BlocListener<CanvasBloc, CanvasState>(
                      listenWhen: (prev, curr) =>
                          prev.interactionMode == InteractionMode.drawing &&
                          curr.interactionMode != InteractionMode.drawing,
                      listener: (context, canvasState) {
                        final tool =
                            context.read<WorkspaceBloc>().state.activeTool;
                        final isBoxTool = tool == CanvasTool.rectangle ||
                            tool == CanvasTool.ellipse ||
                            tool == CanvasTool.frame;

                        if (isBoxTool) {
                          context
                              .read<WorkspaceBloc>()
                              .add(const ToolSelected(CanvasTool.select));
                        }
                      },
                    ),
                    BlocListener<CanvasBloc, CanvasState>(
                      listenWhen: (prev, curr) =>
                          prev.editingTextShapeId != curr.editingTextShapeId,
                      listener: (context, canvasState) {
                        final id = canvasState.editingTextShapeId;
                        setState(() {
                          _editingTextShapeId = id;
                        });

                        _lastSentTextWidth = null;
                        _lastSentTextHeight = null;

                        if (id == null) {
                          return;
                        }

                        // After creating a new text element, immediately switch
                        // back to Select (Penpot-like behavior). Only do this
                        // for draft text shapes so editing existing text doesn't
                        // unexpectedly change tools.
                        if (canvasState.draftTextShapeIds.contains(id)) {
                          final workspaceBloc = context.read<WorkspaceBloc>();
                          if (workspaceBloc.state.activeTool ==
                              CanvasTool.text) {
                            workspaceBloc.add(
                              const ToolSelected(CanvasTool.select),
                            );
                          }
                        }

                        final shape = canvasState.shapes[id];
                        if (shape is! TextShape) {
                          return;
                        }

                        _textController.text = shape.text;
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _textFocusNode.requestFocus();
                          }
                        });

                        // If this is a Google font, it may load async and change
                        // metrics after we've measured. Trigger a relayout once
                        // the font is ready so text never overflows the box.
                        _relayoutEditingTextAfterFontLoad(
                          shapeId: id,
                          shape: shape,
                        );
                      },
                    ),
                  ],
                  child: MouseRegion(
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
                                  selectedShapeIds:
                                      canvasState.selectedShapeIds,
                                  hoveredShapeId: canvasState.hoveredShapeId,
                                  hoveredLayerId: canvasState.hoveredLayerId,
                                  editingTextShapeId: _editingTextShapeId,
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
                                        canvasState.selectedShapes.length ==
                                                1 &&
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

                            // Inline text editor overlay
                            if (_editingTextShapeId != null)
                              _TextEditorOverlay(
                                shapeId: _editingTextShapeId!,
                                controller: _textController,
                                focusNode: _textFocusNode,
                                canvasState: canvasState,
                              ),
                          ],
                        ),
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
      CanvasTool.zoom => SystemMouseCursors.basic,
      CanvasTool.comment => SystemMouseCursors.basic,
    };
  }

  void _handlePointerDown(
    BuildContext context,
    PointerDownEvent event,
    WorkspaceState workspaceState,
  ) {
    // If we are editing text and the user clicks outside the editor, commit
    // the current edit BEFORE forwarding this pointer down.
    // Otherwise, the focus-loss commit can run after a new text draft is
    // created and accidentally commit the wrong shape ID.
    final editingId = _editingTextShapeId;
    if (editingId != null) {
      final canvasState = context.read<CanvasBloc>().state;
      final shape = canvasState.shapes[editingId];
      if (shape is TextShape) {
        final editorRect = _getTextEditorScreenRect(shape, canvasState);
        if (editorRect.contains(event.localPosition)) {
          // Click is inside the text editor; don't forward to canvas.
          return;
        }
      }

      _commitTextEdit(shapeId: editingId);

      // We'll unfocus to allow pointer interaction, but suppress the blur
      // listener from enqueuing a duplicate commit.
      _suppressBlurCommitForShapeId = editingId;
      _textFocusNode.unfocus();
    }

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

    // Double click on text to edit (Select/DirectSelect tools).
    if (event.buttons == kPrimaryButton &&
        (workspaceState.activeTool == CanvasTool.select ||
            workspaceState.activeTool == CanvasTool.directSelect)) {
      final canvasState = context.read<CanvasBloc>().state;
      final canvasPoint = canvasState.screenToCanvas(
        Size(event.localPosition.dx, event.localPosition.dy),
      );
      final hitShape = HitTest.findTopShapeAtPoint(
        canvasPoint,
        canvasState.shapeList,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final withinTime =
          (nowMs - _lastPrimaryClickMs) <= _doubleClickThresholdMs;
      final withinDistance = _lastPrimaryClickPosition == null
          ? false
          : (event.localPosition - _lastPrimaryClickPosition!).distance <=
              _doubleClickMaxDistancePx;
      final sameShape = hitShape != null &&
          hitShape.id == _lastPrimaryClickShapeId &&
          hitShape is TextShape;

      if (withinTime && withinDistance && sameShape) {
        context.read<CanvasBloc>().add(TextEditRequested(shapeId: hitShape.id));

        // Reset click tracking to avoid triple-click oddities.
        _lastPrimaryClickMs = 0;
        _lastPrimaryClickPosition = null;
        _lastPrimaryClickShapeId = null;
        return;
      }

      _lastPrimaryClickMs = nowMs;
      _lastPrimaryClickPosition = event.localPosition;
      _lastPrimaryClickShapeId = hitShape?.id;
    }

    final tool = switch (workspaceState.activeTool) {
      CanvasTool.rectangle => CanvasPointerTool.drawRectangle,
      CanvasTool.ellipse => CanvasPointerTool.drawEllipse,
      CanvasTool.frame => CanvasPointerTool.drawFrame,
      CanvasTool.text => CanvasPointerTool.drawText,
      _ => CanvasPointerTool.select,
    };

    final preset = tool == CanvasPointerTool.drawFrame
        ? framePresetById(workspaceState.frameToolPresetId)
        : null;

    context.read<CanvasBloc>().add(
          PointerDown(
            x: event.localPosition.dx,
            y: event.localPosition.dy,
            button: event.buttons,
            shiftPressed: HardwareKeyboard.instance.isShiftPressed,
            tool: tool,
            initialWidth: preset?.width,
            initialHeight: preset?.height,
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
            shiftPressed: HardwareKeyboard.instance.isShiftPressed,
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
      final isShiftScroll = HardwareKeyboard.instance.isShiftPressed;

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
        // Regular scroll/pan - trackpad two-finger scroll or mouse wheel.
        // Shift + mouse wheel pans horizontally (common design-tool behavior).
        final deltaX = isShiftScroll
            ? -(event.scrollDelta.dx != 0
                ? event.scrollDelta.dx
                : event.scrollDelta.dy)
            : -event.scrollDelta.dx;
        final deltaY = isShiftScroll ? 0.0 : -event.scrollDelta.dy;

        context.read<CanvasBloc>().add(
              ViewportPanned(
                deltaX: deltaX,
                deltaY: deltaY,
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

  void _commitTextEdit({String? shapeId}) {
    shapeId ??= _editingTextShapeId;
    if (shapeId == null) return;

    final bloc = context.read<CanvasBloc>();
    final shape = bloc.state.shapes[shapeId];
    if (shape is! TextShape) {
      bloc.add(TextEditCanceled(shapeId: shapeId));
      return;
    }

    final text = _textController.text;
    final (width, height) = _measureText(text, shape);

    bloc.add(
      TextEditCommitted(
        shapeId: shapeId,
        text: text,
        width: width,
        height: height,
      ),
    );
  }

  Rect _getTextEditorScreenRect(TextShape shape, CanvasState canvasState) {
    final bounds = shape.bounds;
    final anchorCanvas = shape.transformPoint(bounds.topLeft);
    final anchorScreen = canvasState.canvasToScreen(anchorCanvas);

    final canvasWidth = bounds.width <= 1 ? 200.0 : bounds.width;
    final canvasHeight = bounds.height <= 1 ? 24.0 : bounds.height;

    final screenWidth = canvasWidth * canvasState.zoom;
    final screenHeight = canvasHeight * canvasState.zoom;

    return Rect.fromLTWH(
      anchorScreen.dx,
      anchorScreen.dy,
      screenWidth,
      screenHeight,
    );
  }

  void _cancelTextEdit() {
    final shapeId = _editingTextShapeId;
    if (shapeId == null) return;

    // Suppress blur-commit when we cancel and lose focus.
    _suppressBlurCommitForShapeId = shapeId;
    _textFocusNode.unfocus();
    context.read<CanvasBloc>().add(TextEditCanceled(shapeId: shapeId));
  }

  (double, double) _measureText(String text, TextShape shape) {
    if (text.trim().isEmpty) {
      return (1, 1);
    }

    FontWeight? fontWeight;
    final weightValue = shape.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final letterSpacing = shape.letterSpacingPercent == 0
        ? null
        : shape.fontSize * (shape.letterSpacingPercent / 100.0);

    final baseStyle = TextStyle(
      fontSize: shape.fontSize,
      fontWeight: fontWeight,
      height: shape.lineHeight,
      letterSpacing: letterSpacing,
    );

    TextStyle resolveFontStyle() {
      final family = shape.fontFamily;
      if (family == null || family.isEmpty) {
        return baseStyle;
      }
      try {
        return GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return baseStyle.copyWith(fontFamily: family);
      }
    }

    final wrapWidth = (shape.textWidth <= 1 ? 200.0 : shape.textWidth)
        .clamp(1.0, double.infinity);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: resolveFontStyle(),
      ),
      textAlign: shape.textAlign,
      textDirection: TextDirection.ltr,
    )..layout(
        // Keep committed bounds consistent with what the editor shows.
        // Force the paragraph width to the current text box width so
        // center/right alignment is computed within the box.
        minWidth: wrapWidth,
        maxWidth: wrapWidth,
      );

    // Keep width stable (the text box width). Only compute the needed height.
    // Add a small padding so caret isn't clipped.
    final height = (painter.height + 2).clamp(1.0, double.infinity);
    return (wrapWidth, height);
  }

  void _relayoutEditingTextAfterFontLoad({
    required String shapeId,
    required TextShape shape,
  }) {
    final family = shape.fontFamily;
    if (family == null || family.isEmpty) return;

    final text = _textController.text;
    if (text.trim().isEmpty) return;

    Future<void>(() async {
      FontWeight? fontWeight;
      final weightValue = shape.fontWeight;
      if (weightValue != null) {
        fontWeight = FontWeight.values.firstWhere(
          (w) => w.value == weightValue,
          orElse: () => FontWeight.w400,
        );
      }

      final letterSpacing = shape.letterSpacingPercent == 0
          ? null
          : shape.fontSize * (shape.letterSpacingPercent / 100.0);

      final baseStyle = TextStyle(
        fontSize: shape.fontSize,
        fontWeight: fontWeight,
        height: shape.lineHeight,
        letterSpacing: letterSpacing,
      );

      TextStyle resolvedStyle;
      try {
        resolvedStyle = GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return;
      }

      try {
        await GoogleFonts.pendingFonts([resolvedStyle]);
      } catch (_) {
        return;
      }

      if (!mounted) return;
      if (_editingTextShapeId != shapeId) return;

      final bloc = context.read<CanvasBloc>();
      final latest = bloc.state.shapes[shapeId];
      if (latest is! TextShape) return;

      final (measuredWidth, measuredHeight) =
          _measureText(_textController.text, latest);
      final width = math.max(200.0, measuredWidth);
      final height = math.max(24.0, measuredHeight);

      bloc.add(
        TextEditLayoutChanged(
          shapeId: shapeId,
          width: width,
          height: height,
        ),
      );
    });
  }
}

class _TextEditorOverlay extends StatelessWidget {
  const _TextEditorOverlay({
    required this.shapeId,
    required this.controller,
    required this.focusNode,
    required this.canvasState,
  });

  final String shapeId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final CanvasState canvasState;

  @override
  Widget build(BuildContext context) {
    final shape = canvasState.shapes[shapeId];
    if (shape is! TextShape) {
      return const SizedBox.shrink();
    }

    // Anchor at transformed top-left of the text bounds.
    final bounds = shape.bounds;
    final anchorCanvas = shape.transformPoint(bounds.topLeft);
    final anchorScreen = canvasState.canvasToScreen(anchorCanvas);

    // Provide a usable editing area even before we measure text.
    // Keep the layout size in screen space to avoid transforming EditableText.
    final canvasWidth = bounds.width <= 1 ? 200.0 : bounds.width;
    final canvasHeight = bounds.height <= 1 ? 24.0 : bounds.height;

    final screenWidth = canvasWidth * canvasState.zoom;
    final screenHeight = canvasHeight * canvasState.zoom;

    final fill = shape.fills.isNotEmpty ? shape.fills.first : null;
    final color = fill != null
        ? Color(fill.color).withValues(alpha: fill.opacity)
        : const Color(0xFFE6EDF3);

    FontWeight? fontWeight;
    final weightValue = shape.fontWeight;
    if (weightValue != null) {
      fontWeight = FontWeight.values.firstWhere(
        (w) => w.value == weightValue,
        orElse: () => FontWeight.w400,
      );
    }

    final scaledFontSize = shape.fontSize * canvasState.zoom;
    final scaledLetterSpacing = shape.letterSpacingPercent == 0
        ? null
        : scaledFontSize * (shape.letterSpacingPercent / 100.0);

    final baseStyle = TextStyle(
      color: color,
      // Match the painted text size under zoom by scaling font size.
      fontSize: scaledFontSize,
      fontWeight: fontWeight,
      height: shape.lineHeight,
      letterSpacing: scaledLetterSpacing,
    );

    TextStyle resolveFontStyle() {
      final family = shape.fontFamily;
      if (family == null || family.isEmpty) {
        return baseStyle;
      }
      try {
        return GoogleFonts.getFont(family, textStyle: baseStyle);
      } catch (_) {
        return baseStyle.copyWith(fontFamily: family);
      }
    }

    return Positioned(
      left: anchorScreen.dx,
      top: anchorScreen.dy,
      child: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: EditableText(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textAlign: shape.textAlign,
          textDirection: TextDirection.ltr,
          style: resolveFontStyle(),
          cursorColor: VioColors.primary,
          backgroundCursorColor: VioColors.background,
          selectionColor: VioColors.primary.withValues(alpha: 0.25),
        ),
      ),
    );
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
