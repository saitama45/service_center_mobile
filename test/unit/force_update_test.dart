import 'dart:async';
import 'dart:convert';

import 'package:cbtl/app.dart';
import 'package:cbtl/core/utils/app_update_checker.dart';
import 'package:cbtl/database/app_database.dart';
import 'package:cbtl/presentation/providers/app_providers.dart';
import 'package:cbtl/presentation/providers/force_update_provider.dart';
import 'package:cbtl/routing/app_router.dart';
import 'package:cbtl/routing/route_names.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A release must stop the app until the member has updated, but a phone that
/// cannot reach the store must still open: the member QR has to work offline.
void main() {
  final title = 'Update required'.toUpperCase();
  const storeUrl =
      'https://play.google.com/store/apps/details?id=com.coffeebean.cbtl';

  Future<ProviderContainer> launch(
    WidgetTester tester,
    Future<String?> Function() lookup,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => 'Version 1.0.4 (9)'),
        storeUpdateLookupProvider.overrideWithValue(lookup),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CbtlApp()),
    );
    return container;
  }

  String location(ProviderContainer container) => container
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a waiting update blocks the app and every route',
      (tester) async {
    final container = await launch(tester, () async => storeUrl);
    await settle(tester);

    expect(find.text(title), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);

    for (final route in [
      RouteName.login,
      RouteName.register,
      RouteName.dashboard,
      RouteName.scan,
    ]) {
      container.read(appRouterProvider).go(route);
      await settle(tester);
      expect(location(container), RouteName.updateRequired, reason: route);
    }
  });

  testWidgets('the splash holds until the store has answered', (tester) async {
    final answer = Completer<String?>();
    final container = await launch(tester, () => answer.future);
    await settle(tester);

    expect(location(container), RouteName.splash);

    answer.complete(storeUrl);
    await settle(tester);

    expect(find.text(title), findsOneWidget);
  });

  testWidgets('no update leaves the app alone', (tester) async {
    final container = await launch(tester, () async => null);
    await settle(tester);

    expect(location(container), RouteName.login);
    expect(find.text(title), findsNothing);
  });

  testWidgets('an unreachable store never blocks the app', (tester) async {
    final container =
        await launch(tester, () async => throw Exception('no store'));
    await settle(tester);

    expect(location(container), RouteName.login);
    expect(find.text(title), findsNothing);
  });

  testWidgets('a slow store opens the app, and a late answer still blocks it',
      (tester) async {
    final answer = Completer<String?>();
    final container = await launch(tester, () => answer.future);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(location(container), RouteName.login);

    answer.complete(storeUrl);
    await settle(tester);

    expect(location(container), RouteName.updateRequired);
  });

  group('the Update Now button', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    Future<List<Map>> tapWith(
      WidgetTester tester,
      bool Function(Map arguments) answer,
    ) async {
      final calls = <Map>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        final arguments = call.arguments as Map;
        calls.add(arguments);
        return answer(arguments);
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      await launch(tester, () async => storeUrl);
      await settle(tester);
      await tester.tap(find.text('Update Now'));
      await settle(tester);
      return calls;
    }

    testWidgets('opens the store app rather than a browser', (tester) async {
      final calls = await tapWith(tester, (_) => true);

      expect(calls, hasLength(1));
      expect(calls.single['url'], storeUrl);
      expect(calls.single['universalLinksOnly'], isTrue);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('falls back to the browser with no store app', (tester) async {
      final calls = await tapWith(
        tester,
        (arguments) => arguments['universalLinksOnly'] != true,
      );

      expect(calls, hasLength(2));
      expect(calls.last['url'], storeUrl);
      expect(calls.last['universalLinksOnly'], isFalse);
    });
  });

  group('re-checking while blocked', () {
    late List<Object?> answers;
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        storeUpdateLookupProvider.overrideWithValue(() async {
          final next = answers.removeAt(0);
          if (next is Exception) throw next;
          return next as String?;
        }),
      ]);
      addTearDown(container.dispose);
    });

    Future<String?> check() async {
      await container.read(forceUpdateProvider.notifier).check();
      return container.read(forceUpdateProvider);
    }

    test('a dropped connection does not let the member through', () async {
      answers = [storeUrl, Exception('offline')];

      expect(await check(), storeUrl);
      expect(await check(), storeUrl);
    });

    test('pulling the release from the store unblocks the member', () async {
      answers = [storeUrl, null];

      expect(await check(), storeUrl);
      expect(await check(), isNull);
    });
  });

  group('App Store lookup', () {
    const appStoreUrl = 'https://apps.apple.com/ph/app/cbtl/id123?uo=4';

    String? update({
      String store = '1.0.5',
      String installed = '1.0.4',
      String os = '18.1',
      String minimumOs = '15.0',
    }) =>
        AppUpdateChecker.appStoreUpdateUrl(
          jsonEncode({
            'resultCount': 1,
            'results': [
              {
                'version': store,
                'trackViewUrl': appStoreUrl,
                'minimumOsVersion': minimumOs,
              },
            ],
          }),
          installedVersion: installed,
          osVersion: os,
        );

    test('a newer store version asks for the update', () {
      expect(update(), appStoreUrl);
    });

    test('compares numbers, not text: 1.0.10 is newer than 1.0.9', () {
      expect(update(store: '1.0.10', installed: '1.0.9'), appStoreUrl);
      expect(update(store: '1.0.9', installed: '1.0.10'), isNull);
    });

    test('the same version is up to date', () {
      expect(update(store: '1.0.4'), isNull);
    });

    test('TestFlight and App Review builds, ahead of the store, are not blocked',
        () {
      expect(update(store: '1.0.4', installed: '1.0.5'), isNull);
    });

    test('an app not on the store yet is not blocked', () {
      expect(
        AppUpdateChecker.appStoreUpdateUrl(
          '{"resultCount":0,"results":[]}',
          installedVersion: '1.0.4',
          osVersion: '18.1',
        ),
        isNull,
      );
    });

    test('a release this iOS cannot install does not lock the member out', () {
      expect(update(os: '15.8', minimumOs: '16.0'), isNull);
    });
  });
}
