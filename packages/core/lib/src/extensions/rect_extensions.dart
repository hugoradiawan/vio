import 'dart:math' as math;
import 'dart:ui';

/// Extensions on Flutter's Rect class
extension RectExtensions on Rect {
  /// Get center as Offset
  Offset get centerOffset => Offset(center.dx, center.dy);

  /// Expand rect by delta on all sides
  Rect inflateBy(double delta) {
    return Rect.fromLTRB(
      left - delta,
      top - delta,
      right + delta,
      bottom + delta,
    );
  }

  /// Shrink rect by delta on all sides
  Rect deflateBy(double delta) => inflateBy(-delta);

  /// Scale rect from its center
  Rect scaleFromCenter(double factor) {
    final newWidth = width * factor;
    final newHeight = height * factor;
    return Rect.fromCenter(center: center, width: newWidth, height: newHeight);
  }

  /// Get all four corners as list of Offsets
  List<Offset> get corners => [
        topLeft,
        topRight,
        Offset(right, bottom),
        Offset(left, bottom),
      ];

  /// Check if this rect fully contains another rect
  bool fullyContains(Rect other) {
    return left <= other.left &&
        right >= other.right &&
        top <= other.top &&
        bottom >= other.bottom;
  }

  /// Get union with another rect
  Rect union(Rect other) {
    return Rect.fromLTRB(
      math.min(left, other.left),
      math.min(top, other.top),
      math.max(right, other.right),
      math.max(bottom, other.bottom),
    );
  }

  /// Get intersection with another rect, or null if no intersection
  Rect? safeIntersect(Rect other) {
    if (!overlaps(other)) return null;
    return intersect(other);
  }

  /// Translate rect by offset
  Rect translateBy(Offset offset) {
    return translate(offset.dx, offset.dy);
  }

  /// Round all values to integers
  Rect get rounded {
    return Rect.fromLTRB(
      left.roundToDouble(),
      top.roundToDouble(),
      right.roundToDouble(),
      bottom.roundToDouble(),
    );
  }

  /// Aspect ratio (width / height)
  double get aspectRatio => width / height;

  /// Area of the rectangle
  double get area => width * height;

  /// Perimeter of the rectangle
  double get perimeter => 2 * (width + height);

  /// Check if rect is approximately equal to another
  bool closeTo(Rect other, [double epsilon = 1e-10]) {
    return (left - other.left).abs() < epsilon &&
        (top - other.top).abs() < epsilon &&
        (right - other.right).abs() < epsilon &&
        (bottom - other.bottom).abs() < epsilon;
  }

  /// Constrain a point to be within this rect
  Offset constrainPoint(Offset point) {
    return Offset(point.dx.clamp(left, right), point.dy.clamp(top, bottom));
  }

  /// Create rect with a margin around it
  Rect withMargin(double margin) {
    return Rect.fromLTRB(
      left - margin,
      top - margin,
      right + margin,
      bottom + margin,
    );
  }

  /// Create rect fitted inside another rect maintaining aspect ratio
  Rect fitInside(Rect container) {
    final scale = math.min(container.width / width, container.height / height);
    final newWidth = width * scale;
    final newHeight = height * scale;
    return Rect.fromCenter(
      center: container.center,
      width: newWidth,
      height: newHeight,
    );
  }

  /// Create rect that covers another rect maintaining aspect ratio
  Rect coverRect(Rect target) {
    final scale = math.max(target.width / width, target.height / height);
    final newWidth = width * scale;
    final newHeight = height * scale;
    return Rect.fromCenter(
      center: target.center,
      width: newWidth,
      height: newHeight,
    );
  }
}
