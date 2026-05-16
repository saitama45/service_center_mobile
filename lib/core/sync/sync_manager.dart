import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/dtr_repository.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../database/app_database.dart';

typedef OnlineCheck = Future<bool> Function();

class SyncManager {
  SyncManager(
    this._db,
    this._apiClient,
    this._dtrRepository, {
    OnlineCheck? isOnline,
  }) : _isOnline = isOnline ?? _defaultIsOnline;

  final AppDatabase _db;
  final ApiClient _apiClient;
  final DtrRepository _dtrRepository;
  final OnlineCheck _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Main entry point to trigger a full sync cycle (Push then Pull).
  Future<void> sync() async {
    if (_isSyncing) return;

    if (!await _isOnline()) {
      debugPrint('Sync: Skipped — device is offline.');
      return;
    }

    _isSyncing = true;
    debugPrint('Sync: Starting sync cycle...');

    try {
      await _pushChanges();
      await _pullChanges();
      debugPrint('Sync: Sync cycle completed successfully.');
    } catch (e) {
      debugPrint('Sync: Sync cycle failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Push locally modified records to the server.
  Future<void> _pushChanges() async {
    debugPrint('Sync: Pushing local changes...');
    await _uploadDtrLogs();
  }

  Future<void> _uploadDtrLogs() async {
    final pending = await (_db.select(_db.offlineDtrLogs)
          ..where((t) => t.syncStatus.equals(dtrSyncPending))
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAt)]))
        .get();
    if (pending.isEmpty) return;

    debugPrint('Sync: Uploading ${pending.length} pending DTR logs...');

    for (final log in pending) {
      try {
        await (_db.update(_db.offlineDtrLogs)
              ..where((t) => t.id.equals(log.id)))
            .write(
          OfflineDtrLogsCompanion(
            syncStatus: const Value(dtrSyncSyncing),
            updatedAt: Value(DateTime.now().toUtc()),
            serverMessage: const Value(null),
          ),
        );

        final file = File(log.photoPath);
        if (!await file.exists()) {
          await _markDtrLogFailed(
              log.id, 'Selfie file is no longer available on this device.');
          debugPrint('Sync: Photo file not found for log ${log.id}.');
          continue;
        }

        final bytes = await file.readAsBytes();
        final base64Photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final response = await _apiClient.post('/api/dtr/log', {
          'client_request_id': log.clientRequestId ?? log.id,
          if (log.actionType != null) 'action_type': log.actionType,
          if (log.scheduleId != null) 'schedule_id': log.scheduleId,
          'latitude': log.latitude,
          'longitude': log.longitude,
          'location_accuracy': log.accuracy,
          'location_captured_at': log.capturedAt.toIso8601String(),
          'location_received_at': DateTime.now().toUtc().toIso8601String(),
          'location_client': 'native',
          'location_provider': Platform.isAndroid ? 'android' : 'ios',
          'photo': base64Photo,
          'device_info': log.deviceInfo ?? 'Offline Device',
          'public_ip': '',
        });

        if (response.statusCode == 200) {
          await (_db.delete(_db.offlineDtrLogs)
                ..where((t) => t.id.equals(log.id)))
              .go();
          await file.delete();
          debugPrint('Sync: DTR log ${log.id} uploaded and cleaned up.');
        } else if (response.statusCode == 422 || response.statusCode == 409) {
          await _markDtrLogFailed(
              log.id,
              _extractServerMessage(response.body) ??
                  'Server rejected this offline DTR log.');
        } else {
          await _markDtrLogPending(
              log.id,
              _extractServerMessage(response.body) ??
                  'Server error (${response.statusCode}). Will retry.');
        }
      } catch (e) {
        debugPrint('Sync: Error uploading log ${log.id}: $e');
        await _markDtrLogPending(
            log.id, 'Network error. Will retry when online.');
      }
    }
  }

  Future<void> _markDtrLogPending(String id, String message) async {
    await (_db.update(_db.offlineDtrLogs)..where((t) => t.id.equals(id))).write(
      OfflineDtrLogsCompanion(
        syncStatus: const Value(dtrSyncPending),
        serverMessage: Value(message),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _markDtrLogFailed(String id, String message) async {
    await (_db.update(_db.offlineDtrLogs)..where((t) => t.id.equals(id))).write(
      OfflineDtrLogsCompanion(
        syncStatus: const Value(dtrSyncFailed),
        serverMessage: Value(message),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  String? _extractServerMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Refresh DTR-related caches (schedules and recent attendance) from server.
  Future<void> _pullChanges() async {
    debugPrint('Sync: Pulling remote changes...');
    await _dtrRepository.refreshOfflineBootstrap();
  }
}

Future<bool> _defaultIsOnline() async {
  final results = await Connectivity().checkConnectivity();
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}
