import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'rbac_tables.dart';

// ── sessions ──────────────────────────────────────────────────────────────────

class Sessions extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get tokenHash => text()();
  TextColumn get deviceInfo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get invalidatedAt => dateTime().nullable()();

  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['UNIQUE (token_hash)'];
}

// ── audit_logs ────────────────────────────────────────────────────────────────

class AuditLogs extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get userId => text().nullable().references(Users, #id)();
  TextColumn get moduleId => text().nullable()();
  TextColumn get permissionId => text().nullable()();
  TextColumn get targetTable => text().nullable()();
  TextColumn get targetId => text().nullable()();
  TextColumn get actionDetail => text().nullable()();
  TextColumn get oldValueJson => text().nullable()();
  TextColumn get newValueJson => text().nullable()();
  TextColumn get ipAddress => text().nullable()();

  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ── sync_log ──────────────────────────────────────────────────────────────────

class SyncLog extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get userId => text().references(Users, #id)();
  // sync_type: FULL | INCREMENTAL | REFERENCE_DATA
  TextColumn get syncType => text().withLength(max: 20)();
  // direction: UPLOAD | DOWNLOAD | BIDIRECTIONAL
  TextColumn get direction => text().withLength(max: 20)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  // status: IN_PROGRESS | SUCCESS | FAILED | PARTIAL
  TextColumn get status => text().withLength(max: 20)();
  IntColumn get recordsSent => integer().withDefault(const Constant(0))();
  IntColumn get recordsReceived => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
}

// ── app_settings ──────────────────────────────────────────────────────────────

class AppSettings extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get userId => text().nullable().references(Users, #id)();
  TextColumn get settingKey => text().withLength(max: 100)();
  TextColumn get settingValue => text()();

  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, settingKey}
      ];
}

// ── offline_dtr_logs ──────────────────────────────────────────────────────────

class OfflineDtrLogs extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get clientRequestId => text().nullable()();
  TextColumn get scheduleId => text().nullable()();
  TextColumn get actionType => text().nullable()(); // time_in | time_out
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real()();
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get photoPath => text()(); // Local file path
  TextColumn get deviceInfo => text().nullable()();

  // 0=pending, 1=synced (usually deleted after sync), 2=syncing, 3=failed
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get serverMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientRequestId}
      ];
}

// Cached rolling schedule/geofence data used to validate DTR while offline.
class CachedDtrSchedules extends Table {
  TextColumn get id => text()(); // Server schedule id

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get userId => text().nullable()();
  TextColumn get status => text().nullable()(); // On-site | Off-site | WFH
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  TextColumn get storeId => text().nullable()();
  TextColumn get storeCode => text().nullable()();
  TextColumn get storeName => text().nullable()();
  RealColumn get storeLatitude => real().nullable()();
  RealColumn get storeLongitude => real().nullable()();
  RealColumn get radiusMeters => real().nullable()();
  TextColumn get lastLogType => text().nullable()();
  DateTimeColumn get lastLogAt => dateTime().nullable()();
  BoolColumn get isSegmentComplete =>
      boolean().withDefault(const Constant(false))();
  TextColumn get rawJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get validUntil => dateTime()();
}

// Cached server attendance rows for offline history display.
class CachedAttendanceLogs extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  DateTimeColumn get logTime => dateTime()();
  TextColumn get rawJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();
}
