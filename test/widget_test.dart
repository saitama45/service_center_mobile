import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bms/app.dart';

void main() {
  testWidgets('BmsApp builds inside ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BmsApp()));
    await tester.pump();
    expect(find.byType(BmsApp), findsOneWidget);
  });
}
