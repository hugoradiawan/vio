import 'package:flutter_test/flutter_test.dart';
import 'package:vio_core/vio_core.dart';

void main() {
  group('Matrix2D', () {
    test('identity matrix has correct values', () {
      const identity = Matrix2D.identity;

      expect(identity.a, 1.0);
      expect(identity.b, 0.0);
      expect(identity.c, 0.0);
      expect(identity.d, 1.0);
      expect(identity.e, 0.0);
      expect(identity.f, 0.0);
    });

    test('copyWith preserves unchanged values', () {
      const matrix = Matrix2D(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6);
      final updated = matrix.copyWith(e: 10, f: 20);

      expect(updated.a, 1);
      expect(updated.b, 2);
      expect(updated.c, 3);
      expect(updated.d, 4);
      expect(updated.e, 10);
      expect(updated.f, 20);
    });
  });
}
