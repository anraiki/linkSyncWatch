import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncwatch/app.dart';

void main() {
  testWidgets('App renders auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SyncWatchApp()),
    );

    expect(find.text('SYNCWATCH'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
