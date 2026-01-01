import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vio_core/vio_core.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Handle position on the selection box
enum HandlePosition {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  rotation,
}

/// Information about a handle for hit-testing
class HandleInfo {
  const HandleInfo({
    required this.position,
    required this.center,
    required this.size,
  });

  final HandlePosition position;
  final Point2D center;
  final double size;

  /// Check if a point hits this handle
  bool containsPoint(Point2D point) {
    final halfSize = size / 2;
    return point.x >= center.x - halfSize &&
        point.x <= center.x + halfSize &&
        point.y >= center.y - halfSize &&
        point.y <= center.y + halfSize;
  }
}

/// Paints the selection bounding box with resize and rotation handles
class SelectionBoxPainter extends CustomPainter {
  SelectionBoxPainter({
    required this.selectedShapes,
    required this.viewMatrix,
    this.dragOffset,
    this.handleSize = 8.0,
    this.rotationHandleOffset = 24.0,
  });

  /// The shapes that are selected
  final List<Shape> selectedShapes;

  /// View transformation matrix
  final Matrix2D viewMatrix;

  /// Current drag offset (applied at render time)
  final Point2D? dragOffset;

  /// Size of resize handles
  final double handleSize;

  /// Distance of rotation handle from top edge
  final double rotationHandleOffset;

  /// Computed handles for hit-testing (in screen coordinates)
  List<HandleInfo> get handles => _computeHandles();

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
      canvas.translate(dragOffset!.x, dragOffset!.y);
    }

    // Draw bounding box
    _drawBoundingBox(canvas, bounds);

    // Draw handles
    _drawHandles(canvas, bounds);

    canvas.restore();
  }

  /// Get the combined bounding box of all selected shapes
  Rect2D? _getCombinedBounds() {
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

    return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY);
  }

  /// Get the axis-aligned bounding box of a shape after transform
  Rect2D _getTransformedBounds(Shape shape) {
    final bounds = shape.bounds;

    // Get the four corners of the local bounds
    final corners = [
      shape.transformPoint(Point2D(bounds.left, bounds.top)),
      shape.transformPoint(Point2D(bounds.right, bounds.top)),
      shape.transformPoint(Point2D(bounds.right, bounds.bottom)),
      shape.transformPoint(Point2D(bounds.left, bounds.bottom)),
    ];

    // Find the axis-aligned bounding box
    var minX = corners[0].x;
    var maxX = corners[0].x;
    var minY = corners[0].y;
    var maxY = corners[0].y;

    for (final corner in corners) {
      if (corner.x < minX) minX = corner.x;
      if (corner.x > maxX) maxX = corner.x;
      if (corner.y < minY) minY = corner.y;
      if (corner.y > maxY) maxY = corner.y;
    }

    return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY);
  }

  void _drawBoundingBox(Canvas canvas, Rect2D bounds) {
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
    final centerX = bounds.centerX;
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

  void _drawHandles(Canvas canvas, Rect2D bounds) {
    final handlePositions = _getHandlePositions(bounds);

    for (final entry in handlePositions.entries) {
      _drawHandle(canvas, entry.value, entry.key == HandlePosition.rotation);
    }
  }

  Map<HandlePosition, Point2D> _getHandlePositions(Rect2D bounds) {
    final centerX = bounds.centerX;
    final centerY = bounds.centerY;

    return {
      HandlePosition.topLeft: Point2D(bounds.left, bounds.top),
      HandlePosition.topCenter: Point2D(centerX, bounds.top),
      HandlePosition.topRight: Point2D(bounds.right, bounds.top),
      HandlePosition.middleLeft: Point2D(bounds.left, centerY),
      HandlePosition.middleRight: Point2D(bounds.right, centerY),
      HandlePosition.bottomLeft: Point2D(bounds.left, bounds.bottom),
      HandlePosition.bottomCenter: Point2D(centerX, bounds.bottom),
      HandlePosition.bottomRight: Point2D(bounds.right, bounds.bottom),
      HandlePosition.rotation:
          Point2D(centerX, bounds.top - rotationHandleOffset),
    };
  }

  void _drawHandle(Canvas canvas, Point2D center, bool isRotationHandle) {
    final halfSize = handleSize / 2;
    final rect = Rect.fromCenter(
      center: Offset(center.x, center.y),
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
        Offset(center.x, center.y),
        halfSize,
        fillPaint,
      );
      canvas.drawCircle(
        Offset(center.x, center.y),
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
          viewMatrix.transformPoint(entry.value.x, entry.value.y);
      return HandleInfo(
        position: entry.key,
        center: Point2D(screenPoint.x, screenPoint.y),
        size: handleSize,
      );
    }).toList();
  }

  @override
  bool shouldRepaint(SelectionBoxPainter oldDelegate) {
    // Fast path for drag offset changes
    if (dragOffset != oldDelegate.dragOffset) return true;
    
    return !identical(selectedShapes, oldDelegate.selectedShapes) ||
        viewMatrix != oldDelegate.viewMatrix;
  }
}
