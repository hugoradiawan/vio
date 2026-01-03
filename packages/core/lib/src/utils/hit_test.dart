import 'package:flutter/rendering.dart';
import 'package:vio_core/vio_core.dart';

/// Utility class for hit-testing shapes on the canvas
class HitTest {
  HitTest._();

  /// Test if a point hits a shape, accounting for transforms
  /// Returns true if the point is inside the shape
  static bool hitTestShape(Offset point, Shape shape) {
    if (shape.hidden) return false;

    // Transform the point into the shape's local coordinate system
    final localPoint = shape.inverseTransformPoint(point);

    // Perform hit test based on shape type
    return switch (shape.type) {
      ShapeType.rectangle => _hitTestRectangle(
          localPoint,
          shape as RectangleShape,
        ),
      ShapeType.ellipse => _hitTestEllipse(localPoint, shape as EllipseShape),
      ShapeType.frame => _hitTestFrame(localPoint, shape as FrameShape),
      ShapeType.path => _hitTestBounds(localPoint, shape.bounds),
      ShapeType.text => _hitTestBounds(localPoint, shape.bounds),
      ShapeType.group => _hitTestBounds(localPoint, shape.bounds),
      ShapeType.image => _hitTestBounds(localPoint, shape.bounds),
      ShapeType.svg => _hitTestBounds(localPoint, shape.bounds),
      ShapeType.bool => _hitTestBounds(localPoint, shape.bounds),
    };
  }

  /// Hit test against a rectangle shape
  static bool _hitTestRectangle(Offset point, RectangleShape shape) {
    final bounds = shape.bounds;

    // Simple bounds check for rectangles without rounded corners
    if (shape.r1 <= 0 && shape.r2 <= 0 && shape.r3 <= 0 && shape.r4 <= 0) {
      return bounds.contains(point);
    }

    // For rounded rectangles, we need more sophisticated hit testing
    // First, check if we're in the bounding box at all
    if (!bounds.contains(point)) return false;

    // Check each corner region
    final corners = [
      (bounds.left, bounds.top, shape.r1), // top-left
      (bounds.right, bounds.top, shape.r2), // top-right
      (bounds.right, bounds.bottom, shape.r3), // bottom-right
      (bounds.left, bounds.bottom, shape.r4), // bottom-left
    ];

    for (var i = 0; i < 4; i++) {
      final (cx, cy, r) = corners[i];
      if (r <= 0) continue;

      // Determine the corner center based on corner index
      final centerX = i == 0 || i == 3 ? cx + r : cx - r;
      final centerY = i == 0 || i == 1 ? cy + r : cy - r;

      // Check if point is in the corner region
      final inCornerX = i == 0 || i == 3
          ? point.dx < bounds.left + r
          : point.dx > bounds.right - r;
      final inCornerY = i == 0 || i == 1
          ? point.dy < bounds.top + r
          : point.dy > bounds.bottom - r;
      if (inCornerX && inCornerY) {
        // Point is in corner region - check distance from arc center
        final dx = point.dx - centerX;
        final dy = point.dy - centerY;
        if (dx * dx + dy * dy > r * r) {
          return false; // Outside the corner arc
        }
      }
    }

    return true;
  }

  /// Hit test against an ellipse shape
  static bool _hitTestEllipse(Offset point, EllipseShape shape) {
    final bounds = shape.bounds;
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final radiusX = bounds.width / 2;
    final radiusY = bounds.height / 2;

    if (radiusX <= 0 || radiusY <= 0) return false;

    // Ellipse equation: (x-cx)²/rx² + (y-cy)²/ry² <= 1
    final dx = point.dx - centerX;
    final dy = point.dy - centerY;
    final normalized =
        (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY);

    return normalized <= 1.0;
  }

  /// Hit test against a frame shape
  /// Frames are only selectable by clicking on their name label area
  static bool _hitTestFrame(Offset point, FrameShape shape) {
    final bounds = shape.bounds;
    // Frame name label is positioned above the frame, to the left
    // Label area: x = bounds.left, y = bounds.top - labelHeight, width = ~150, height = labelHeight
    const labelHeight = 20.0;
    const labelWidth = 150.0;
    final labelBounds = Rect.fromLTWH(
      bounds.left,
      bounds.top - labelHeight - 4, // 4px gap above frame
      labelWidth,
      labelHeight,
    );
    return labelBounds.contains(point);
  }

  /// Simple bounds hit test for unsupported shape types
  static bool _hitTestBounds(Offset point, Rect bounds) {
    return bounds.contains(point);
  }

  /// Find all shapes at a given point, in reverse order (top-most first)
  static List<Shape> findShapesAtPoint(Offset point, List<Shape> shapes) {
    final hits = <Shape>[];
    // Iterate in reverse to get top-most shapes first
    for (var i = shapes.length - 1; i >= 0; i--) {
      if (hitTestShape(point, shapes[i])) {
        hits.add(shapes[i]);
      }
    }
    return hits;
  }

  /// Find the top-most shape at a given point
  static Shape? findTopShapeAtPoint(Offset point, List<Shape> shapes) {
    // Iterate in reverse to get top-most shape first
    for (var i = shapes.length - 1; i >= 0; i--) {
      if (hitTestShape(point, shapes[i])) {
        return shapes[i];
      }
    }
    return null;
  }

  /// Find all shapes that intersect with a rectangle (for marquee selection)
  /// Note: Frames are excluded from marquee selection (they can only be selected via their label)
  static List<Shape> findShapesInRect(Rect rect, List<Shape> shapes) {
    final hits = <Shape>[];
    for (final shape in shapes) {
      if (shape.hidden) continue;
      // Skip frames - they can only be selected by clicking their label
      if (shape.type == ShapeType.frame) continue;

      // Get the shape's bounding box in world coordinates
      final shapeBounds = _getTransformedBounds(shape);
      if (rect.overlaps(shapeBounds)) {
        hits.add(shape);
      }
    }
    return hits;
  }

  /// Get the axis-aligned bounding box of a shape after transform
  static Rect _getTransformedBounds(Shape shape) {
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
}
