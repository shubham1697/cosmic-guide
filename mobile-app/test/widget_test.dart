import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_guide/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CosmicGuideApp());
    await tester.pumpAndSettle();
    expect(find.text('CosmicGuide'), findsOneWidget);
  });
}
