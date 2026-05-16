// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bms/core/sync/sync_manager.dart';
import 'package:bms/data/datasources/remote/api_client.dart';
import 'package:bms/data/repositories/dtr_repository.dart';
import 'package:bms/database/app_database.dart';

class _RecordedPost {
  _RecordedPost(this.path, this.body);
  final String path;
  final Map<String, dynamic> body;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(const FlutterSecureStorage());

  final List<_RecordedPost> postCalls = [];
  final List<String> getCalls = [];

  http.Response Function(String path, Map<String, dynamic> body) postHandler =
      (_, __) => http.Response('{}', 200);
  http.Response Function(String path) getHandler =
      (_) => http.Response('{}', 200);

  @override
  Future<http.Response> post(String path, dynamic body) async {
    final map = body is Map<String, dynamic>
        ? body
        : jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
    postCalls.add(_RecordedPost(path, map));
    return postHandler(path, map);
  }

  @override
  Future<http.Response> get(String path) async {
    getCalls.add(path);
    return getHandler(path);
  }
}

Future<String> _writeTempPhoto() async {
  final tempDir = await Directory.systemTemp.createTemp('sync_manager_test_');
  final file = File('${tempDir.path}/selfie.jpg');
  await file.writeAsBytes([0x89, 0x50, 0x4e, 0x47]);
  return file.path;
}

Future<void> _insertPending(
  AppDatabase db, {
  required String id,
  required DateTime capturedAt,
  required String photoPath,
  String? clientRequestId,
}) async {
  await db.into(db.offlineDtrLogs).insert(
        OfflineDtrLogsCompanion.insert(
          id: Value(id),
          clientRequestId: Value(clientRequestId ?? id),
          latitude: 14.5,
          longitude: 120.9,
          accuracy: 10,
          capturedAt: capturedAt,
          photoPath: photoPath,
          syncStatus: const Value(dtrSyncPending),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeApiClient api;
  late DtrRepository dtrRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApiClient();
    dtrRepo = DtrRepository(db, api);
  });

  tearDown(() async {
    await db.close();
  });

  test('sync() short-circuits when offline (no API calls)', () async {
    final manager = SyncManager(db, api, dtrRepo, isOnline: () async => false);
    await _insertPending(
      db,
      id: 'log-1',
      capturedAt: DateTime.utc(2026, 5, 17, 8),
      photoPath: await _writeTempPhoto(),
    );

    await manager.sync();

    expect(api.postCalls, isEmpty);
    expect(api.getCalls, isEmpty);
    final row = await (db.select(db.offlineDtrLogs)
          ..where((t) => t.id.equals('log-1')))
        .getSingle();
    expect(row.syncStatus, dtrSyncPending);
  });

  test('uploads pending logs oldest-first', () async {
    await _insertPending(db,
        id: 'newer',
        capturedAt: DateTime.utc(2026, 5, 17, 10),
        photoPath: await _writeTempPhoto());
    await _insertPending(db,
        id: 'oldest',
        capturedAt: DateTime.utc(2026, 5, 17, 6),
        photoPath: await _writeTempPhoto());
    await _insertPending(db,
        id: 'middle',
        capturedAt: DateTime.utc(2026, 5, 17, 8),
        photoPath: await _writeTempPhoto());

    final manager = SyncManager(db, api, dtrRepo, isOnline: () async => true);
    await manager.sync();

    final orderedIds = api.postCalls
        .where((c) => c.path == '/api/dtr/log')
        .map((c) => c.body['client_request_id'] as String)
        .toList();
    expect(orderedIds, ['oldest', 'middle', 'newer']);
  });

  test('422 response marks log failed with server message', () async {
    final photo = await _writeTempPhoto();
    await _insertPending(db,
        id: 'log-422',
        capturedAt: DateTime.utc(2026, 5, 17, 8),
        photoPath: photo);
    api.postHandler = (path, body) {
      if (path == '/api/dtr/log') {
        return http.Response(
            jsonEncode({'message': 'Outside vicinity'}), 422);
      }
      return http.Response('{}', 200);
    };

    final manager = SyncManager(db, api, dtrRepo, isOnline: () async => true);
    await manager.sync();

    final row = await (db.select(db.offlineDtrLogs)
          ..where((t) => t.id.equals('log-422')))
        .getSingle();
    expect(row.syncStatus, dtrSyncFailed);
    expect(row.serverMessage, 'Outside vicinity');
  });

  test('network error keeps log pending with retry message', () async {
    final photo = await _writeTempPhoto();
    await _insertPending(db,
        id: 'log-net',
        capturedAt: DateTime.utc(2026, 5, 17, 8),
        photoPath: photo);
    api.postHandler = (path, body) {
      if (path == '/api/dtr/log') {
        throw const SocketException('connection failed');
      }
      return http.Response('{}', 200);
    };

    final manager = SyncManager(db, api, dtrRepo, isOnline: () async => true);
    await manager.sync();

    final row = await (db.select(db.offlineDtrLogs)
          ..where((t) => t.id.equals('log-net')))
        .getSingle();
    expect(row.syncStatus, dtrSyncPending);
    expect(row.serverMessage, contains('retry'));
  });

  test('200 response deletes log row and triggers pull', () async {
    final photo = await _writeTempPhoto();
    await _insertPending(db,
        id: 'log-ok',
        capturedAt: DateTime.utc(2026, 5, 17, 8),
        photoPath: photo);
    api.getHandler = (path) {
      if (path.startsWith('/api/dtr/offline-bootstrap')) {
        return http.Response(
            jsonEncode({'data': {'schedules': []}}), 200);
      }
      return http.Response('{}', 200);
    };

    final manager = SyncManager(db, api, dtrRepo, isOnline: () async => true);
    await manager.sync();

    final remaining = await (db.select(db.offlineDtrLogs)
          ..where((t) => t.id.equals('log-ok')))
        .get();
    expect(remaining, isEmpty);
    expect(
      api.getCalls.any((p) => p.startsWith('/api/dtr/offline-bootstrap')),
      isTrue,
    );
  });
}
