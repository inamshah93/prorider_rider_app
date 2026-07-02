import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prorider_rider_app/main.dart';

void main() {
  testWidgets('Rider app loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RiderApp()));
    await tester.pumpAndSettle();

    expect(find.text('Velo Rider'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
