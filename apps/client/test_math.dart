import 'dart:math';

import 'package:flutter/foundation.dart';

class Matrix2D {
  final double a, b, c, d, e, f;
  const Matrix2D(this.a, this.b, this.c, this.d, this.e, this.f);

  factory Matrix2D.rotationAt(double angle, double cx, double cy) {
    final cosA = cos(angle);
    final sinA = sin(angle);
    return Matrix2D(
      cosA,
      sinA,
      -sinA,
      cosA,
      cx - cx * cosA + cy * sinA,
      cy - cx * sinA - cy * cosA,
    );
  }

  ({double x, double y}) transformPoint(double x, double y) {
    return (x: a * x + c * y + e, y: b * x + d * y + f);
  }
}

void main() {
  const double x = 10, y = 10, w = 100, h = 100;
  const double cx = x + w / 2;
  const double cy = y + h / 2;

  var m = Matrix2D.rotationAt(pi / 2, cx, cy);

  debugPrint('Dart paint top-left (10, 10): ${m.transformPoint(x, y)}');
  debugPrint(
    'Dart paint bottom-right (110, 110): ${m.transformPoint(x + w, y + h)}',
  );

  // Move by 50, 50
  m = Matrix2D(m.a, m.b, m.c, m.d, m.e + 50, m.f + 50);

  debugPrint('Dart after move top-left (10, 10): ${m.transformPoint(x, y)}');

  // Rust matrix
  final mRust = Matrix2D(
    m.a,
    m.b,
    m.c,
    m.d,
    m.a * x + m.c * y + m.e,
    m.b * x + m.d * y + m.f,
  );

  debugPrint('Rust paint top-left (0, 0): ${mRust.transformPoint(0, 0)}');
  debugPrint(
    'Rust paint bottom-right (100, 100): ${mRust.transformPoint(w, h)}',
  );
}
