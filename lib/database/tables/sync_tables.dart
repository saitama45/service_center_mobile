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
