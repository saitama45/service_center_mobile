import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cbtl/app.dart';

void main() {
  testWidgets('CbtlApp builds inside ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CbtlApp()));
    await tester.pump();
    expect(find.byType(CbtlApp), findsOneWidget);
  });
}
