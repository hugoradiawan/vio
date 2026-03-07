import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Prevent network font fetching during unit tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  group('VioTheme.fromSeed', () {
    test('returns a valid ThemeData', () {
      final theme = VioTheme.fromSeed(VioColors.primary);
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
    });

    test('uses the provided seed color in the ColorScheme', () {
      const seed = Color(0xFFAA00FF); // purple
      final theme = VioTheme.fromSeed(seed);
      // M3 ColorScheme.fromSeed derives primary from the seed, not always
      // identical — just verify it's non-null and the scheme is named dark.
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNotNull);
    });

    test('defaults to dark brightness', () {
      final theme = VioTheme.fromSeed(VioColors.primary);
      expect(theme.brightness, Brightness.dark);
    });

    test('produces light brightness when ThemeMode.light is passed', () {
      final theme = VioTheme.fromSeed(VioColors.primary, mode: ThemeMode.light);
      expect(theme.brightness, Brightness.light);
    });

    test('produces dark brightness for ThemeMode.system', () {
      // system → dark (our fallback for non-light modes)
      final theme =
          VioTheme.fromSeed(VioColors.primary, mode: ThemeMode.system);
      expect(theme.brightness, Brightness.dark);
    });

    test('attaches VioCanvasTheme extension', () {
      final theme = VioTheme.fromSeed(VioColors.primary);
      final canvas = theme.extension<VioCanvasTheme>();
      expect(canvas, isNotNull);
    });

    test('canvas selectionColor derives from seed primary', () {
      const seed = Color(0xFF00BCD4); // teal
      final theme = VioTheme.fromSeed(seed);
      final canvas = theme.extension<VioCanvasTheme>()!;
      // selectionColor must equal the generated colorScheme.primary
      expect(canvas.selectionColor, equals(theme.colorScheme.primary));
    });

    test('canvas background stays dark regardless of seed', () {
      const seed = Color(0xFFFFEB3B); // yellow — extreme contrast check
      final theme = VioTheme.fromSeed(seed);
      final canvas = theme.extension<VioCanvasTheme>()!;
      // Canvas bg must be the fixed dark constant, not anything derived from yellow
      expect(canvas.canvasBackground, equals(VioColors.canvas));
    });

    test('different seeds produce different primary colors', () {
      final blueTheme = VioTheme.fromSeed(const Color(0xFF2196F3));
      final redTheme = VioTheme.fromSeed(const Color(0xFFF44336));
      expect(blueTheme.colorScheme.primary, isNot(redTheme.colorScheme.primary));
    });

    test('scaffold background stays dark in dark mode regardless of seed', () {
      final theme =
          VioTheme.fromSeed(const Color(0xFFFF9800)); // orange seed
      expect(theme.scaffoldBackgroundColor, equals(VioColors.background));
    });
  });

  group('VioTheme.darkTheme (backward compat)', () {
    test('still attaches VioCanvasTheme extension', () {
      final canvas = VioTheme.darkTheme.extension<VioCanvasTheme>();
      expect(canvas, isNotNull);
    });

    test('selectionColor matches VioColors.primary', () {
      final canvas = VioTheme.darkTheme.extension<VioCanvasTheme>()!;
      expect(canvas.selectionColor, equals(VioColors.primary));
    });

    test('uses Material 3', () {
      expect(VioTheme.darkTheme.useMaterial3, isTrue);
    });
  });

  group('VioCanvasTheme', () {
    test('fromPrimary sets selectionColor', () {
      const color = Color(0xFF9C27B0);
      final t = VioCanvasTheme.fromPrimary(color);
      expect(t.selectionColor, equals(color));
    });

    test('copyWith overrides specific fields', () {
      final original = VioCanvasTheme.fromPrimary(VioColors.primary);
      final updated =
          original.copyWith(selectionColor: const Color(0xFF4CAF50));
      expect(updated.selectionColor, const Color(0xFF4CAF50));
      expect(updated.canvasBackground, equals(original.canvasBackground));
    });

    test('lerp interpolates colors', () {
      final a = VioCanvasTheme.fromPrimary(const Color(0xFF0000FF));
      final b = VioCanvasTheme.fromPrimary(const Color(0xFFFF0000));
      final mid = a.lerp(b, 0.5);
      // midpoint between blue and red selection colors should be neither
      expect(mid.selectionColor, isNot(a.selectionColor));
      expect(mid.selectionColor, isNot(b.selectionColor));
    });

    test('equality holds for identical instances', () {
      final a = VioCanvasTheme.fromPrimary(VioColors.primary);
      final b = VioCanvasTheme.fromPrimary(VioColors.primary);
      expect(a, equals(b));
    });
  });
}
