import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// ── roles ────────────────────────────────────────────────────────────────────

class Roles extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get code => text().withLength(max: 50)();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get description => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['UNIQUE (code)'];
}

// ── permissions ───────────────────────────────────────────────────────────────

class Permissions extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get code => text().withLength(max: 50)();
  TextColumn get name => text().withLength(max: 100)();
  // category: DATA | ACTION | WORKFLOW | SYSTEM
  TextColumn get category => text().withLength(max: 20)();
  TextColumn get description => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['UNIQUE (code)'];
}

// ── modules ───────────────────────────────────────────────────────────────────

class Modules extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get code => text().withLength(max: 60)();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get parentModuleId =>
      text().nullable().references(Modules, #id)();
  TextColumn get route => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['UNIQUE (code)'];
}

// ── role_module_permissions ───────────────────────────────────────────────────

class RoleModulePermissions extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get moduleId => text().references(Modules, #id)();
  TextColumn get permissionId => text().references(Permissions, #id)();
  BoolColumn get isGranted => boolean().withDefault(const Constant(true))();
  TextColumn get grantedBy => text().nullable().references(Users, #id)();
  
  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {roleId, moduleId, permissionId}
      ];
}

// Forward reference — Users is defined in user_tables.dart
// Drift resolves cross-table references at runtime via the @DriftDatabase tables list.
// We need a lightweight forward declaration here.
class Users extends Table {
  @override
  String get tableName => 'users';
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};
  // remaining columns defined in user_tables.dart's UsersTable
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get deoId => text().nullable()();
  TextColumn get username => text().withLength(max: 80)();
  TextColumn get passwordHash => text()();
  TextColumn get fullName => text().withLength(max: 150)();
  TextColumn get email => text().nullable()();
  TextColumn get employeeId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  IntColumn get failedLoginCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  TextColumn get createdBy => text().nullable().references(Users, #id)();
  
  // Sync columns
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => ['UNIQUE (username)'];
}
