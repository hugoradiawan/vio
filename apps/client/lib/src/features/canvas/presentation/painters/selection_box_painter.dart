import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../models/handle_types.dart';

export '../../models/handle_types.dart';

/// Paints the selection bounding box with resize and rotation handles
class SelectionBoxPainter extends CustomPainter {
  SelectionBoxPainter({
    required this.selectedShapes,
    required this.viewMatrix,
    this.dragOffset,
    this.handleSize = 8.0,
    this.rotationHandleOffset = 24.0,
    this.cornerRadiusHandleSize = 6.0,
    this.showCornerRadiusHandles = false,
  });

  /// The shapes that are selected
  final List<Shape> selectedShapes;

  /// View transformation matrix
  final Matrix2D viewMatrix;

  /// Current drag offset (applied at render time)
  final Offset? dragOffset;

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
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, outlinePaint);

    // Draw rotation handle line
    final centerX = bounds.center.dx;
    final handleY = bounds.top - rotationHandleOffset;

    final linePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(centerX, bounds.top),
      Offset(centerX, handleY),
      linePaint,
    );
  }

  void _drawHandles(Canvas canvas, Rect bounds) {
    final handlePositions = _getHandlePositions(bounds);

    for (final entry in handlePositions.entries) {
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
          Offset(centerX, bounds.top - rotationHandleOffset),
    };
  }

  void _drawHandle(Canvas canvas, Offset center, bool isRotationHandle) {
    final halfSize = handleSize / 2;
    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy),
      width: handleSize,
      height: handleSize,
    );

    // Fill
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Stroke
    final strokePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

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
    return positions.entries.map((entry) {
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

    // Fill
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Stroke
    final strokePaint = Paint()
      ..color = VioColors.canvasSelection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pos in positions) {
      canvas.drawCircle(pos, cornerRadiusHandleSize / 2, fillPaint);
      canvas.drawCircle(pos, cornerRadiusHandleSize / 2, strokePaint);
    }
  }

  /// Get corner radius handle positions inside the rectangle
  List<Offset> _getCornerRadiusHandlePositions(RectangleShape rect) {
    // Handle offset from corner (diagonal distance inward)
    const handleOffset = 16.0;
    final bounds = rect.bounds;

    // Calculate handle positions based on current corner radii
    // Each handle is positioned diagonally inward from its corner
    const diagonalOffset = handleOffset * 0.707; // cos(45°) ≈ 0.707

    return [
      // Top-left (r1)
      rect.transformPoint(
        Offset(bounds.left + diagonalOffset, bounds.top + diagonalOffset),
      ),
      // Top-right (r2)
      rect.transformPoint(
        Offset(bounds.right - diagonalOffset, bounds.top + diagonalOffset),
      ),
      // Bottom-right (r3)
      rect.transformPoint(
        Offset(bounds.right - diagonalOffset, bounds.bottom - diagonalOffset),
      ),
      // Bottom-left (r4)
      rect.transformPoint(
        Offset(bounds.left + diagonalOffset, bounds.bottom - diagonalOffset),
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

    return !identical(selectedShapes, oldDelegate.selectedShapes) ||
        viewMatrix != oldDelegate.viewMatrix ||
        showCornerRadiusHandles != oldDelegate.showCornerRadiusHandles;
  }
}
