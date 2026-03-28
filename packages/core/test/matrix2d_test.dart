import 'dart:math' as math;

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

    test('rotation getter returns correct angle after rotationAt', () {
      // Simulate the exact rotation flow from canvas_bloc_interaction.dart:
      // 1. Start with identity transform
      // 2. Create a rotationAt matrix (like the rotation drag handler does)
      // 3. Multiply: identity * rotationAt
      // 4. Check that the rotation getter returns the correct angle

      const identity = Matrix2D.identity;

      // 45 degrees in radians
      const deltaRadians = 45.0 * math.pi / 180.0;

      // Rotation around center (100, 100) — simulating shape center
      final rotationMatrix = Matrix2D.rotationAt(deltaRadians, 100, 100);

      // This is what the rotation handler does:
      // newTransform = originalShape.transform * rotationMatrix
      final newTransform = identity * rotationMatrix;

      // Check the rotation getter extracts the correct angle
      final rotDeg = newTransform.rotation * 180.0 / math.pi;
      expect(rotDeg, closeTo(45.0, 0.01));
    });

    test('rotation getter after 90 degree rotation', () {
      const identity = Matrix2D.identity;
      const deltaRadians = 90.0 * math.pi / 180.0;
      final rotationMatrix = Matrix2D.rotationAt(deltaRadians, 50, 50);
      final newTransform = identity * rotationMatrix;
      final rotDeg = newTransform.rotation * 180.0 / math.pi;
      expect(rotDeg, closeTo(90.0, 0.01));
    });

    test('rotation is preserved through multiply with identity', () {
      const deltaRadians = 30.0 * math.pi / 180.0;
      final rotated = Matrix2D.rotationAt(deltaRadians, 200, 150);
      // Multiply with identity should not change rotation
      final result = Matrix2D.identity * rotated;
      final rotDeg = result.rotation * 180.0 / math.pi;
      expect(rotDeg, closeTo(30.0, 0.01));
    });
  });
}
