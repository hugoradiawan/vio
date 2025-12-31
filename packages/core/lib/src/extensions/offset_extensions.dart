import 'dart:math' as math;
import 'dart:ui';

/// Extensions on Flutter's Offset class
extension OffsetExtensions on Offset {
  /// Convert to a record format
  ({double x, double y}) toRecord() => (x: dx, y: dy);

  /// Rotate around origin by angle (radians)
  Offset rotate(double angle) {
    final cos = angle.cos();
    final sin = angle.sin();
    return Offset(dx * cos - dy * sin, dx * sin + dy * cos);
  }

  /// Rotate around a center point by angle (radians)
  Offset rotateAround(Offset center, double angle) {
    return (this - center).rotate(angle) + center;
  }

  /// Linear interpolation to another offset
  Offset lerpTo(Offset other, double t) {
    return Offset(dx + (other.dx - dx) * t, dy + (other.dy - dy) * t);
  }

  /// Snap to grid
  Offset snapTo(double gridSize) {
    if (gridSize <= 0) return this;
    return Offset(
      (dx / gridSize).roundToDouble() * gridSize,
      (dy / gridSize).roundToDouble() * gridSize,
    );
  }

  /// Check if approximately equal to another offset
  bool closeTo(Offset other, [double epsilon = 1e-10]) {
    return (dx - other.dx).abs() < epsilon && (dy - other.dy).abs() < epsilon;
  }

  /// Clamp both components
  Offset clampTo(double minX, double maxX, double minY, double maxY) {
    return Offset(dx.clamp(minX, maxX), dy.clamp(minY, maxY));
  }

  /// Normalize to unit vector
  Offset get normalized {
    final mag = distance;
    if (mag == 0) return Offset.zero;
    return this / mag;
  }

  /// Cross product (returns scalar for 2D)
  double cross(Offset other) => dx * other.dy - dy * other.dx;

  /// Dot product
  double dot(Offset other) => dx * other.dx + dy * other.dy;

  /// Project onto another vector
  Offset projectOnto(Offset other) {
    final otherMagSq = other.dx * other.dx + other.dy * other.dy;
    if (otherMagSq == 0) return Offset.zero;
    final scalar = dot(other) / otherMagSq;
    return other * scalar;
  }

  /// Get perpendicular vector (90 degrees counter-clockwise)
  Offset get perpendicular => Offset(-dy, dx);
}

/// Helper extension for angle calculations
extension _DoubleAngle on double {
  double cos() => math.cos(this);
  double sin() => math.sin(this);
}
