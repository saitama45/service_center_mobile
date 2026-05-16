import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../database/app_database.dart';

class SyncManager {
  SyncManager(this._db, this._apiClient);

  final AppDatabase _db;
  final ApiClient _apiClient;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Main entry point to trigger a full sync cycle (Push then Pull).
  Future<void> sync() async {
    if (_isSyncing) return;
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
    
    // 1. Upload Offline DTR Logs first
    await _uploadDtrLogs();

    // 2. Upload other tables (Conceptual example for Roles)
    final pendingRoles = await (_db.select(_db.roles)..where((t) => t.syncStatus.equals(0).not())).get();
    
    if (pendingRoles.isNotEmpty) {
      final response = await _apiClient.post('/sync/push/roles', pendingRoles.map((r) => r.toJson()).toList());
      if (response.statusCode == 200) {
        // Mark as synced locally
        for (final role in pendingRoles) {
          await (_db.update(_db.roles)..where((t) => t.id.equals(role.id))).write(const RolesCompanion(syncStatus: Value(0)));
        }
      }
    }
  }

  Future<void> _uploadDtrLogs() async {
    final pending = await (_db.select(_db.offlineDtrLogs)..where((t) => t.syncStatus.equals(0))).get();
    if (pending.isEmpty) return;

    debugPrint('Sync: Uploading ${pending.length} pending DTR logs...');

    for (final log in pending) {
      try {
        final file = File(log.photoPath);
        if (!await file.exists()) {
          debugPrint('Sync: Photo file not found for log ${log.id}, skipping...');
          continue;
        }

        final bytes = await file.readAsBytes();
        final base64Photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final response = await _apiClient.post('/api/dtr/log', {
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
          // Success: Delete local log and photo
          await (_db.delete(_db.offlineDtrLogs)..where((t) => t.id.equals(log.id))).go();
          await file.delete();
          debugPrint('Sync: DTR log ${log.id} uploaded and cleaned up.');
        }
      } catch (e) {
        debugPrint('Sync: Error uploading log ${log.id}: $e');
      }
    }
  }

  /// Pull remote changes from the server using the latest local timestamp.
  Future<void> _pullChanges() async {
    debugPrint('Sync: Pulling remote changes...');
    
    // 1. Get the latest updatedAt timestamp from our local DB
    final latestLocal = await _db.customSelect('SELECT MAX(updated_at) as last FROM roles').getSingle();
    final lastSyncStr = latestLocal.read<DateTime?>('last')?.toIso8601String() ?? '1970-01-01T00:00:00Z';

    final response = await _apiClient.get('/sync/pull?since=$lastSyncStr');
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> remoteRoles = data['roles'] ?? [];

      await _db.batch((batch) {
        for (final json in remoteRoles) {
          final role = Role.fromJson(json);
          batch.insert(_db.roles, role, mode: InsertMode.insertOrReplace);
        }
      });
    }
  }
}
