import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:vio_client/src/core/core.dart';
import 'package:vio_client/src/features/assets/bloc/asset_bloc.dart';
import 'package:vio_client/src/features/canvas/bloc/canvas_bloc.dart';
import 'package:vio_client/src/features/canvas/models/frame_presets.dart';
import 'package:vio_client/src/features/workspace/bloc/workspace_bloc.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'canvas_performance_diagnostics.dart';
import 'widgets/canvas_input_layer.dart';
import 'widgets/canvas_surface.dart';

part 'canvas_view_controller.dart';

enum _CanvasContextAction {
  cut,
  copy,
  paste,
  group,
  ungroup,
  bringToFront,
  sendToBack,
}

enum _RulerContextAction {
  hideRulers,
}

/// Main canvas view with infinite pan/zoom capability
class CanvasView extends StatefulWidget {
  const CanvasView({super.key});

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> with _CanvasViewController {
  bool _isSpacePressed = false;
  bool _isPanning = false;
  Offset? _lastPanPosition;
  double _lastScale = 1.0;
  final CanvasPerformanceDiagnostics _perfDiagnostics =
      CanvasPerformanceDiagnostics();

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

  /// Subscription to image cache decode events for triggering repaints.
  StreamSubscription<String>? _imageDecodeSub;

  /// Track which assetIds we've already requested data for.
  final Set<String> _requestedAssetIds = {};

  /// Whether an OS file is being dragged over the canvas.
  bool _isDroppingFile = false;

  /// Last known drag position for OS file drops.
  Offset? _lastOsDragOffset;

  /// True while viewport interactions are active (pan/zoom/wheel) to allow
  /// temporary render simplifications on very large canvases.
  bool _isViewportInteractionActive = false;

  /// Debounce timer used for wheel/trackpad interactions.
  Timer? _viewportInteractionTimer;

  /// Buffered pan delta for high-frequency pointer pan/zoom events.
  Offset _bufferedPanZoomDelta = Offset.zero;

  /// Buffered zoom multiplier for high-frequency pointer pan/zoom events.
  double _bufferedPanZoomScale = 1.0;

  /// Latest focal point for buffered zoom flush.
  Offset _bufferedPanZoomFocal = Offset.zero;

  /// Last flush timestamp for buffered pointer pan/zoom updates.
  int _lastPanZoomFlushTimestamp = 0;

  /// Throttle interval for pointer pan/zoom viewport updates (~60fps).
  static const int _panZoomFlushThrottleMs = 16;

  /// Ignore micro zoom drift from high-frequency pointer events.
  static const double _panZoomScaleDriftEpsilon = 0.0015;

  /// Ignore small pointer-scale drift to avoid accidental zoom from trackpad
  /// scrolling while still allowing intentional pinch zoom.
  static const double _pointerScaleGestureEpsilon = 0.06;

  @override
  void initState() {
    super.initState();

    // On Flutter Web, prevent the browser from showing its own context menu so
    // right-click can be used for the canvas/layers context menu.
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }

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

    // Repaint when a new image finishes decoding
    _imageDecodeSub = ImageCacheService.instance.onImageDecoded.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (kIsWeb) {
      BrowserContextMenu.enableContextMenu();
    }

    HardwareKeyboard.instance.removeHandler(_handleKeyboardEvent);

    _imageDecodeSub?.cancel();
    _textLayoutDebounce?.cancel();
    _viewportInteractionTimer?.cancel();
    _textController.removeListener(_onTextControllerChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    if (_perfDiagnostics.isEnabled) {
      _perfDiagnostics.dispose(lastState: context.read<CanvasBloc>().state);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use CanvasBloc provided from parent (VioApp)
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDroppingFile = true),
      onDragExited: (_) {
        setState(() => _isDroppingFile = false);
        _lastOsDragOffset = null;
      },
      onDragUpdated: (details) {
        _lastOsDragOffset = details.localPosition;
      },
      onDragDone: (details) {
        setState(() => _isDroppingFile = false);
        _handleOsFileDrop(context, details, _lastOsDragOffset);
        _lastOsDragOffset = null;
      },
      child: Stack(
        children: [
          BlocListener<CanvasBloc, CanvasState>(
            listenWhen: (prev, curr) => prev.shapes != curr.shapes,
            listener: _loadImagesForNewShapes,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasBloc = context.read<CanvasBloc>();
                // Initialize canvas with size
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  canvasBloc.add(
                    CanvasInitialized(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    ),
                  );
                });
                return BlocBuilder<CanvasBloc, CanvasState>(
                  buildWhen: (prev, curr) =>
                      // Rendering-affecting changes only — skip rebuilds for
                      // sync status, server version, expanded layers, etc.
                      prev.zoom != curr.zoom ||
                      prev.viewportOffset != curr.viewportOffset ||
                      prev.viewportSize != curr.viewportSize ||
                      prev.interactionMode != curr.interactionMode ||
                      prev.dragStart != curr.dragStart ||
                      prev.currentPointer != curr.currentPointer ||
                      prev.dragOffset != curr.dragOffset ||
                      !identical(prev.shapes, curr.shapes) ||
                      prev.selectedShapeIds != curr.selectedShapeIds ||
                      prev.hoveredShapeId != curr.hoveredShapeId ||
                      prev.hoveredLayerId != curr.hoveredLayerId ||
                      prev.editingTextShapeId != curr.editingTextShapeId ||
                      prev.snapLines != curr.snapLines ||
                      prev.snapPoints != curr.snapPoints ||
                      prev.activeCornerIndex != curr.activeCornerIndex ||
                      prev.hoveredCornerIndex != curr.hoveredCornerIndex ||
                      prev.selectionCursorKind != curr.selectionCursorKind ||
                      prev.syncStatus != curr.syncStatus ||
                      prev.syncError != curr.syncError,
                  builder: (context, canvasState) {
                    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
                      buildWhen: (prev, curr) =>
                          prev.showGrid != curr.showGrid ||
                          prev.showRulers != curr.showRulers ||
                          prev.gridSize != curr.gridSize ||
                          prev.activeTool != curr.activeTool,
                      builder: (context, workspaceState) {
                        final selectionRect = canvasState.selectionRect;
                        final orderedShapes = canvasState.shapeList;

                        return MultiBlocListener(
                          listeners: [
                            BlocListener<CanvasBloc, CanvasState>(
                              listenWhen: (prev, curr) =>
                                  prev.interactionMode ==
                                      InteractionMode.drawing &&
                                  curr.interactionMode !=
                                      InteractionMode.drawing,
                              listener: (context, canvasState) {
                                final tool = context
                                    .read<WorkspaceBloc>()
                                    .state
                                    .activeTool;
                                final isBoxTool =
                                    tool == CanvasTool.rectangle ||
                                        tool == CanvasTool.ellipse ||
                                        tool == CanvasTool.frame;

                                if (isBoxTool) {
                                  context.read<WorkspaceBloc>().add(
                                        const ToolSelected(CanvasTool.select),
                                      );
                                }
                              },
                            ),
                            BlocListener<CanvasBloc, CanvasState>(
                              listenWhen: (prev, curr) =>
                                  prev.editingTextShapeId !=
                                  curr.editingTextShapeId,
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
                                if (canvasState.draftTextShapeIds
                                    .contains(id)) {
                                  final workspaceBloc =
                                      context.read<WorkspaceBloc>();
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
                                _textController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _textController.text.length,
                                  ),
                                );

                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
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
                          child: CanvasInputLayer(
                            cursor: _getCursor(
                              workspaceState.activeTool,
                              canvasState,
                            ),
                            onHover: (event) => _handlePointerHover(
                              context,
                              event,
                              workspaceState,
                            ),
                            onExit: () => _handlePointerExit(context),
                            onPointerDown: (event) => _handlePointerDown(
                              context,
                              event,
                              workspaceState,
                            ),
                            onPointerMove: (event) => _handlePointerMove(
                              context,
                              event,
                              workspaceState,
                            ),
                            onPointerUp: (event) =>
                                _handlePointerUp(context, event),
                            onPointerSignal: (event) =>
                                _handlePointerSignal(context, event),
                            onPointerPanZoomStart: (event) {
                              _lastScale = 1.0;
                              _resetBufferedPanZoom(event.localPosition);
                              _setViewportInteractionActive();
                              _perfDiagnostics.onGestureZoomStart(canvasState);
                            },
                            onPointerPanZoomUpdate: (event) {
                              _setViewportInteractionActive();
                              if (event.scale != 1.0) {
                                final scaleChange = event.scale / _lastScale;
                                _lastScale = event.scale;
                                _perfDiagnostics.onGestureZoomUpdate(
                                  scaleChange,
                                  canvasState,
                                );
                                _bufferPanZoomViewportUpdate(
                                  context,
                                  scaleFactor: scaleChange,
                                  panDelta: Offset.zero,
                                  focalPoint: event.localPosition,
                                );
                              } else if (event.panDelta != Offset.zero) {
                                _perfDiagnostics.onGesturePanUpdate(
                                  event.panDelta,
                                  canvasState,
                                );
                                _perfDiagnostics.onDragPanUpdate(
                                  event.panDelta,
                                  canvasState,
                                );
                                _bufferPanZoomViewportUpdate(
                                  context,
                                  scaleFactor: 1.0,
                                  panDelta: event.panDelta,
                                  focalPoint: event.localPosition,
                                );
                              }
                            },
                            onPointerPanZoomEnd: (event) {
                              _lastScale = 1.0;
                              _flushBufferedPanZoom(context, force: true);
                              _perfDiagnostics.onGestureZoomEnd(canvasState);
                              _setViewportInteractionInactive();
                            },
                            onAssetAccept: (details) {
                              _handleAssetDrop(
                                context,
                                details,
                                canvasState,
                              );
                            },
                            child: CanvasSurface(
                              canvasState: canvasState,
                              workspaceState: workspaceState,
                              orderedShapes: orderedShapes,
                              selectionRect: selectionRect,
                              editingTextShapeId: _editingTextShapeId,
                              textController: _textController,
                              textFocusNode: _textFocusNode,
                              isViewportInteractionActive:
                                  _isViewportInteractionActive,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // OS file drop overlay indicator
          if (_isDroppingFile)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: VioColors.primary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: VioColors.primary,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download,
                          size: 48,
                          color: VioColors.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Drop files to upload',
                          style: TextStyle(
                            color: VioColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
