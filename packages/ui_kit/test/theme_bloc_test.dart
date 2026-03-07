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
  group('ThemeState', () {
    test('initial state uses VioColors.primary seed and dark mode', () {
      final state = ThemeState.initial();
      expect(state.seedColor, equals(VioColors.primary));
      expect(state.themeMode, equals(ThemeMode.dark));
    });

    test('themeData is a valid ThemeData', () {
      final state = ThemeState.initial();
      expect(state.themeData, isA<ThemeData>());
    });

    test('themeData reflects seedColor', () {
      const seed = Color(0xFF4CAF50); // green
      const state = ThemeState(seedColor: seed, themeMode: ThemeMode.dark);
      final td = state.themeData;
      // Green seed → non-blue primary
      expect(td.colorScheme.primary, isNot(VioColors.primary));
    });

    test('copyWith changes only specified fields', () {
      final original = ThemeState.initial();
      final changed =
          original.copyWith(themeMode: ThemeMode.light);
      expect(changed.themeMode, equals(ThemeMode.light));
      expect(changed.seedColor, equals(original.seedColor));
    });

    test('two states with same inputs are equal', () {
      final a = ThemeState.initial();
      final b = ThemeState.initial();
      expect(a, equals(b));
    });

    test('states with different seeds are not equal', () {
      const a = ThemeState(
        seedColor: Color(0xFF000000),
        themeMode: ThemeMode.dark,
      );
      const b = ThemeState(
        seedColor: Color(0xFFFFFFFF),
        themeMode: ThemeMode.dark,
      );
      expect(a, isNot(b));
    });
  });

  group('ThemeBloc', () {
    late ThemeBloc bloc;

    setUp(() {
      bloc = ThemeBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state matches ThemeState.initial()', () {
      expect(bloc.state, equals(ThemeState.initial()));
    });

    test('ThemeLoaded updates seed and mode', () async {
      const newSeed = Color(0xFFE91E63); // pink
      bloc.add(
        const ThemeLoaded(seedColor: newSeed, mode: ThemeMode.light),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.seedColor, equals(newSeed));
      expect(bloc.state.themeMode, equals(ThemeMode.light));
    });

    test('ThemeSeedChanged updates only seedColor', () async {
      const originalMode = ThemeMode.dark;
      const newSeed = Color(0xFF9C27B0); // purple
      bloc.add(const ThemeSeedChanged(newSeed));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.seedColor, equals(newSeed));
      expect(bloc.state.themeMode, equals(originalMode));
    });

    test('ThemeModeChanged updates only themeMode', () async {
      final originalSeed = bloc.state.seedColor;
      bloc.add(const ThemeModeChanged(ThemeMode.light));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.themeMode, ThemeMode.light);
      expect(bloc.state.seedColor, equals(originalSeed));
    });

    test('multiple events accumulate correctly', () async {
      const seed = Color(0xFF00BCD4); // teal
      bloc
        ..add(const ThemeSeedChanged(seed))
        ..add(const ThemeModeChanged(ThemeMode.light));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.seedColor, equals(seed));
      expect(bloc.state.themeMode, ThemeMode.light);
    });

    test('ThemeLoaded followed by ThemeSeedChanged changes seed', () async {
      const loadedSeed = Color(0xFF607D8B); // blue-grey
      const newSeed = Color(0xFFFF5722); // deep-orange
      bloc
        ..add(
          const ThemeLoaded(seedColor: loadedSeed, mode: ThemeMode.dark),
        )
        ..add(const ThemeSeedChanged(newSeed));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.seedColor, equals(newSeed));
      expect(bloc.state.themeMode, ThemeMode.dark);
    });
  });
}
