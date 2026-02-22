import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/core/core.dart';
import 'package:vio_client/src/features/canvas/presentation/widgets/canvas_status_widgets.dart';

void main() {
  group('CanvasCoordinatesDisplay', () {
    testWidgets('renders coordinates when pointer is available',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanvasCoordinatesDisplay(
              pointer: Offset(10.4, 20.6),
            ),
          ),
        ),
      );

      expect(find.text('X: 10  Y: 21'), findsOneWidget);
    });

    testWidgets('renders nothing when pointer is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanvasCoordinatesDisplay(pointer: null),
          ),
        ),
      );

      expect(find.textContaining('X:'), findsNothing);
    });
  });

  group('CanvasSyncStatusIndicator', () {
    testWidgets('is hidden for idle status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanvasSyncStatusIndicator(syncStatus: SyncStatus.idle),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsNothing);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('shows spinner while syncing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanvasSyncStatusIndicator(syncStatus: SyncStatus.syncing),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Syncing...'), findsOneWidget);
    });

    testWidgets('shows synced label when synced', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanvasSyncStatusIndicator(syncStatus: SyncStatus.synced),
          ),
        ),
      );

      expect(find.text('Synced'), findsOneWidget);
    });
  });
}
