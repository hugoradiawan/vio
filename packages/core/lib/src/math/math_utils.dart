import 'dart:math' as math;

/// Mathematical utility functions
class MathUtils {
  MathUtils._();

  /// Default epsilon for floating point comparisons
  static const double epsilon = 1e-10;

  /// Convert degrees to radians
  static double degToRad(double degrees) => degrees * math.pi / 180;

  /// Convert radians to degrees
  static double radToDeg(double radians) => radians * 180 / math.pi;

  /// Check if two doubles are approximately equal
  static bool close(double a, double b, [double eps = epsilon]) {
    return (a - b).abs() < eps;
  }

  /// Check if a value is approximately zero
  static bool isZero(double value, [double eps = epsilon]) {
    return value.abs() < eps;
  }

  /// Clamp a value between min and max
  static double clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Linear interpolation
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Inverse linear interpolation - find t given value between a and b
  static double inverseLerp(double a, double b, double value) {
    if (close(a, b)) return 0;
    return (value - a) / (b - a);
  }

  /// Remap value from one range to another
  static double remap(
    double value,
    double fromMin,
    double fromMax,
    double toMin,
    double toMax,
  ) {
    final t = inverseLerp(fromMin, fromMax, value);
    return lerp(toMin, toMax, t);
  }

  /// Smooth step interpolation
  static double smoothStep(double edge0, double edge1, double x) {
    final t = clamp((x - edge0) / (edge1 - edge0), 0, 1);
    return t * t * (3 - 2 * t);
  }

  /// Round to a specific number of decimal places
  static double roundTo(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).roundToDouble() / factor;
  }

  /// Snap value to nearest grid step
  static double snap(double value, double gridSize) {
    if (gridSize <= 0) return value;
    return (value / gridSize).roundToDouble() * gridSize;
  }

  /// Calculate the bounding box of multiple points
  static ({double minX, double minY, double maxX, double maxY})? boundingBox(
    List<({double x, double y})> points,
  ) {
    if (points.isEmpty) return null;

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final point in points) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }

    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  /// Calculate distance between two points
  static double distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate squared distance between two points (faster, no sqrt)
  static double distanceSquared(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return dx * dx + dy * dy;
  }

  /// Calculate angle from point (x1, y1) to point (x2, y2) in radians
  static double angle(double x1, double y1, double x2, double y2) {
    return math.atan2(y2 - y1, x2 - x1);
  }

  /// Normalize angle to range [0, 2*pi)
  static double normalizeAngle(double angle) {
    const twoPi = 2 * math.pi;
    var result = angle % twoPi;
    if (result < 0) result += twoPi;
    return result;
  }

  /// Normalize angle to range [-pi, pi)
  static double normalizeAngleSigned(double angle) {
    const twoPi = 2 * math.pi;
    var result = angle % twoPi;
    if (result >= math.pi) result -= twoPi;
    if (result < -math.pi) result += twoPi;
    return result;
  }
}
