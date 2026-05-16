import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

part 'role_dao.g.dart';

@DriftAccessor(tables: [Roles])
class RoleDao extends DatabaseAccessor<AppDatabase> with _$RoleDaoMixin {
  RoleDao(super.db);

  Future<List<Role>> getAllRoles({bool includeInactive = false}) {
    final query = select(roles);
    if (!includeInactive) {
      query.where((r) => r.isActive.equals(true));
    }
    query.orderBy([(r) => OrderingTerm.asc(r.name)]);
    return query.get();
  }

  Future<Role?> getRoleById(String id) =>
      (select(roles)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<Role?> getRoleByCode(String code) =>
      (select(roles)..where((r) => r.code.equals(code))).getSingleOrNull();

  Future<int> insertRole(RolesCompanion companion) =>
      into(roles).insert(companion);

  Future<bool> updateRole(RolesCompanion companion) async {
    final rowsAffected = await (update(roles)
          ..where((r) => r.id.equals(companion.id.value)))
        .write(companion);
    return rowsAffected > 0;
  }

  Future<int> countActiveUsersForRole(String roleId) async {
    final result = await (selectOnly(db.users)
          ..addColumns([db.users.id.count()])
          ..where(db.users.roleId.equals(roleId) &
              db.users.isActive.equals(true)))
        .getSingle();
    return result.read(db.users.id.count()) ?? 0;
  }

  Future<int> deleteRole(String id) =>
      (delete(roles)..where((r) => r.id.equals(id))).go();
}
