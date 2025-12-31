import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../workspace/bloc/workspace_bloc.dart';
import '../bloc/canvas_bloc.dart';
import 'painters/canvas_painter.dart';
import 'painters/grid_painter.dart';

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
                    child: GestureDetector(
                      // Trackpad pinch-to-zoom
                      onScaleStart: (details) {
                        _lastScale = 1.0;
                      },
                      onScaleUpdate: (details) {
                        if (details.pointerCount >= 2) {
                          // Pinch zoom
                          final scaleChange = details.scale / _lastScale;
                          _lastScale = details.scale;
                          context.read<CanvasBloc>().add(
                                ViewportZoomed(
                                  scaleFactor: scaleChange,
                                  focalX: details.localFocalPoint.dx,
                                  focalY: details.localFocalPoint.dy,
                                ),
                              );
                        }
                      },
                      onScaleEnd: (details) {
                        _lastScale = 1.0;
                      },
                      child: Listener(
                        onPointerDown: (event) =>
                            _handlePointerDown(context, event, workspaceState),
                        onPointerMove: (event) =>
                            _handlePointerMove(context, event, workspaceState),
                        onPointerUp: (event) =>
                            _handlePointerUp(context, event),
                        onPointerSignal: (event) =>
                            _handlePointerSignal(context, event),
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
                                    dragRect: canvasState.dragRect,
                                    selectedShapeIds:
                                        canvasState.selectedShapeIds,
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
                                  child: _HorizontalRuler(
                                    offset: canvasState.viewportOffset.x,
                                    zoom: canvasState.zoom,
                                  ),
                                ),
                                // Vertical ruler
                                Positioned(
                                  top: 20,
                                  left: 0,
                                  bottom: 0,
                                  width: 20,
                                  child: _VerticalRuler(
                                    offset: canvasState.viewportOffset.y,
                                    zoom: canvasState.zoom,
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

/// Horizontal ruler widget
class _HorizontalRuler extends StatelessWidget {
  const _HorizontalRuler({
    required this.offset,
    required this.zoom,
  });

  final double offset;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HorizontalRulerPainter(
        offset: offset,
        zoom: zoom,
      ),
    );
  }
}

class _HorizontalRulerPainter extends CustomPainter {
  _HorizontalRulerPainter({
    required this.offset,
    required this.zoom,
  });

  final double offset;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VioColors.surface2
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Tick marks
    final tickPaint = Paint()
      ..color = VioColors.textTertiary
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate tick interval based on zoom
    double interval = 100;
    if (zoom < 0.25) {
      interval = 400;
    } else if (zoom < 0.5) {
      interval = 200;
    } else if (zoom > 2) {
      interval = 50;
    } else if (zoom > 4) {
      interval = 25;
    }

    final scaledInterval = interval * zoom;
    final startValue = (-offset / zoom / interval).floor() * interval;
    final startX = startValue * zoom + offset;

    for (double x = startX; x < size.width; x += scaledInterval) {
      final value = ((x - offset) / zoom).round();

      // Major tick
      canvas.drawLine(
        Offset(x, size.height - 8),
        Offset(x, size.height),
        tickPaint,
      );

      // Label
      textPainter.text = TextSpan(
        text: value.toString(),
        style: VioTypography.caption.copyWith(
          color: VioColors.textTertiary,
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 2, 2));

      // Minor ticks
      for (int i = 1; i < 10; i++) {
        final minorX = x + (scaledInterval / 10) * i;
        if (minorX < size.width) {
          canvas.drawLine(
            Offset(minorX, size.height - (i == 5 ? 5 : 3)),
            Offset(minorX, size.height),
            tickPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HorizontalRulerPainter oldDelegate) {
    return offset != oldDelegate.offset || zoom != oldDelegate.zoom;
  }
}

/// Vertical ruler widget
class _VerticalRuler extends StatelessWidget {
  const _VerticalRuler({
    required this.offset,
    required this.zoom,
  });

  final double offset;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalRulerPainter(
        offset: offset,
        zoom: zoom,
      ),
    );
  }
}

class _VerticalRulerPainter extends CustomPainter {
  _VerticalRulerPainter({
    required this.offset,
    required this.zoom,
  });

  final double offset;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VioColors.surface2
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Tick marks
    final tickPaint = Paint()
      ..color = VioColors.textTertiary
      ..strokeWidth = 1;

    // Calculate tick interval based on zoom
    double interval = 100;
    if (zoom < 0.25) {
      interval = 400;
    } else if (zoom < 0.5) {
      interval = 200;
    } else if (zoom > 2) {
      interval = 50;
    } else if (zoom > 4) {
      interval = 25;
    }

    final scaledInterval = interval * zoom;
    final startValue = (-offset / zoom / interval).floor() * interval;
    final startY = startValue * zoom + offset;

    for (double y = startY; y < size.height; y += scaledInterval) {
      final value = ((y - offset) / zoom).round();

      // Major tick
      canvas.drawLine(
        Offset(size.width - 8, y),
        Offset(size.width, y),
        tickPaint,
      );

      // Label (rotated)
      canvas.save();
      canvas.translate(3, y + 2);
      canvas.rotate(-1.5708); // -90 degrees

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toString(),
          style: VioTypography.caption.copyWith(
            color: VioColors.textTertiary,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();

      // Minor ticks
      for (int i = 1; i < 10; i++) {
        final minorY = y + (scaledInterval / 10) * i;
        if (minorY < size.height) {
          canvas.drawLine(
            Offset(size.width - (i == 5 ? 5 : 3), minorY),
            Offset(size.width, minorY),
            tickPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_VerticalRulerPainter oldDelegate) {
    return offset != oldDelegate.offset || zoom != oldDelegate.zoom;
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
