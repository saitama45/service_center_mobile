import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/rbac_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/loyalty_tables.dart';
import 'daos/role_dao.dart';
import 'daos/permission_dao.dart';
import 'daos/module_dao.dart';
import 'daos/user_dao.dart';
import 'daos/session_dao.dart';
import 'daos/permission_matrix_dao.dart';
import 'daos/audit_log_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/loyalty_dao.dart';

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
    Products,
    Campaigns,
    StampCards,
    LoyaltyTransactions,
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
    LoyaltyDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v4 replaced the DTR/attendance tables with the loyalty schema.
          // The old tables carried only cached server data and a local upload
          // queue, so dropping them loses nothing that isn't re-derivable.
          if (from < 4) {
            for (final legacy in const [
              'offline_dtr_logs',
              'cached_dtr_schedules',
              'cached_attendance_logs',
            ]) {
              await m.database.customStatement('DROP TABLE IF EXISTS $legacy');
            }
            await m.createTable(products);
            await m.createTable(campaigns);
            await m.createTable(stampCards);
            await m.createTable(loyaltyTransactions);
          }
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
