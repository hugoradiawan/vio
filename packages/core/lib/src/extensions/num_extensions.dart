import 'dart:math' as math;

/// Extensions on numeric types
extension NumExtensions on num {
  /// Convert degrees to radians
  double get toRadians => this * math.pi / 180;

  /// Convert radians to degrees
  double get toDegrees => this * 180 / math.pi;

  /// Check if this value is approximately equal to another
  bool closeTo(num other, [double epsilon = 1e-10]) {
    return (this - other).abs() < epsilon;
  }

  /// Check if this value is approximately zero
  bool get isAlmostZero => closeTo(0);

  /// Round to specific decimal places
  double roundTo(int decimals) {
    final factor = math.pow(10, decimals);
    return (this * factor).roundToDouble() / factor;
  }

  /// Snap to nearest grid value
  double snapTo(double gridSize) {
    if (gridSize <= 0) return toDouble();
    return (this / gridSize).roundToDouble() * gridSize;
  }

  /// Clamp between min and max with type inference
  T clampTo<T extends num>(T min, T max) {
    if (this < min) return min;
    if (this > max) return max;
    return this as T;
  }

  /// Linear interpolation to target
  double lerpTo(num target, double t) {
    return this + (target - this) * t;
  }
}

/// Extensions specifically for double
extension DoubleExtensions on double {
  /// Remap from one range to another
  double remap(double fromMin, double fromMax, double toMin, double toMax) {
    if (fromMin == fromMax) return toMin;
    final t = (this - fromMin) / (fromMax - fromMin);
    return toMin + (toMax - toMin) * t;
  }

  /// Smooth step interpolation
  double smoothStep(double edge0, double edge1) {
    final t = ((this - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Format with fixed decimal places, removing trailing zeros
  String toCleanString([int maxDecimals = 6]) {
    final fixed = toStringAsFixed(maxDecimals);
    // Remove trailing zeros and potential trailing decimal point
    var result = fixed.replaceAll(RegExp(r'0+$'), '');
    if (result.endsWith('.')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

/// Extensions for int
extension IntExtensions on int {
  /// Check if this integer is even
  bool get isEven => this % 2 == 0;

  /// Check if this integer is odd
  bool get isOdd => this % 2 != 0;

  /// Generate a range of integers
  Iterable<int> to(int end, [int step = 1]) sync* {
    if (step == 0) throw ArgumentError('Step cannot be zero');
    if (step > 0) {
      for (var i = this; i <= end; i += step) {
        yield i;
      }
    } else {
      for (var i = this; i >= end; i += step) {
        yield i;
      }
    }
  }
}
