import 'package:flutter_test/flutter_test.dart';
import 'package:sports_buddy_app/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const SportsBuddyApp());
    expect(find.byType(SportsBuddyApp), findsOneWidget);
  });
}
