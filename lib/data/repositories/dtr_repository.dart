import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../../core/errors/failures.dart';
import '../datasources/remote/api_client.dart';
import '../../database/app_database.dart';

class DtrRepository {
  DtrRepository(this._db, this._apiClient);

  final AppDatabase _db;
  final ApiClient _apiClient;

  /// Fetches the current DtrStatus from the API.
  Future<Map<String, dynamic>?> getDtrStatus() async {
    try {
      final response = await _apiClient.get('/api/dtr/status');
      debugPrint('DtrRepository: status HTTP ${response.statusCode}');
      debugPrint('DtrRepository: status body: ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('DtrRepository: Error fetching status: $e');
      return null;
    }
  }

  /// Submits a DTR log. Returns null on success, or an error message string on failure.
  Future<String?> submitLog({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String photoPath,
    required String deviceInfo,
    required bool isOnline,
  }) async {
    final capturedAt = DateTime.now().toUtc();

    if (!isOnline) {
      final queued = await _queueOfflineLog(latitude, longitude, accuracy, photoPath, deviceInfo, capturedAt);
      return queued ? null : 'Failed to save log offline.';
    }

    try {
      String photoBase64 = photoPath;
      if (!photoPath.startsWith('data:image')) {
        final bytes = await File(photoPath).readAsBytes();
        photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final response = await _apiClient.post('/api/dtr/log', {
        'latitude': latitude,
        'longitude': longitude,
        'location_accuracy': accuracy,
        'location_captured_at': capturedAt.toIso8601String(),
        'location_received_at': DateTime.now().toUtc().toIso8601String(),
        'location_client': 'native',
        'location_provider': 'capacitor',
        'photo': photoBase64,
        'device_info': deviceInfo,
        'public_ip': '',
      });

      debugPrint('DtrRepository: submitLog HTTP ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        return null; // success
      }

      // Parse server error message if available
      String? serverMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        serverMessage = body['message'] as String?;
      } catch (_) {}
      return serverMessage ?? 'Server error (${response.statusCode}). Please try again.';
    } catch (e) {
      debugPrint('DtrRepository: Network error submitting log: $e');
      final queued = await _queueOfflineLog(latitude, longitude, accuracy, photoPath, deviceInfo, capturedAt);
      return queued ? null : 'Network error. Could not save log.';
    }
  }

  Future<bool> _queueOfflineLog(
    double lat, double lng, double acc, String path, String device, DateTime time
  ) async {
    try {
      await _db.into(_db.offlineDtrLogs).insert(
        OfflineDtrLogsCompanion.insert(
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          capturedAt: time,
          photoPath: path,
          deviceInfo: Value(device),
          syncStatus: const Value(0),
        )
      );
      return true;
    } catch (e) {
      debugPrint('DtrRepository: Error queuing log: $e');
      return false;
    }
  }

  /// Fetches attendance logs.
  Future<Map<String, dynamic>?> getAttendanceLogs({
    int page = 1,
    String? search,
    String? subUnit,
    String? storeId,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final params = <String, String>{'page': '$page'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (subUnit != null && subUnit.isNotEmpty) params['sub_unit'] = subUnit;
      if (storeId != null && storeId.isNotEmpty) params['store_id'] = storeId;
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null) params['date_to'] = dateTo;

      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final response = await _apiClient.get('/api/attendance/logs?$query');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('DtrRepository: Error fetching logs: $e');
      return null;
    }
  }
}
