import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cbtl/presentation/screens/home/widgets/coffee_stamp.dart';

/// Home's stamp grid: the first `holidaySlots` positions are Holiday slots,
/// and each region fills from its own start.
void main() {
  Future<List<CoffeeStamp>> pumpGrid(WidgetTester tester, StampGrid grid) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 320, child: grid)),
    ));
    return tester.widgetList<CoffeeStamp>(find.byType(CoffeeStamp)).toList();
  }

  testWidgets('4 Holiday + 16 regular slots, Holiday full and 2 regular',
      (tester) async {
    final slots = await pumpGrid(
      tester,
      const StampGrid(
        collected: 6,
        total: 20,
        holidaySlots: 4,
        holidayCount: 4,
        regularCount: 2,
      ),
    );

    expect(slots, hasLength(20));
    expect(slots.take(4).every((s) => s.holiday), isTrue,
        reason: 'the Holiday slots come first');
    expect(slots.skip(4).any((s) => s.holiday), isFalse);
    expect(slots.take(4).every((s) => s.filled), isTrue);
    expect(slots.skip(4).map((s) => s.filled),
        [true, true, ...List.filled(14, false)],
        reason: 'regular stamps fill from the start of the regular region');
  });

  testWidgets('regular slots fill independently of empty Holiday slots',
      (tester) async {
    // Card 2 of a Holiday overflow: one Holiday stamp, no regular yet —
    // and the reverse case, regular stamps with no Holiday ones.
    final slots = await pumpGrid(
      tester,
      const StampGrid(
        collected: 3,
        total: 20,
        holidaySlots: 4,
        holidayCount: 0,
        regularCount: 3,
      ),
    );

    expect(slots.take(4).any((s) => s.filled), isFalse);
    expect(slots.skip(4).take(3).every((s) => s.filled), isTrue);
    expect(slots.skip(7).any((s) => s.filled), isFalse);
  });

  testWidgets('without Holiday slots it is the plain card it always was',
      (tester) async {
    final slots = await pumpGrid(
      tester,
      const StampGrid(collected: 4, total: 12),
    );

    expect(slots, hasLength(12));
    expect(slots.any((s) => s.holiday), isFalse);
    expect(slots.where((s) => s.filled), hasLength(4));
    expect(slots.take(4).every((s) => s.filled), isTrue);
  });

  testWidgets('the legend names both slot kinds', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StampSlotLegend(holidaySlots: 4, regularSlots: 16)),
    ));

    expect(find.text('4 Holiday'), findsOneWidget);
    expect(find.text('16 Regular'), findsOneWidget);
  });
}
