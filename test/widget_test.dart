import 'package:flutter_test/flutter_test.dart';

import 'package:copy_lot/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CopyLotApp());
    expect(find.text('Copy-lot'), findsOneWidget);
  });
}
