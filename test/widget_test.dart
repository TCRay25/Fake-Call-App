import 'package:flutter_test/flutter_test.dart';
import 'package:fake_call/main.dart';

void main() {
  testWidgets('ShadowCallApp initial render smoke test', (WidgetTester tester) async {
    // Build ShadowCallApp and verify header renders
    await tester.pumpWidget(const ShadowCallApp());
    expect(find.text('ShadowCall'), findsOneWidget);
    expect(find.text('Test Fake Call Now'), findsOneWidget);
  });
}
