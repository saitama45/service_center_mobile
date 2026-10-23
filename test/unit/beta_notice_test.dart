import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cbtl/core/widgets/cbtl_button.dart';
import 'package:cbtl/database/app_database.dart';
import 'package:cbtl/presentation/screens/beta_notice/beta_notice.dart';

/// The closed-beta confidentiality notice: accepted once per member, only
/// with the box ticked, never dismissed by accident, Android only.
void main() {
  group('BetaNoticeStore', () {
    late AppDatabase db;
    late BetaNoticeStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = BetaNoticeStore(db.settingsDao);
    });
    tearDown(() => db.close());

    test('a member has not accepted until they do, and then stays accepted', () async {
      expect(await store.isAccepted('42'), isFalse);
      await store.accept('42');
      expect(await store.isAccepted('42'), isTrue);
    });

    test('acceptance belongs to one member, not the device', () async {
      await store.accept('42');
      expect(await store.isAccepted('43'), isFalse);
    });

    test('accepting twice keeps a single row, so it still reads as accepted', () async {
      await store.accept('42');
      await store.accept('42');
      final rows = await db.select(db.appSettings).get();
      expect(rows.where((r) => r.settingKey == BetaNoticeStore.keyFor('42')), hasLength(1));
      expect(await store.isAccepted('42'), isTrue);
    });
  });

  group('BetaNoticeDialog', () {
    Future<Future<bool>> open(WidgetTester tester) async {
      late Future<bool> result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => result = showBetaNoticeDialog(ctx),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    CbtlButton continueButton(WidgetTester tester) =>
        tester.widget<CbtlButton>(find.widgetWithText(CbtlButton, BetaNotice.continueLabel));

    testWidgets('Continue stays disabled until "I accept" is ticked', (tester) async {
      final result = await open(tester);
      expect(find.text(BetaNotice.title), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('beta-notice-accept')));
      await tester.pump();
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(find.text(BetaNotice.continueLabel));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.text(BetaNotice.title), findsNothing);
    });

    testWidgets('Sign out declines', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text(BetaNotice.declineLabel));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('neither the barrier nor Back dismisses it', (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text(BetaNotice.title), findsOneWidget);

      final dynamic app = tester.state(find.byType(WidgetsApp));
      await app.didPopRoute();
      await tester.pumpAndSettle();
      expect(find.text(BetaNotice.title), findsOneWidget);
    });
  });

  test('the notice is shown on Android only — never to App Store review', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BetaNotice.enabled, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BetaNotice.enabled, isFalse);
  });
}
