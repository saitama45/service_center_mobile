import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

part 'permission_dao.g.dart';

@DriftAccessor(tables: [Permissions])
class PermissionDao extends DatabaseAccessor<AppDatabase>
    with _$PermissionDaoMixin {
  PermissionDao(super.db);

  Future<List<Permission>> getAllPermissions() =>
      (select(permissions)
            ..orderBy([
              (p) => OrderingTerm.asc(p.category),
              (p) => OrderingTerm.asc(p.displayOrder),
            ]))
          .get();

  Future<Permission?> getPermissionByCode(String code) =>
      (select(permissions)..where((p) => p.code.equals(code)))
          .getSingleOrNull();

  Future<int> insertPermission(PermissionsCompanion companion) =>
      into(permissions).insert(companion);
}
