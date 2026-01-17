import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import 'shape_painter.dart';

/// Main canvas painter for rendering shapes and selection
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.viewMatrix,
    required this.shapes,
    this.dragRect,
    this.dragOffset,
    this.selectedShapeIds = const [],
    this.hoveredShapeId,
    this.hoveredLayerId,
    this.editingTextShapeId,
  });

  /// Transformation matrix for viewport
  final Matrix2D viewMatrix;

  /// All shapes to render
  final List<Shape> shapes;

  /// Current drag selection rectangle (in canvas coordinates)
  final Rect? dragRect;

  /// Current drag offset for moving shapes (applied at render time)
  final Offset? dragOffset;

  /// IDs of selected shapes
  final List<String> selectedShapeIds;

  /// ID of shape hovered on canvas
  final String? hoveredShapeId;

  /// ID of layer hovered in layers panel
  final String? hoveredLayerId;

  /// ID of the text shape currently being edited (rendered by overlay)
  final String? editingTextShapeId;

  @override
  void paint(Canvas canvas, Size size) {
    // Apply view transformation
    canvas.save();
    canvas.transform(
      Float64List.fromList([
        viewMatrix.a,
        viewMatrix.b,
        0,
        0,
        viewMatrix.c,
        viewMatrix.d,
        0,
        0,
        0,
        0,
        1,
        0,
        viewMatrix.e,
        viewMatrix.f,
        0,
        1,
      ]),
    );

    final isDraggingSelection =
        dragOffset != null && selectedShapeIds.isNotEmpty;
    final selectedIdSet = selectedShapeIds.toSet();

    // Build a simple containment map using existing absolute coordinates.
    // - If a shape has a valid parentId that points to a group, it is rendered
    //   as a child of that group.
    // - Otherwise, if a shape has a valid frameId, it is rendered as a child
    //   of that frame.
    final shapesById = <String, Shape>{for (final s in shapes) s.id: s};
    final childrenByContainerId = <String, List<Shape>>{};
    final rootShapes = <Shape>[];

    for (final shape in shapes) {
      final parentId = shape.parentId;
      final parent = parentId == null ? null : shapesById[parentId];
      if (parentId != null && parent is GroupShape) {
        childrenByContainerId.putIfAbsent(parentId, () => []).add(shape);
        continue;
      }

      final frameId = shape.frameId;
      final frame = frameId == null ? null : shapesById[frameId];
      if (frameId != null && frame is FrameShape) {
        childrenByContainerId.putIfAbsent(frameId, () => []).add(shape);
      } else {
        rootShapes.add(shape);
      }
    }

    // During dragging, if a container (group/frame) is selected, also move its
    // descendants in the drag overlay so children don't appear to detach.
    final dragOverlayIdSet = <String>{...selectedIdSet};
    if (isDraggingSelection) {
      void addDescendants(String containerId) {
        final children = childrenByContainerId[containerId];
        if (children == null) return;
        for (final child in children) {
          if (dragOverlayIdSet.add(child.id)) {
            addDescendants(child.id);
          }
        }
      }

      for (final id in selectedIdSet) {
        final shape = shapesById[id];
        if (shape is GroupShape || shape is FrameShape) {
          addDescendants(id);
        }
      }
    }

    void paintShapeTree(Shape shape) {
      if (isDraggingSelection && dragOverlayIdSet.contains(shape.id)) {
        return;
      }

      // When a text shape is being edited, an overlay EditableText renders it.
      // Skip painting it here to avoid double-rendered (duplicated) text.
      if (shape is! TextShape || shape.id != editingTextShapeId) {
        ShapePainter.paintShape(canvas, shape);
      }

      if (shape is FrameShape) {
        _drawFrameLabel(canvas, shape);
      }

      final children = childrenByContainerId[shape.id];
      if (children == null || children.isEmpty) {
        return;
      }

      if (shape is FrameShape) {
        if (shape.clipContent) {
          canvas.save();
          canvas.clipRect(
            Rect.fromLTWH(
              shape.x,
              shape.y,
              shape.frameWidth,
              shape.frameHeight,
            ),
          );
          for (final child in children) {
            paintShapeTree(child);
          }
          canvas.restore();
        } else {
          for (final child in children) {
            paintShapeTree(child);
          }
        }
      } else if (shape is GroupShape) {
        for (final child in children) {
          paintShapeTree(child);
        }
      }
    }

    // Paint non-dragging scene normally (with clipping).
    for (final shape in rootShapes) {
      paintShapeTree(shape);
    }

    // While dragging, paint the selection on top without clipping so it remains
    // visible when crossing frame boundaries.
    if (isDraggingSelection) {
      canvas.save();
      final overlayOffset = dragOffset!;

      void paintOverlayTree(Shape shape) {
        final isOverlay = dragOverlayIdSet.contains(shape.id);
        if (isOverlay) {
          canvas.save();

          final frameId = shape.frameId;
          final frame = frameId == null ? null : shapesById[frameId];
          final isInClippingFrame = frame is FrameShape && frame.clipContent;
          final isFrameAlsoDragging = frameId != null &&
              dragOverlayIdSet.contains(frameId); // frame moves with overlay

          // If the clip frame is NOT being dragged, keep the clip rect anchored
          // to the frame (untranslated), then translate the shape.
          if (isInClippingFrame && !isFrameAlsoDragging) {
            canvas.clipRect(
              Rect.fromLTWH(
                frame.x,
                frame.y,
                frame.frameWidth,
                frame.frameHeight,
              ),
            );
            canvas.translate(overlayOffset.dx, overlayOffset.dy);
          } else {
            // Otherwise (no clip frame or the frame itself is moving), translate
            // first so the clip (if any) moves along with the frame.
            canvas.translate(overlayOffset.dx, overlayOffset.dy);
            if (isInClippingFrame) {
              canvas.clipRect(
                Rect.fromLTWH(
                  frame.x,
                  frame.y,
                  frame.frameWidth,
                  frame.frameHeight,
                ),
              );
            }
          }

          if (shape is! TextShape || shape.id != editingTextShapeId) {
            ShapePainter.paintShape(canvas, shape);
          }
          if (shape is FrameShape) {
            _drawFrameLabel(canvas, shape);
          }

          canvas.restore();
        }

        final children = childrenByContainerId[shape.id];
        if (children == null || children.isEmpty) {
          return;
        }

        // Apply the same clip rules during drag so objects are clipped instantly
        // when they move outside their frame.
        if (shape is FrameShape && shape.clipContent) {
          canvas.save();
          canvas.clipRect(
            Rect.fromLTWH(
              shape.x,
              shape.y,
              shape.frameWidth,
              shape.frameHeight,
            ),
          );
          for (final child in children) {
            paintOverlayTree(child);
          }
          canvas.restore();
        } else {
          for (final child in children) {
            paintOverlayTree(child);
          }
        }
      }

      for (final shape in rootShapes) {
        paintOverlayTree(shape);
      }

      canvas.restore();
    }

    // Draw hover outline (from canvas or layer panel)
    _drawHoverOutline(canvas);

    // Draw selection outlines for selected shapes
    _drawSelectionOutlines(canvas);

    canvas.restore();

    // Draw selection rectangle (in screen coordinates)
    if (dragRect != null) {
      _drawSelectionRect(canvas, size);
    }
  }

  void _drawSelectionOutlines(Canvas canvas) {
    if (selectedShapeIds.isEmpty) return;

    final shapesById = <String, Shape>{for (final s in shapes) s.id: s};
    final selectedIdSet = selectedShapeIds.toSet();

    final outlinePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final shape in shapes) {
      if (!selectedShapeIds.contains(shape.id)) continue;

      final bounds = shape.bounds;
      final rect = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        bounds.width,
        bounds.height,
      );

      canvas.save();

      if (dragOffset != null) {
        // Match the same clip order as the drag overlay:
        // - If the frame is not moving, clip first, then translate the shape.
        // - If the frame is moving, translate first (clip moves with it).
        final frameId = shape.frameId;
        final frame = frameId == null ? null : shapesById[frameId];
        final isInClippingFrame = frame is FrameShape && frame.clipContent;
        final isFrameAlsoDragging = frameId != null &&
            selectedIdSet.contains(frameId); // frame selected implies dragging

        if (isInClippingFrame && !isFrameAlsoDragging) {
          canvas.clipRect(
            Rect.fromLTWH(
              frame.x,
              frame.y,
              frame.frameWidth,
              frame.frameHeight,
            ),
          );
          canvas.translate(dragOffset!.dx, dragOffset!.dy);
        } else {
          canvas.translate(dragOffset!.dx, dragOffset!.dy);
          if (isInClippingFrame) {
            canvas.clipRect(
              Rect.fromLTWH(
                frame.x,
                frame.y,
                frame.frameWidth,
                frame.frameHeight,
              ),
            );
          }
        }
      }

      // Apply shape transform for outline
      canvas.transform(
        Float64List.fromList([
          shape.transform.a,
          shape.transform.b,
          0,
          0,
          shape.transform.c,
          shape.transform.d,
          0,
          0,
          0,
          0,
          1,
          0,
          shape.transform.e,
          shape.transform.f,
          0,
          1,
        ]),
      );
      canvas.drawRect(rect, outlinePaint);
      canvas.restore();
    }
  }

  void _drawHoverOutline(Canvas canvas) {
    // Get the hovered shape ID (prefer layer hover over canvas hover)
    final hoveredId = hoveredLayerId ?? hoveredShapeId;
    if (hoveredId == null) return;

    // Don't draw hover if already selected
    if (selectedShapeIds.contains(hoveredId)) return;

    final shape = shapes.where((s) => s.id == hoveredId).firstOrNull;
    if (shape == null) return;

    final hoverPaint = Paint()
      ..color = VioColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final bounds = shape.bounds;
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );

    canvas.save();
    canvas.transform(
      Float64List.fromList([
        shape.transform.a,
        shape.transform.b,
        0,
        0,
        shape.transform.c,
        shape.transform.d,
        0,
        0,
        0,
        0,
        1,
        0,
        shape.transform.e,
        shape.transform.f,
        0,
        1,
      ]),
    );
    canvas.drawRect(rect, hoverPaint);
    canvas.restore();
  }

  void _drawSelectionRect(Canvas canvas, Size size) {
    if (dragRect == null) return;

    // Convert drag rect from canvas to screen coordinates
    final topLeft = _canvasToScreen(Offset(dragRect!.left, dragRect!.top));
    final bottomRight =
        _canvasToScreen(Offset(dragRect!.right, dragRect!.bottom));

    final rect = Rect.fromPoints(
      Offset(topLeft.dx, topLeft.dy),
      Offset(bottomRight.dx, bottomRight.dy),
    );

    // Fill
    final fillPaint = Paint()
      ..color = VioColors.canvasSelection.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, strokePaint);
  }

  Offset _canvasToScreen(Offset canvasPoint) {
    final result = viewMatrix.transformPoint(canvasPoint.dx, canvasPoint.dy);
    return Offset(result.x, result.y);
  }

  void _drawFrameLabel(Canvas canvas, FrameShape frame) {
    final bounds = frame.bounds;
    final isSelected = selectedShapeIds.contains(frame.id);

    // Position label above the frame
    const labelHeight = 20.0;
    const labelPadding = 8.0;
    final labelY = bounds.top - labelHeight - 4; // 4px gap

    // Draw label text
    final textStyle = TextStyle(
      color: isSelected ? VioColors.canvasSelection : VioColors.textSecondary,
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    );

    final textSpan = TextSpan(
      text: frame.name,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background if selected
    if (isSelected) {
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bounds.left - 4,
          labelY,
          textPainter.width + labelPadding * 2,
          labelHeight,
        ),
        const Radius.circular(4),
      );
      final bgPaint = Paint()
        ..color = VioColors.canvasSelection.withValues(alpha: 0.15);
      canvas.drawRRect(bgRect, bgPaint);
    }

    // Draw text
    textPainter.paint(
      canvas,
      Offset(bounds.left, labelY + (labelHeight - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    // Fast path: if only dragOffset changed, repaint
    // This is the most frequent change during dragging
    if (dragOffset != oldDelegate.dragOffset) return true;

    // Use identity comparison for shapes (they don't change during drag)
    if (!identical(shapes, oldDelegate.shapes)) return true;

    return viewMatrix != oldDelegate.viewMatrix ||
        dragRect != oldDelegate.dragRect ||
        !listEquals(selectedShapeIds, oldDelegate.selectedShapeIds) ||
        hoveredShapeId != oldDelegate.hoveredShapeId ||
        hoveredLayerId != oldDelegate.hoveredLayerId;
  }
}
