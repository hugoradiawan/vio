import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';

import '../../models/handle_types.dart';
import '../../models/selection_handle_metrics.dart';

export '../../models/handle_types.dart';

/// Paints the selection bounding box with resize and rotation handles
class SelectionBoxPainter extends CustomPainter {
  SelectionBoxPainter({
    required this.selectedShapes,
    required this.viewMatrix,
    required this.selectionColor,
    this.dragOffset,
    this.activeCornerIndex,
    this.hoveredCornerIndex,
    this.handleSize = SelectionHandleMetrics.resizeVisualSize,
    this.rotationHandleOffset = SelectionHandleMetrics.rotationOffset,
    this.cornerRadiusHandleSize = SelectionHandleMetrics.cornerRadiusVisualSize,
    this.showCornerRadiusHandles = false,
  });

  /// The shapes that are selected
  final List<Shape> selectedShapes;

  /// View transformation matrix
  final Matrix2D viewMatrix;

  /// Color for selection outlines, handles, and fill.
  final Color selectionColor;

  /// Current drag offset (applied at render time)
  final Offset? dragOffset;

  /// Active corner index while adjusting radius (0..3), null otherwise.
  final int? activeCornerIndex;

  /// Hovered corner index while pointer is over a radius handle (0..3).
  final int? hoveredCornerIndex;

  /// Size of resize handles
  final double handleSize;

  /// Distance of rotation handle from top edge
  final double rotationHandleOffset;

  /// Size of corner radius handles
  final double cornerRadiusHandleSize;

  /// Whether to show corner radius handles (only for single rectangle selection)
  final bool showCornerRadiusHandles;

  /// Computed handles for hit-testing (in screen coordinates)
  List<HandleInfo> get handles => _computeHandles();

  /// Computed corner radius handles for hit-testing (in screen coordinates)
  List<CornerRadiusHandleInfo> get cornerRadiusHandles =>
      _computeCornerRadiusHandles();

  bool get _isSingleTextSelection =>
      selectedShapes.length == 1 && selectedShapes.first is TextShape;

  bool _isTextHandle(HandlePosition position) {
    return position == HandlePosition.rotation ||
        position == HandlePosition.topLeft ||
        position == HandlePosition.topRight ||
        position == HandlePosition.bottomLeft ||
        position == HandlePosition.bottomRight;
  }

  double get _zoom {
    final zoom = viewMatrix.a.abs();
    return zoom <= 0 ? 1.0 : zoom;
  }

  double _screenToCanvas(double px) {
    return SelectionHandleMetrics.toCanvasUnits(screenPx: px, zoom: _zoom);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedShapes.isEmpty) return;

    // Calculate combined bounding box
    final bounds = _getCombinedBounds();
    if (bounds == null) return;

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

    // Apply drag offset if dragging
    if (dragOffset != null) {
      canvas.translate(dragOffset!.dx, dragOffset!.dy);
    }

    // Draw bounding box
    _drawBoundingBox(canvas, bounds);

    // Draw handles
    _drawHandles(canvas, bounds);

    // Draw corner radius handles for single rectangle
    if (showCornerRadiusHandles && selectedShapes.length == 1) {
      final shape = selectedShapes.first;
      if (shape is RectangleShape) {
        _drawCornerRadiusHandles(canvas, shape);
      }
    }

    canvas.restore();

    // Draw radius info in screen space while hovering/adjusting.
    if (showCornerRadiusHandles &&
        selectedShapes.length == 1 &&
        selectedShapes.first is RectangleShape &&
        (activeCornerIndex != null || hoveredCornerIndex != null)) {
      final index = activeCornerIndex ?? hoveredCornerIndex;
      if (index == null) return;
      _drawCornerRadiusInfoBox(
        canvas,
        selectedShapes.first as RectangleShape,
        index,
      );
    }
  }

  void _drawCornerRadiusInfoBox(
    Canvas canvas,
    RectangleShape rect,
    int cornerIndex,
  ) {
    final positions = _getCornerRadiusHandlePositions(rect);
    if (cornerIndex < 0 || cornerIndex >= positions.length) return;

    final basePos = positions[cornerIndex];
    final withDrag = dragOffset == null
        ? basePos
        : Offset(basePos.dx + dragOffset!.dx, basePos.dy + dragOffset!.dy);

    final screen = viewMatrix.transformPoint(withDrag.dx, withDrag.dy);
    final screenPos = Offset(screen.x, screen.y);

    final radius = switch (cornerIndex) {
      0 => rect.r1,
      1 => rect.r2,
      2 => rect.r3,
      3 => rect.r4,
      _ => rect.r1,
    };

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Radius ${radius.round()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);
    final boxSize = Size(
      textPainter.width + padding.horizontal,
      textPainter.height + padding.vertical,
    );

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        screenPos.dx + 12,
        screenPos.dy - boxSize.height - 12,
        boxSize.width,
        boxSize.height,
      ),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(boxRect, bgPaint);
    textPainter.paint(
      canvas,
      Offset(
        boxRect.left + padding.left,
        boxRect.top + padding.top,
      ),
    );
  }

  /// Get the combined bounding box of all selected shapes
  Rect? _getCombinedBounds() {
    if (selectedShapes.isEmpty) return null;

    double? minX, minY, maxX, maxY;

    for (final shape in selectedShapes) {
      final shapeBounds = _getTransformedBounds(shape);

      minX = minX == null
          ? shapeBounds.left
          : minX.compareTo(shapeBounds.left) < 0
              ? minX
              : shapeBounds.left;
      minY = minY == null
          ? shapeBounds.top
          : minY.compareTo(shapeBounds.top) < 0
              ? minY
              : shapeBounds.top;
      maxX = maxX == null
          ? shapeBounds.right
          : maxX.compareTo(shapeBounds.right) > 0
              ? maxX
              : shapeBounds.right;
      maxY = maxY == null
          ? shapeBounds.bottom
          : maxY.compareTo(shapeBounds.bottom) > 0
              ? maxY
              : shapeBounds.bottom;
    }

    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// Get the axis-aligned bounding box of a shape after transform
  Rect _getTransformedBounds(Shape shape) {
    final bounds = shape.bounds;

    // Get the four corners of the local bounds
    final corners = [
      shape.transformPoint(Offset(bounds.left, bounds.top)),
      shape.transformPoint(Offset(bounds.right, bounds.top)),
      shape.transformPoint(Offset(bounds.right, bounds.bottom)),
      shape.transformPoint(Offset(bounds.left, bounds.bottom)),
    ];

    // Find the axis-aligned bounding box
    var minX = corners[0].dx;
    var maxX = corners[0].dx;
    var minY = corners[0].dy;
    var maxY = corners[0].dy;

    for (final corner in corners) {
      if (corner.dx < minX) minX = corner.dx;
      if (corner.dx > maxX) maxX = corner.dx;
      if (corner.dy < minY) minY = corner.dy;
      if (corner.dy > maxY) maxY = corner.dy;
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  void _drawBoundingBox(Canvas canvas, Rect bounds) {
    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );

    // Draw outline
    final outlinePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          _screenToCanvas(SelectionHandleMetrics.selectionStrokeWidth);

    canvas.drawRect(rect, outlinePaint);

    // Draw rotation handle line
    final centerX = bounds.center.dx;
    final handleY = bounds.top - _screenToCanvas(rotationHandleOffset);

    final linePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          _screenToCanvas(SelectionHandleMetrics.selectionStrokeWidth);

    canvas.drawLine(
      Offset(centerX, bounds.top),
      Offset(centerX, handleY),
      linePaint,
    );
  }

  void _drawHandles(Canvas canvas, Rect bounds) {
    final handlePositions = _getHandlePositions(bounds);

    for (final entry in handlePositions.entries) {
      if (_isSingleTextSelection && !_isTextHandle(entry.key)) {
        continue;
      }
      _drawHandle(canvas, entry.value, entry.key == HandlePosition.rotation);
    }
  }

  Map<HandlePosition, Offset> _getHandlePositions(Rect bounds) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;

    return {
      HandlePosition.topLeft: Offset(bounds.left, bounds.top),
      HandlePosition.topCenter: Offset(centerX, bounds.top),
      HandlePosition.topRight: Offset(bounds.right, bounds.top),
      HandlePosition.middleLeft: Offset(bounds.left, centerY),
      HandlePosition.middleRight: Offset(bounds.right, centerY),
      HandlePosition.bottomLeft: Offset(bounds.left, bounds.bottom),
      HandlePosition.bottomCenter: Offset(centerX, bounds.bottom),
      HandlePosition.bottomRight: Offset(bounds.right, bounds.bottom),
      HandlePosition.rotation:
          Offset(centerX, bounds.top - _screenToCanvas(rotationHandleOffset)),
    };
  }

  void _drawHandle(Canvas canvas, Offset center, bool isRotationHandle) {
    final handleSizeInCanvas = _screenToCanvas(handleSize);
    final halfSize = handleSizeInCanvas / 2;
    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy),
      width: handleSizeInCanvas,
      height: handleSizeInCanvas,
    );

    // Fill
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Stroke
    final strokePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _screenToCanvas(SelectionHandleMetrics.handleStrokeWidth);

    if (isRotationHandle) {
      // Draw rotation handle as a circle
      canvas.drawCircle(
        Offset(center.dx, center.dy),
        halfSize,
        fillPaint,
      );
      canvas.drawCircle(
        Offset(center.dx, center.dy),
        halfSize,
        strokePaint,
      );
    } else {
      // Draw resize handles as squares
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    }
  }

  List<HandleInfo> _computeHandles() {
    final bounds = _getCombinedBounds();
    if (bounds == null) return [];

    final positions = _getHandlePositions(bounds);
    final entries = _isSingleTextSelection
        ? positions.entries.where((entry) => _isTextHandle(entry.key))
        : positions.entries;

    return entries.map((entry) {
      // Transform handle position to screen coordinates
      final screenPoint =
          viewMatrix.transformPoint(entry.value.dx, entry.value.dy);
      return HandleInfo(
        position: entry.key,
        center: Offset(screenPoint.x, screenPoint.y),
        size: handleSize,
      );
    }).toList();
  }

  /// Draw corner radius handles inside the rectangle corners
  void _drawCornerRadiusHandles(Canvas canvas, RectangleShape rect) {
    final positions = _getCornerRadiusHandlePositions(rect);
    final radiusInCanvas = _screenToCanvas(cornerRadiusHandleSize) / 2;

    // Fill
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Stroke
    final strokePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _screenToCanvas(SelectionHandleMetrics.handleStrokeWidth);

    for (final pos in positions) {
      canvas.drawCircle(pos, radiusInCanvas, fillPaint);
      canvas.drawCircle(pos, radiusInCanvas, strokePaint);
    }
  }

  /// Get corner radius handle positions inside the rectangle
  List<Offset> _getCornerRadiusHandlePositions(RectangleShape rect) {
    final bounds = rect.bounds;

    // Inset from corner in local coordinates. Bigger radius => bigger inset
    // (handle moves toward the middle).
    final minInset =
        _screenToCanvas(SelectionHandleMetrics.cornerRadiusMinInset);
    double insetFor(double radius) => math.max(minInset, radius);

    return [
      // Top-left (r1)
      rect.transformPoint(
        Offset(bounds.left + insetFor(rect.r1), bounds.top + insetFor(rect.r1)),
      ),
      // Top-right (r2)
      rect.transformPoint(
        Offset(
          bounds.right - insetFor(rect.r2),
          bounds.top + insetFor(rect.r2),
        ),
      ),
      // Bottom-right (r3)
      rect.transformPoint(
        Offset(
          bounds.right - insetFor(rect.r3),
          bounds.bottom - insetFor(rect.r3),
        ),
      ),
      // Bottom-left (r4)
      rect.transformPoint(
        Offset(
          bounds.left + insetFor(rect.r4),
          bounds.bottom - insetFor(rect.r4),
        ),
      ),
    ];
  }

  /// Compute corner radius handles for hit-testing
  List<CornerRadiusHandleInfo> _computeCornerRadiusHandles() {
    if (!showCornerRadiusHandles ||
        selectedShapes.length != 1 ||
        selectedShapes.first is! RectangleShape) {
      return [];
    }

    final rect = selectedShapes.first as RectangleShape;
    final positions = _getCornerRadiusHandlePositions(rect);
    const cornerPositions = CornerPosition.values;

    return List.generate(4, (i) {
      final screenPoint =
          viewMatrix.transformPoint(positions[i].dx, positions[i].dy);
      return CornerRadiusHandleInfo(
        cornerPosition: cornerPositions[i],
        center: Offset(screenPoint.x, screenPoint.y),
        size: cornerRadiusHandleSize,
      );
    });
  }

  @override
  bool shouldRepaint(SelectionBoxPainter oldDelegate) {
    // Fast path for drag offset changes
    if (dragOffset != oldDelegate.dragOffset) return true;

    if (activeCornerIndex != oldDelegate.activeCornerIndex) return true;
    if (hoveredCornerIndex != oldDelegate.hoveredCornerIndex) return true;

    return !identical(selectedShapes, oldDelegate.selectedShapes) ||
        viewMatrix != oldDelegate.viewMatrix ||
        showCornerRadiusHandles != oldDelegate.showCornerRadiusHandles;
  }
}
