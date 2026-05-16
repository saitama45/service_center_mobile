import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/rbac_tables.dart';
import 'tables/sync_tables.dart';
import 'daos/role_dao.dart';
import 'daos/permission_dao.dart';
import 'daos/module_dao.dart';
import 'daos/user_dao.dart';
import 'daos/session_dao.dart';
import 'daos/permission_matrix_dao.dart';
import 'daos/audit_log_dao.dart';
import 'daos/settings_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Roles,
    Permissions,
    Modules,
    Users,
    RoleModulePermissions,
    Sessions,
    AuditLogs,
    SyncLog,
    AppSettings,
    OfflineDtrLogs,
  ],
  daos: [
    RoleDao,
    PermissionDao,
    ModuleDao,
    UserDao,
    SessionDao,
    PermissionMatrixDao,
    AuditLogDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2; // Incremented for schema change

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Migration logic if needed
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_database.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
