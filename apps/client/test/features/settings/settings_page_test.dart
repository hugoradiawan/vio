import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/features/settings/presentation/settings_page.dart';
import 'package:vio_client/src/features/settings/presentation/widgets/theme_section.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump a minimal widget tree with a real [ThemeBloc] so that
/// [BlocBuilder<ThemeBloc, ThemeState>] and [context.read<ThemeBloc>()]
/// work inside the widget-under-test.
Widget _wrap(Widget child, {ThemeBloc? bloc}) {
  final themeBloc = bloc ?? ThemeBloc();
  return BlocProvider<ThemeBloc>.value(
    value: themeBloc,
    child: MaterialApp(
      theme: ThemeState.initial().themeData,
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// ThemeSection tests
// ---------------------------------------------------------------------------

void main() {
  group('ThemeSection', () {
    testWidgets('renders preset color swatches', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ThemeSection(
              onSeedChanged: (_) {},
              onModeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Palette / brightness labels are visible
      expect(find.text('Accent Color'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
    });

    testWidgets('tapping a swatch invokes onSeedChanged', (tester) async {
      Color? picked;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ThemeSection(
              onSeedChanged: (c) => picked = c,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // The 'Vio' swatch has a matching tooltip; tap the first circle chip.
      // We look for Tooltip widgets with the 'Vio' label.
      final vioTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Vio',
      );
      expect(vioTooltip, findsOneWidget);
      await tester.tap(vioTooltip);
      await tester.pump();

      expect(picked, equals(VioColors.primary));
    });

    testWidgets('ThemeModeSelector shows all three modes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ThemeSection(
              onSeedChanged: (_) {},
              onModeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // SettingsPage tests
  // -------------------------------------------------------------------------

  group('SettingsPage', () {
    testWidgets('renders the Appearance section header', (tester) async {
      await tester.pumpWidget(
        _wrap(const Scaffold(body: SettingsPage())),
      );
      await tester.pump();

      expect(find.textContaining('APPEARANCE'), findsOneWidget);
    });

    testWidgets('has a back button', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsPage()));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ThemeBloc integration: changing seed propagates to ThemeData
  // -------------------------------------------------------------------------

  group('ThemeBloc → ThemeSection integration', () {
    testWidgets('ThemeSeedChanged event updates colorScheme.primary',
        (tester) async {
      final bloc = ThemeBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        BlocProvider<ThemeBloc>.value(
          value: bloc,
          child: BlocBuilder<ThemeBloc, ThemeState>(
            builder: (_, state) => MaterialApp(
              theme: state.themeData,
              home: Scaffold(
                backgroundColor: state.themeData.colorScheme.primary,
              ),
            ),
          ),
        ),
      );

      // Initial state uses VioColors.primary
      final initialPrimary = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary;

      // Dispatch a purple seed
      const purpleSeed = Color(0xFF9C27B0);
      bloc.add(const ThemeSeedChanged(purpleSeed));
      await tester.pump();

      final updatedPrimary = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary;

      expect(updatedPrimary, isNot(equals(initialPrimary)));
    });
  });
}
