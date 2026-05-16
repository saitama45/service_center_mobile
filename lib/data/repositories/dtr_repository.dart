import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../datasources/remote/api_client.dart';
import '../../database/app_database.dart';

const int dtrSyncPending = 0;
const int dtrSyncSynced = 1;
const int dtrSyncSyncing = 2;
const int dtrSyncFailed = 3;

class DtrSubmitResult {
  const DtrSubmitResult.success({this.queued = false}) : message = null;
  const DtrSubmitResult.failure(this.message) : queued = false;

  final bool queued;
  final String? message;

  bool get isSuccess => message == null;
}

class DtrRepository {
  DtrRepository(this._db, this._apiClient);

  final AppDatabase _db;
  final ApiClient _apiClient;

  /// Refreshes the local rolling schedule/geofence cache used by offline DTR.
  Future<void> refreshOfflineBootstrap({int days = 7}) async {
    final from = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final response = await _apiClient
          .get('/api/dtr/offline-bootstrap?from=$from&days=$days');
      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      await _cacheBootstrap(body, days: days);
    } catch (e) {
      debugPrint('DtrRepository: Offline bootstrap refresh failed: $e');
    }
  }

  /// Fetches the current DtrStatus from the API, falling back to cached status.
  Future<Map<String, dynamic>?> getDtrStatus() async {
    try {
      final response = await _apiClient.get('/api/dtr/status');
      debugPrint('DtrRepository: status HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final status = jsonDecode(response.body) as Map<String, dynamic>;
        await _cacheStatus(status);
        return status;
      }
    } catch (e) {
      debugPrint('DtrRepository: Error fetching status: $e');
    }

    return _buildCachedDtrStatus();
  }

  Future<Map<String, dynamic>?> getCachedDtrStatus() {
    return _buildCachedDtrStatus();
  }

  /// Submits a DTR log. Online submissions go straight to the API; offline or
  /// network-failed submissions are queued locally and synced later.
  Future<DtrSubmitResult> submitLog({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String photoPath,
    required String deviceInfo,
    required bool isOnline,
  }) async {
    final capturedAt = DateTime.now().toUtc();
    final clientRequestId = const Uuid().v4();

    if (!isOnline) {
      return _queueOfflineLog(
        latitude,
        longitude,
        accuracy,
        photoPath,
        deviceInfo,
        capturedAt,
        clientRequestId,
      );
    }

    try {
      final response = await _apiClient.post('/api/dtr/log', {
        ...await _buildPayload(
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          photoPath: photoPath,
          deviceInfo: deviceInfo,
          capturedAt: capturedAt,
          clientRequestId: clientRequestId,
        ),
      });

      debugPrint(
          'DtrRepository: submitLog HTTP ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        return const DtrSubmitResult.success();
      }

      return DtrSubmitResult.failure(_extractServerMessage(response.body) ??
          'Server error (${response.statusCode}). Please try again.');
    } catch (e) {
      debugPrint('DtrRepository: Network error submitting log: $e');
      return _queueOfflineLog(
        latitude,
        longitude,
        accuracy,
        photoPath,
        deviceInfo,
        capturedAt,
        clientRequestId,
      );
    }
  }

  Future<DtrSubmitResult> _queueOfflineLog(
    double lat,
    double lng,
    double acc,
    String path,
    String device,
    DateTime time,
    String clientRequestId,
  ) async {
    try {
      final schedule = await _activeCachedSchedule(time);
      if (schedule == null) {
        return const DtrSubmitResult.failure(
          'No cached active schedule is available for offline DTR. Connect to the internet to refresh your schedule.',
        );
      }

      final action = await _nextOfflineAction(schedule);
      if (action == null) {
        return const DtrSubmitResult.failure(
          'This schedule is already complete or has pending Time In and Time Out logs.',
        );
      }

      await _db.into(_db.offlineDtrLogs).insert(
            OfflineDtrLogsCompanion.insert(
              clientRequestId: Value(clientRequestId),
              scheduleId: Value(schedule.id),
              actionType: Value(action),
              latitude: lat,
              longitude: lng,
              accuracy: acc,
              capturedAt: time,
              photoPath: path,
              deviceInfo: Value(device),
              syncStatus: const Value(dtrSyncPending),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      return const DtrSubmitResult.success(queued: true);
    } catch (e) {
      debugPrint('DtrRepository: Error queuing log: $e');
      return const DtrSubmitResult.failure('Failed to save log offline.');
    }
  }

  /// Fetches attendance logs. Online responses are cached; offline responses
  /// combine cached server logs with local pending/failed DTR logs.
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

      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final response = await _apiClient.get('/api/attendance/logs?$query');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _cacheAttendanceLogs(data);
        return _mergePendingLogs(data, dateFrom: dateFrom, dateTo: dateTo);
      }
    } catch (e) {
      debugPrint('DtrRepository: Error fetching logs: $e');
    }

    return _buildCachedAttendanceLogs(dateFrom: dateFrom, dateTo: dateTo);
  }

  Future<List<OfflineDtrLog>> getPendingOfflineDtrLogs() {
    return (_db.select(_db.offlineDtrLogs)
          ..where((t) => t.syncStatus
              .isIn([dtrSyncPending, dtrSyncSyncing, dtrSyncFailed]))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
        .get();
  }

  Future<Map<String, dynamic>> _buildPayload({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String photoPath,
    required String deviceInfo,
    required DateTime capturedAt,
    required String clientRequestId,
    String? actionType,
    String? scheduleId,
  }) async {
    String photoBase64 = photoPath;
    if (!photoPath.startsWith('data:image')) {
      final bytes = await File(photoPath).readAsBytes();
      photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    return {
      'client_request_id': clientRequestId,
      if (actionType != null) 'action_type': actionType,
      if (scheduleId != null) 'schedule_id': scheduleId,
      'latitude': latitude,
      'longitude': longitude,
      'location_accuracy': accuracy,
      'location_captured_at': capturedAt.toIso8601String(),
      'location_received_at': DateTime.now().toUtc().toIso8601String(),
      'location_client': 'native',
      'location_provider': Platform.isAndroid ? 'android' : 'ios',
      'photo': photoBase64,
      'device_info': deviceInfo,
      'public_ip': '',
    };
  }

  Future<void> _cacheBootstrap(Map<String, dynamic> body,
      {required int days}) async {
    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;
    final rawSchedules =
        data['schedules'] ?? data['dtrSchedules'] ?? data['items'];
    if (rawSchedules is! List) return;

    final fetchedAt = DateTime.now().toUtc();
    final validUntil = fetchedAt.add(Duration(days: days));
    await _db.batch((batch) {
      for (final item in rawSchedules) {
        if (item is! Map<String, dynamic>) continue;
        final companion = _scheduleCompanionFromJson(
          item,
          fetchedAt: fetchedAt,
          validUntil: validUntil,
        );
        if (companion != null) {
          batch.insert(_db.cachedDtrSchedules, companion,
              mode: InsertMode.insertOrReplace);
        }
      }
    });
  }

  Future<void> _cacheStatus(Map<String, dynamic> status) async {
    final schedule = status['todaySchedule'];
    if (schedule is! Map<String, dynamic>) return;

    final fetchedAt = DateTime.now().toUtc();
    final companion = _scheduleCompanionFromJson(
      schedule,
      lastLog: status['lastLog'],
      isSegmentComplete: status['isSegmentComplete'] == true,
      fetchedAt: fetchedAt,
      validUntil: fetchedAt.add(const Duration(days: 7)),
    );
    if (companion != null) {
      await _db
          .into(_db.cachedDtrSchedules)
          .insert(companion, mode: InsertMode.insertOrReplace);
    }
  }

  CachedDtrSchedulesCompanion? _scheduleCompanionFromJson(
    Map<String, dynamic> json, {
    dynamic lastLog,
    bool? isSegmentComplete,
    required DateTime fetchedAt,
    required DateTime validUntil,
  }) {
    final id = json['id']?.toString() ?? json['schedule_id']?.toString();
    final startRaw = json['start_time'] ?? json['startTime'];
    final endRaw = json['end_time'] ?? json['endTime'];
    final start = _parseDate(startRaw);
    final end = _parseDate(endRaw);
    if (id == null || start == null || end == null) return null;

    final store = json['store'] is Map<String, dynamic>
        ? json['store'] as Map<String, dynamic>
        : json['schedule_store'] is Map<String, dynamic>
            ? json['schedule_store'] as Map<String, dynamic>
            : null;

    final localLastLog = lastLog ?? json['lastLog'] ?? json['last_log'];
    return CachedDtrSchedulesCompanion.insert(
      id: id,
      userId: Value(json['user_id']?.toString()),
      status: Value(json['status']?.toString()),
      startTime: start.toUtc(),
      endTime: end.toUtc(),
      storeId: Value(store?['id']?.toString()),
      storeCode:
          Value(store?['code']?.toString() ?? store?['store_code']?.toString()),
      storeName:
          Value(store?['name']?.toString() ?? store?['store_name']?.toString()),
      storeLatitude: Value(_toDoubleOrNull(store?['latitude'])),
      storeLongitude: Value(_toDoubleOrNull(store?['longitude'])),
      radiusMeters: Value(_toDoubleOrNull(store?['radius_meters']) ?? 100),
      lastLogType: Value(_extractLastLogType(localLastLog)),
      lastLogAt: Value(_extractLastLogAt(localLastLog)),
      isSegmentComplete: Value(
        isSegmentComplete ??
            json['isSegmentComplete'] == true ||
                json['is_segment_complete'] == true,
      ),
      rawJson: jsonEncode(json),
      fetchedAt: fetchedAt,
      validUntil: validUntil,
    );
  }

  Future<Map<String, dynamic>?> _buildCachedDtrStatus() async {
    final now = DateTime.now().toUtc();
    final schedule = await _activeCachedSchedule(now);
    if (schedule == null) return null;

    final pending = await _pendingLogsForSchedule(schedule.id);
    final lastPending = pending.isEmpty ? null : pending.last;
    final lastLogType = lastPending?.actionType ?? schedule.lastLogType;
    final isComplete = schedule.isSegmentComplete ||
        lastLogType == 'time_out' &&
            pending.any((log) => log.actionType == 'time_in');

    return {
      'lastLog': lastLogType == null
          ? null
          : {
              'type': lastLogType,
              'log_time': (lastPending?.capturedAt ?? schedule.lastLogAt)
                  ?.toIso8601String(),
              'is_pending': lastPending != null,
            },
      'isSegmentComplete': isComplete,
      'assignedStores': const [],
      'totalAssignedCount': schedule.storeId == null ? 0 : 1,
      'offline': true,
      'todaySchedule': _scheduleToStatusJson(schedule),
    };
  }

  Map<String, dynamic> _scheduleToStatusJson(CachedDtrSchedule schedule) {
    return {
      'id': schedule.id,
      'status': schedule.status,
      'start_time': schedule.startTime.toIso8601String(),
      'end_time': schedule.endTime.toIso8601String(),
      'store': schedule.storeId == null
          ? null
          : {
              'id': schedule.storeId,
              'code': schedule.storeCode,
              'name': schedule.storeName,
              'latitude': schedule.storeLatitude,
              'longitude': schedule.storeLongitude,
              'radius_meters': schedule.radiusMeters ?? 100,
            },
    };
  }

  Future<CachedDtrSchedule?> _activeCachedSchedule(DateTime at) async {
    final now = at.toUtc();
    final rows = await (_db.select(_db.cachedDtrSchedules)
          ..where((t) =>
              t.startTime.isSmallerOrEqualValue(now) &
              t.endTime.isBiggerOrEqualValue(now) &
              t.validUntil.isBiggerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> _nextOfflineAction(CachedDtrSchedule schedule) async {
    if (schedule.isSegmentComplete) return null;
    final pending = await _pendingLogsForSchedule(schedule.id);
    final hasPendingIn = pending.any((log) => log.actionType == 'time_in');
    final hasPendingOut = pending.any((log) => log.actionType == 'time_out');
    if (hasPendingIn && hasPendingOut) return null;

    final lastType =
        pending.isEmpty ? schedule.lastLogType : pending.last.actionType;
    if (lastType == null || lastType == 'time_out') return 'time_in';
    return 'time_out';
  }

  Future<List<OfflineDtrLog>> _pendingLogsForSchedule(String scheduleId) {
    return (_db.select(_db.offlineDtrLogs)
          ..where((t) =>
              t.scheduleId.equals(scheduleId) &
              t.syncStatus.isIn([dtrSyncPending, dtrSyncSyncing]))
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAt)]))
        .get();
  }

  Future<void> _cacheAttendanceLogs(Map<String, dynamic> data) async {
    final logs = (data['logs']?['data'] as List? ?? []);
    final fetchedAt = DateTime.now().toUtc();

    await _db.batch((batch) {
      for (final raw in logs) {
        if (raw is! Map<String, dynamic>) continue;
        final rawId = raw['id']?.toString();
        final logTime = _parseDate(
            raw['log_time'] ?? raw['captured_at'] ?? raw['created_at']);
        if (rawId == null || logTime == null) continue;
        batch.insert(
          _db.cachedAttendanceLogs,
          CachedAttendanceLogsCompanion.insert(
            id: rawId,
            logTime: logTime.toUtc(),
            rawJson: jsonEncode(raw),
            fetchedAt: fetchedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<Map<String, dynamic>> _buildCachedAttendanceLogs({
    String? dateFrom,
    String? dateTo,
  }) async {
    final cached =
        await _cachedAttendanceRows(dateFrom: dateFrom, dateTo: dateTo);
    final data = {
      'logs': {
        'data': cached,
        'current_page': 1,
        'last_page': 1,
        'total': cached.length,
      },
      'stores': const [],
      'users': const [],
      'workHoursSummary': const [],
      'filters': {'date_from': dateFrom, 'date_to': dateTo},
      'offline': true,
    };
    return _mergePendingLogs(data, dateFrom: dateFrom, dateTo: dateTo);
  }

  Future<Map<String, dynamic>> _mergePendingLogs(
    Map<String, dynamic> data, {
    String? dateFrom,
    String? dateTo,
  }) async {
    final logs = (data['logs']?['data'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .toList();
    final pending =
        await _offlineLogsAsAttendanceRows(dateFrom: dateFrom, dateTo: dateTo);
    logs.insertAll(0, pending);
    logs.sort((a, b) {
      final aTime =
          _parseDate(a['log_time'] ?? a['captured_at'] ?? a['created_at']);
      final bTime =
          _parseDate(b['log_time'] ?? b['captured_at'] ?? b['created_at']);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    final logsMap = Map<String, dynamic>.from(data['logs'] as Map? ?? const {});
    logsMap['data'] = logs;
    logsMap['total'] = logs.length;
    return {...data, 'logs': logsMap};
  }

  Future<List<Map<String, dynamic>>> _cachedAttendanceRows({
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = _db.select(_db.cachedAttendanceLogs);
    _applyDateFilter(query, dateFrom: dateFrom, dateTo: dateTo);
    query.orderBy([(t) => OrderingTerm.desc(t.logTime)]);
    final rows = await query.get();
    return rows
        .map((row) => jsonDecode(row.rawJson) as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _offlineLogsAsAttendanceRows({
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = _db.select(_db.offlineDtrLogs)
      ..where((t) =>
          t.syncStatus.isIn([dtrSyncPending, dtrSyncSyncing, dtrSyncFailed]));
    _applyOfflineDateFilter(query, dateFrom: dateFrom, dateTo: dateTo);
    query.orderBy([(t) => OrderingTerm.desc(t.capturedAt)]);
    final logs = await query.get();

    final rows = <Map<String, dynamic>>[];
    for (final log in logs) {
      final schedule = log.scheduleId == null
          ? null
          : await (_db.select(_db.cachedDtrSchedules)
                ..where((t) => t.id.equals(log.scheduleId!)))
              .getSingleOrNull();
      rows.add({
        'id': 'offline-${log.id}',
        'type': log.actionType ?? 'time_in',
        'log_time': log.capturedAt.toIso8601String(),
        'captured_at': log.capturedAt.toIso8601String(),
        'latitude': log.latitude,
        'longitude': log.longitude,
        'photo_path': log.photoPath,
        'device_info': log.deviceInfo,
        'is_pending': log.syncStatus != dtrSyncFailed,
        'is_failed': log.syncStatus == dtrSyncFailed,
        'sync_status': log.syncStatus,
        'server_message': log.serverMessage,
        'store': schedule == null
            ? null
            : {
                'id': schedule.storeId,
                'code': schedule.storeCode,
                'name': schedule.storeName,
              },
      });
    }
    return rows;
  }

  void _applyDateFilter(
    SimpleSelectStatement<$CachedAttendanceLogsTable, CachedAttendanceLog>
        query, {
    String? dateFrom,
    String? dateTo,
  }) {
    final from = _parseLocalDateStart(dateFrom);
    final to = _parseLocalDateEnd(dateTo);
    if (from != null) {
      query.where((t) => t.logTime.isBiggerOrEqualValue(from.toUtc()));
    }
    if (to != null) {
      query.where((t) => t.logTime.isSmallerOrEqualValue(to.toUtc()));
    }
  }

  void _applyOfflineDateFilter(
    SimpleSelectStatement<$OfflineDtrLogsTable, OfflineDtrLog> query, {
    String? dateFrom,
    String? dateTo,
  }) {
    final from = _parseLocalDateStart(dateFrom);
    final to = _parseLocalDateEnd(dateTo);
    if (from != null) {
      query.where((t) => t.capturedAt.isBiggerOrEqualValue(from.toUtc()));
    }
    if (to != null) {
      query.where((t) => t.capturedAt.isSmallerOrEqualValue(to.toUtc()));
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  DateTime? _parseLocalDateStart(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  DateTime? _parseLocalDateEnd(String? value) {
    final start = _parseLocalDateStart(value);
    return start
        ?.add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String? _extractLastLogType(dynamic lastLog) {
    if (lastLog is Map<String, dynamic>) return lastLog['type']?.toString();
    return null;
  }

  DateTime? _extractLastLogAt(dynamic lastLog) {
    if (lastLog is Map<String, dynamic>) {
      return _parseDate(lastLog['log_time'] ??
              lastLog['captured_at'] ??
              lastLog['created_at'])
          ?.toUtc();
    }
    return null;
  }

  String? _extractServerMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}
