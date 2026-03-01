import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vio_client/src/app.dart';
import 'package:vio_client/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    await tester.pumpWidget(const VioApp());
    expect(find.textContaining('Result: `Hello, Tom!`'), findsOneWidget);
  });
}
