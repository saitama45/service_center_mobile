// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bms/data/datasources/remote/api_client.dart';
import 'package:bms/data/repositories/dtr_repository.dart';
import 'package:bms/database/app_database.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(const FlutterSecureStorage());

  http.Response Function(String path) getHandler =
      (_) => http.Response('{}', 200);

  @override
  Future<http.Response> get(String path) async => getHandler(path);

  @override
  Future<http.Response> post(String path, dynamic body) async =>
      http.Response('{}', 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeApiClient api;
  late DtrRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApiClient();
    repo = DtrRepository(db, api);
  });

  tearDown(() async => db.close());

  test('refreshOfflineBootstrap caches schedules', () async {
    final now = DateTime.now().toUtc();
    final schedule = {
      'id': 'sched-1',
      'user_id': 'user-1',
      'status': 'active',
      'start_time': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'end_time': now.add(const Duration(hours: 8)).toIso8601String(),
      'store': {
        'id': 'store-1',
        'code': 'STR1',
        'name': 'Store One',
        'latitude': 14.5,
        'longitude': 120.9,
        'radius_meters': 100,
      },
    };
    api.getHandler = (path) {
      expect(path, startsWith('/api/dtr/offline-bootstrap'));
      expect(path, contains('days=7'));
      return http.Response(
        jsonEncode({
          'data': {'schedules': [schedule]}
        }),
        200,
      );
    };

    await repo.refreshOfflineBootstrap();

    final rows = await db.select(db.cachedDtrSchedules).get();
    expect(rows, hasLength(1));
    expect(rows.first.id, 'sched-1');
    expect(rows.first.storeName, 'Store One');
  });

  test('getDtrStatus falls back to cached schedule when API throws', () async {
    final now = DateTime.now().toUtc();
    final schedule = {
      'id': 'sched-cached',
      'status': 'active',
      'start_time': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'end_time': now.add(const Duration(hours: 8)).toIso8601String(),
      'store': {
        'id': 'store-1',
        'name': 'Cached Store',
        'latitude': 14.5,
        'longitude': 120.9,
        'radius_meters': 100,
      },
    };
    api.getHandler = (path) {
      if (path.startsWith('/api/dtr/offline-bootstrap')) {
        return http.Response(
          jsonEncode({
            'data': {'schedules': [schedule]}
          }),
          200,
        );
      }
      throw Exception('network down');
    };
    await repo.refreshOfflineBootstrap();

    final status = await repo.getDtrStatus();

    expect(status, isNotNull);
    expect(status!['offline'], isTrue);
    expect(status['todaySchedule']['id'], 'sched-cached');
  });

  test('getDtrStatus returns null when no cached schedule and API throws',
      () async {
    api.getHandler = (path) => throw Exception('network down');
    expect(await repo.getDtrStatus(), isNull);
  });
}
