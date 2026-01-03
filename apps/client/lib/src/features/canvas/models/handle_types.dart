import 'dart:ui';

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

/// Corner index for corner radius handles
enum CornerPosition {
  topLeft, // 0 - r1
  topRight, // 1 - r2
  bottomRight, // 2 - r3
  bottomLeft, // 3 - r4
}

/// Information about a handle for hit-testing
class HandleInfo {
  const HandleInfo({
    required this.position,
    required this.center,
    required this.size,
    this.cornerPosition,
  });

  final HandlePosition position;
  final Offset center;
  final double size;

  /// For corner radius handles
  final CornerPosition? cornerPosition;

  /// Check if a point hits this handle
  bool containsPoint(Offset point) {
    final halfSize = size / 2;
    return point.dx >= center.dx - halfSize &&
        point.dx <= center.dx + halfSize &&
        point.dy >= center.dy - halfSize &&
        point.dy <= center.dy + halfSize;
  }

  /// Check if a point hits this handle (circular)
  bool containsPointCircular(Offset point) {
    final distance = (point - center).distance;
    return distance <= size / 2;
  }
}

/// Information about a corner radius handle
class CornerRadiusHandleInfo {
  const CornerRadiusHandleInfo({
    required this.cornerPosition,
    required this.center,
    required this.size,
  });

  final CornerPosition cornerPosition;
  final Offset center;
  final double size;

  /// Check if a point hits this handle (circular)
  bool containsPoint(Offset point) {
    final distance = (point - center).distance;
    return distance <= size / 2;
  }
}

/// Extension to get opposite handle for resize anchoring
extension HandlePositionExtension on HandlePosition {
  /// Get the opposite handle position (used as anchor during resize)
  HandlePosition get opposite {
    switch (this) {
      case HandlePosition.topLeft:
        return HandlePosition.bottomRight;
      case HandlePosition.topCenter:
        return HandlePosition.bottomCenter;
      case HandlePosition.topRight:
        return HandlePosition.bottomLeft;
      case HandlePosition.middleLeft:
        return HandlePosition.middleRight;
      case HandlePosition.middleRight:
        return HandlePosition.middleLeft;
      case HandlePosition.bottomLeft:
        return HandlePosition.topRight;
      case HandlePosition.bottomCenter:
        return HandlePosition.topCenter;
      case HandlePosition.bottomRight:
        return HandlePosition.topLeft;
      case HandlePosition.rotation:
        return HandlePosition.rotation;
    }
  }

  /// Whether this handle only scales horizontally
  bool get isHorizontalOnly =>
      this == HandlePosition.middleLeft || this == HandlePosition.middleRight;

  /// Whether this handle only scales vertically
  bool get isVerticalOnly =>
      this == HandlePosition.topCenter || this == HandlePosition.bottomCenter;

  /// Whether this is a corner handle (scales both dimensions)
  bool get isCorner =>
      this == HandlePosition.topLeft ||
      this == HandlePosition.topRight ||
      this == HandlePosition.bottomLeft ||
      this == HandlePosition.bottomRight;
}
