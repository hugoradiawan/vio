import 'package:flutter_test/flutter_test.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

void main() {
  group('VioColors', () {
    test('primary color is correct', () {
      // Using toARGB32 instead of deprecated .value
      expect(VioColors.primary.toARGB32(), 0xFF4C9AFF);
    });

    test('background color is correct', () {
      expect(VioColors.background.toARGB32(), 0xFF0D1117);
    });

    test('surface color is correct', () {
      expect(VioColors.surface.toARGB32(), 0xFF161B22);
    });

    test('textPrimary color is correct', () {
      expect(VioColors.textPrimary.toARGB32(), 0xFFE6EDF3);
    });
  });
}
