import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'point2d.dart';

/// Immutable 2D rectangle representation
@immutable
class Rect2D {
  final double x;
  final double y;
  final double width;
  final double height;

  const Rect2D({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Zero rectangle at origin
  static const Rect2D zero = Rect2D(x: 0, y: 0, width: 0, height: 0);

  /// Create from center point and size
  factory Rect2D.fromCenter({
    required Point2D center,
    required double width,
    required double height,
  }) {
    return Rect2D(
      x: center.x - width / 2,
      y: center.y - height / 2,
      width: width,
      height: height,
    );
  }

  /// Create from two corner points
  factory Rect2D.fromPoints(Point2D p1, Point2D p2) {
    final minX = math.min(p1.x, p2.x);
    final minY = math.min(p1.y, p2.y);
    final maxX = math.max(p1.x, p2.x);
    final maxY = math.max(p1.y, p2.y);
    return Rect2D(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Create from left, top, right, bottom
  factory Rect2D.fromLTRB(
      double left, double top, double right, double bottom) {
    return Rect2D(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  // Getters for edges
  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;

  // Getters for corners
  Point2D get topLeft => Point2D(left, top);
  Point2D get topRight => Point2D(right, top);
  Point2D get bottomLeft => Point2D(left, bottom);
  Point2D get bottomRight => Point2D(right, bottom);

  // Getters for center
  Point2D get center => Point2D(x + width / 2, y + height / 2);
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  // Size helpers
  double get area => width * height;
  double get perimeter => 2 * (width + height);
  double get aspectRatio => width / height;
  bool get isEmpty => width <= 0 || height <= 0;

  /// Check if a point is inside this rectangle
  bool containsPoint(Point2D point) {
    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  /// Check if this rectangle contains another rectangle
  bool containsRect(Rect2D other) {
    return other.left >= left &&
        other.right <= right &&
        other.top >= top &&
        other.bottom <= bottom;
  }

  /// Check if this rectangle intersects with another
  bool intersects(Rect2D other) {
    return left < other.right &&
        right > other.left &&
        top < other.bottom &&
        bottom > other.top;
  }

  /// Get the intersection with another rectangle
  Rect2D? intersection(Rect2D other) {
    if (!intersects(other)) return null;
    return Rect2D.fromLTRB(
      math.max(left, other.left),
      math.max(top, other.top),
      math.min(right, other.right),
      math.min(bottom, other.bottom),
    );
  }

  /// Get the union (bounding box) with another rectangle
  Rect2D union(Rect2D other) {
    return Rect2D.fromLTRB(
      math.min(left, other.left),
      math.min(top, other.top),
      math.max(right, other.right),
      math.max(bottom, other.bottom),
    );
  }

  /// Expand rectangle by delta on all sides
  Rect2D inflate(double delta) {
    return Rect2D(
      x: x - delta,
      y: y - delta,
      width: width + delta * 2,
      height: height + delta * 2,
    );
  }

  /// Shrink rectangle by delta on all sides
  Rect2D deflate(double delta) => inflate(-delta);

  /// Translate rectangle
  Rect2D translate(double dx, double dy) {
    return Rect2D(x: x + dx, y: y + dy, width: width, height: height);
  }

  /// Scale rectangle from its center
  Rect2D scale(double factor) {
    final newWidth = width * factor;
    final newHeight = height * factor;
    return Rect2D(
      x: centerX - newWidth / 2,
      y: centerY - newHeight / 2,
      width: newWidth,
      height: newHeight,
    );
  }

  /// Get the four corner points
  List<Point2D> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  /// Check if two rectangles are approximately equal
  bool closeTo(Rect2D other, [double epsilon = 1e-10]) {
    return (x - other.x).abs() < epsilon &&
        (y - other.y).abs() < epsilon &&
        (width - other.width).abs() < epsilon &&
        (height - other.height).abs() < epsilon;
  }

  @override
  String toString() => 'Rect2D(x: $x, y: $y, width: $width, height: $height)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rect2D && closeTo(other);
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);

  /// Copy with modifications
  Rect2D copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return Rect2D(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
