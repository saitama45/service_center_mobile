import 'package:cbtl/app.dart';
import 'package:cbtl/domain/entities/user_entity.dart';
import 'package:cbtl/database/app_database.dart';
import 'package:cbtl/presentation/providers/app_providers.dart';
import 'package:cbtl/presentation/providers/auth_provider.dart';
import 'package:cbtl/presentation/providers/force_update_provider.dart';
import 'package:cbtl/presentation/screens/beta_notice/beta_notice.dart';
import 'package:cbtl/presentation/screens/whats_new/whats_new.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// After an update, a signed-in member is told what changed, exactly once.
/// Someone who just installed the app has not updated from anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final title = "What's new".toUpperCase();
  const version = 'Version 1.0.5 (10)';
  const notes = 'A fresh look:\n- New colours\n- New fonts\nSame rewards.';

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> openWith(
    WidgetTester tester, {
    String version = version,
    String notes = notes,
  }) async {
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => version),
        releaseNotesProvider.overrideWith((ref) async => notes),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showWhatsNewIfDue(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the release version and its notes, as bullets',
      (tester) async {
    await openWith(tester);

    expect(find.text(title), findsOneWidget);
    expect(find.text(version), findsOneWidget);
    expect(find.text('A fresh look:'), findsOneWidget);
    expect(find.text('New colours'), findsOneWidget);
    expect(find.text('- New colours'), findsNothing);
  });

  testWidgets('appears once per release, and again for the next one',
      (tester) async {
    await openWith(tester);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);

    await openWith(tester);
    expect(find.text(title), findsNothing);

    await openWith(tester, version: 'Version 1.0.6 (11)');
    expect(find.text(title), findsOneWidget);
    expect(find.text('Version 1.0.6 (11)'), findsOneWidget);
  });

  testWidgets('closing the app with it open asks again', (tester) async {
    await openWith(tester);

    await openWith(tester);
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('a release with no notes shows nothing', (tester) async {
    await openWith(tester, notes: '  \n ');
    expect(find.text(title), findsNothing);
  });

  test('the changelog is really bundled with the app', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(releaseNotesProvider.future), isNotEmpty);
  });

  group('alongside the beta notice', () {
    final user = UserEntity(
      id: '42',
      roleId: 'user',
      roleCode: 'user',
      roleName: 'user',
      username: 'member',
      fullName: 'A Member',
      isActive: true,
      failedLoginCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    Future<void> enterApp(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(user),
          appVersionProvider.overrideWith((ref) async => version),
          releaseNotesProvider.overrideWith((ref) async => notes),
        ],
        child: const MaterialApp(
          home: BetaNoticeGate(child: SizedBox()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('waits behind it on Android, so they never stack',
        (tester) async {
      await enterApp(tester);

      expect(find.text(BetaNotice.title.toUpperCase()), findsOneWidget);
      expect(find.text(title), findsNothing);

      await tester.tap(find.byKey(const Key('beta-notice-accept')));
      await tester.pump();
      await tester.tap(find.text(BetaNotice.continueLabel));
      await tester.pumpAndSettle();

      expect(find.text(BetaNotice.title.toUpperCase()), findsNothing);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('appears on its own on iOS, where there is no beta notice',
        (tester) async {
      await enterApp(tester);

      expect(find.text(BetaNotice.title.toUpperCase()), findsNothing);
      expect(find.text(title), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('telling an update from a fresh install', () {
    Future<void> launch(WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => version),
        storeUpdateLookupProvider.overrideWithValue(() async => null),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const CbtlApp()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<bool?> seen(WidgetTester tester) => tester
        .runAsync(() => WhatsNewStore(db.settingsDao).isSeen(version));

    testWidgets('a fresh install is never told', (tester) async {
      await launch(tester);

      expect(await seen(tester), isTrue);
    });

    testWidgets('an existing install that updated is still to be told',
        (tester) async {
      await tester.runAsync(() async {
        await db.settingsDao.setSetting('arch_reset_v7', '13');
        await db.settingsDao.setSetting('db_initialized', '1');
      });

      await launch(tester);

      expect(await seen(tester), isFalse);
    });
  });
}
