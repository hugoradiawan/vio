import 'dart:math' as math;

/// 2D Affine Transformation Matrix (3x3)
///
/// Represents a 2D affine transformation using a 3x3 matrix:
/// ```
/// | a  c  e |   | scaleX  skewX   translateX |
/// | b  d  f | = | skewY   scaleY  translateY |
/// | 0  0  1 |   | 0       0       1          |
/// ```
///
/// This follows the same convention as Penpot's matrix representation.
class Matrix2D {
  /// Scale X component
  final double a;

  /// Skew Y component
  final double b;

  /// Skew X component
  final double c;

  /// Scale Y component
  final double d;

  /// Translate X component
  final double e;

  /// Translate Y component
  final double f;

  const Matrix2D({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
  });

  /// Identity matrix - no transformation
  static const Matrix2D identity = Matrix2D(
    a: 1,
    b: 0,
    c: 0,
    d: 1,
    e: 0,
    f: 0,
  );

  /// Creates a translation matrix
  factory Matrix2D.translation(double tx, double ty) {
    return Matrix2D(a: 1, b: 0, c: 0, d: 1, e: tx, f: ty);
  }

  /// Creates a scale matrix around origin
  factory Matrix2D.scale(double sx, double sy) {
    return Matrix2D(a: sx, b: 0, c: 0, d: sy, e: 0, f: 0);
  }

  /// Creates a scale matrix around a center point
  factory Matrix2D.scaleAt(double sx, double sy, double cx, double cy) {
    return Matrix2D(
      a: sx,
      b: 0,
      c: 0,
      d: sy,
      e: cx - cx * sx,
      f: cy - cy * sy,
    );
  }

  /// Creates a rotation matrix around origin (angle in radians)
  factory Matrix2D.rotation(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Matrix2D(a: cos, b: sin, c: -sin, d: cos, e: 0, f: 0);
  }

  /// Creates a rotation matrix around a center point (angle in radians)
  factory Matrix2D.rotationAt(double angle, double cx, double cy) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Matrix2D(
      a: cos,
      b: sin,
      c: -sin,
      d: cos,
      e: cx - cx * cos + cy * sin,
      f: cy - cx * sin - cy * cos,
    );
  }

  /// Multiply this matrix with another matrix
  /// Result = this * other
  Matrix2D multiply(Matrix2D other) {
    return Matrix2D(
      a: a * other.a + c * other.b,
      b: b * other.a + d * other.b,
      c: a * other.c + c * other.d,
      d: b * other.c + d * other.d,
      e: a * other.e + c * other.f + e,
      f: b * other.e + d * other.f + f,
    );
  }

  /// Operator for matrix multiplication
  Matrix2D operator *(Matrix2D other) => multiply(other);

  /// Transform a point using this matrix
  ({double x, double y}) transformPoint(double x, double y) {
    return (
      x: a * x + c * y + e,
      y: b * x + d * y + f,
    );
  }

  /// Calculate the inverse of this matrix
  /// Returns null if the matrix is not invertible (determinant is zero)
  Matrix2D? get inverse {
    final det = determinant;
    if (det.abs() < 1e-10) return null;

    final invDet = 1.0 / det;
    return Matrix2D(
      a: d * invDet,
      b: -b * invDet,
      c: -c * invDet,
      d: a * invDet,
      e: (c * f - d * e) * invDet,
      f: (b * e - a * f) * invDet,
    );
  }

  /// Calculate the determinant of this matrix
  double get determinant => a * d - b * c;

  /// Check if this is an identity matrix
  bool get isIdentity {
    return _close(a, 1) &&
        _close(b, 0) &&
        _close(c, 0) &&
        _close(d, 1) &&
        _close(e, 0) &&
        _close(f, 0);
  }

  /// Check if two values are close (for floating point comparison)
  static bool _close(double a, double b, [double epsilon = 1e-10]) {
    return (a - b).abs() < epsilon;
  }

  /// Check if two matrices are approximately equal
  bool closeTo(Matrix2D other, [double epsilon = 1e-10]) {
    return _close(a, other.a, epsilon) &&
        _close(b, other.b, epsilon) &&
        _close(c, other.c, epsilon) &&
        _close(d, other.d, epsilon) &&
        _close(e, other.e, epsilon) &&
        _close(f, other.f, epsilon);
  }

  /// Extract scale factors from the matrix
  ({double x, double y}) get scale {
    return (
      x: math.sqrt(a * a + b * b),
      y: math.sqrt(c * c + d * d),
    );
  }

  /// Extract rotation angle from the matrix (in radians)
  double get rotation => math.atan2(b, a);

  /// Extract translation from the matrix
  ({double x, double y}) get translation => (x: e, y: f);

  /// Convert to a flat list [a, b, c, d, e, f]
  List<double> toList() => [a, b, c, d, e, f];

  /// Create from a flat list [a, b, c, d, e, f]
  factory Matrix2D.fromList(List<double> values) {
    if (values.length != 6) {
      throw ArgumentError('Matrix2D requires exactly 6 values');
    }
    return Matrix2D(
      a: values[0],
      b: values[1],
      c: values[2],
      d: values[3],
      e: values[4],
      f: values[5],
    );
  }

  /// Format with precision for display/serialization
  String format([int precision = 6]) {
    String fix(double v) => v.toStringAsFixed(precision);
    return 'matrix(${fix(a)}, ${fix(b)}, ${fix(c)}, ${fix(d)}, ${fix(e)}, ${fix(f)})';
  }

  @override
  String toString() => format(2);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Matrix2D && closeTo(other);
  }

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  /// Copy with modifications
  Matrix2D copyWith({
    double? a,
    double? b,
    double? c,
    double? d,
    double? e,
    double? f,
  }) {
    return Matrix2D(
      a: a ?? this.a,
      b: b ?? this.b,
      c: c ?? this.c,
      d: d ?? this.d,
      e: e ?? this.e,
      f: f ?? this.f,
    );
  }

  /// Returns a new matrix with translation applied
  Matrix2D translated(double tx, double ty) {
    return multiply(Matrix2D.translation(tx, ty));
  }

  /// Returns a new matrix with scale applied
  Matrix2D scaled(double sx, double sy) {
    return multiply(Matrix2D.scale(sx, sy));
  }

  /// Returns a new matrix with rotation applied (angle in radians)
  Matrix2D rotated(double angle) {
    return multiply(Matrix2D.rotation(angle));
  }

  /// Returns a new matrix with scale applied around a center point
  Matrix2D scaledAt(double sx, double sy, double cx, double cy) {
    return multiply(Matrix2D.scaleAt(sx, sy, cx, cy));
  }

  /// Returns a new matrix with rotation applied around a center point
  Matrix2D rotatedAt(double angle, double cx, double cy) {
    return multiply(Matrix2D.rotationAt(angle, cx, cy));
  }
}
