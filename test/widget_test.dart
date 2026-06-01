import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:buleto_app/app.dart';

void main() {
  testWidgets('App boots to splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BuletoApp()));
    expect(find.text('BULETO'), findsWidgets);
  });
}
