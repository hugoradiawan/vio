import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Immutable 2D point representation
@immutable
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  /// Zero point at origin
  static const Point2D zero = Point2D(0, 0);

  /// Create from an offset-like object
  factory Point2D.fromOffset(({double dx, double dy}) offset) {
    return Point2D(offset.dx, offset.dy);
  }

  /// Add two points
  Point2D operator +(Point2D other) => Point2D(x + other.x, y + other.y);

  /// Subtract two points
  Point2D operator -(Point2D other) => Point2D(x - other.x, y - other.y);

  /// Multiply by scalar
  Point2D operator *(double scalar) => Point2D(x * scalar, y * scalar);

  /// Divide by scalar
  Point2D operator /(double scalar) => Point2D(x / scalar, y / scalar);

  /// Negate the point
  Point2D operator -() => Point2D(-x, -y);

  /// Distance from origin
  double get magnitude => math.sqrt(x * x + y * y);

  /// Squared distance from origin (faster, no sqrt)
  double get magnitudeSquared => x * x + y * y;

  /// Distance to another point
  double distanceTo(Point2D other) => (this - other).magnitude;

  /// Squared distance to another point
  double distanceSquaredTo(Point2D other) => (this - other).magnitudeSquared;

  /// Normalize to unit vector
  Point2D get normalized {
    final m = magnitude;
    if (m == 0) return Point2D.zero;
    return this / m;
  }

  /// Dot product
  double dot(Point2D other) => x * other.x + y * other.y;

  /// Cross product (returns scalar for 2D)
  double cross(Point2D other) => x * other.y - y * other.x;

  /// Linear interpolation
  Point2D lerp(Point2D other, double t) {
    return Point2D(
      x + (other.x - x) * t,
      y + (other.y - y) * t,
    );
  }

  /// Rotate around origin by angle (radians)
  Point2D rotate(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Point2D(
      x * cos - y * sin,
      y * cos + x * sin,
    );
  }

  /// Rotate around a center point by angle (radians)
  Point2D rotateAround(Point2D center, double angle) {
    return (this - center).rotate(angle) + center;
  }

  /// Check if two points are approximately equal
  bool closeTo(Point2D other, [double epsilon = 1e-10]) {
    return (x - other.x).abs() < epsilon && (y - other.y).abs() < epsilon;
  }

  /// Clamp both coordinates
  Point2D clamp(double minX, double maxX, double minY, double maxY) {
    return Point2D(
      x.clamp(minX, maxX),
      y.clamp(minY, maxY),
    );
  }

  /// Round to nearest integer
  Point2D get rounded => Point2D(x.roundToDouble(), y.roundToDouble());

  /// Floor to integer
  Point2D get floored => Point2D(x.floorToDouble(), y.floorToDouble());

  /// Ceil to integer
  Point2D get ceiled => Point2D(x.ceilToDouble(), y.ceilToDouble());

  /// Convert to record format
  ({double x, double y}) toRecord() => (x: x, y: y);

  @override
  String toString() => 'Point2D($x, $y)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Point2D && closeTo(other);
  }

  @override
  int get hashCode => Object.hash(x, y);

  /// Copy with modifications
  Point2D copyWith({double? x, double? y}) {
    return Point2D(x ?? this.x, y ?? this.y);
  }
}
