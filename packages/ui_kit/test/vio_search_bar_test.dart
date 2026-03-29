import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

void main() {
  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('VioSearchBar', () {
    testWidgets('shows hint text', (tester) async {
      await tester.pumpWidget(
        buildSubject(const VioSearchBar(hintText: 'Search workspace...')),
      );

      expect(find.text('Search workspace...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows clear button when query is non-empty', (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildSubject(VioSearchBar(hintText: 'Search', controller: controller)),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('clear button clears controller text', (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildSubject(VioSearchBar(hintText: 'Search', controller: controller)),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('alwaysShowClearButton keeps clear visible while empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const VioSearchBar(hintText: 'Search', alwaysShowClearButton: true),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
