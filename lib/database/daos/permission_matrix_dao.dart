import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

part 'permission_matrix_dao.g.dart';

/// Holds the resolved result for a single permission check.
class ResolvedPermission {
  const ResolvedPermission({
    required this.moduleCode,
    required this.permissionCode,
    required this.isGranted,
    required this.source, // 'override' | 'role' | 'default'
  });

  final String moduleCode;
  final String permissionCode;
  final bool isGranted;
  final String source;
}

@DriftAccessor(tables: [RoleModulePermissions, Modules, Permissions])
class PermissionMatrixDao extends DatabaseAccessor<AppDatabase>
    with _$PermissionMatrixDaoMixin {
  PermissionMatrixDao(super.db);

  // ── Role permission matrix ────────────────────────────────────────────────

  Future<List<RoleModulePermission>> getPermissionsForRole(String roleId) =>
      (select(roleModulePermissions)
            ..where((r) => r.roleId.equals(roleId)))
          .get();

  Future<void> setRolePermission({
    required String roleId,
    required String moduleId,
    required String permissionId,
    required bool isGranted,
    String? grantedBy,
  }) async {
    await into(roleModulePermissions).insertOnConflictUpdate(
      RoleModulePermissionsCompanion(
        roleId: Value(roleId),
        moduleId: Value(moduleId),
        permissionId: Value(permissionId),
        isGranted: Value(isGranted),
        grantedBy: Value(grantedBy),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> setRolePermissionsBatch(
      String roleId, List<RoleModulePermissionsCompanion> entries) async {
    await transaction(() async {
      // Delete existing rows first — insertAllOnConflictUpdate targets the PK
      // (auto-increment id), not the unique key (roleId, moduleId, permissionId),
      // so it would insert duplicates instead of updating existing seed rows.
      await (delete(roleModulePermissions)
            ..where((r) => r.roleId.equals(roleId)))
          .go();
      await batch((b) {
        b.insertAll(roleModulePermissions, entries);
      });
    });
  }

  Future<void> deleteRolePermission({
    required String roleId,
    required String moduleId,
    required String permissionId,
  }) async {
    await (delete(roleModulePermissions)
          ..where((r) =>
              r.roleId.equals(roleId) &
              r.moduleId.equals(moduleId) &
              r.permissionId.equals(permissionId)))
        .go();
  }

  // ── Core permission resolution ────────────────────────────────────────────

  /// Resolve ALL permissions for [userId] in one efficient query pass.
  /// Returns a flat list of [ResolvedPermission] covering every
  /// module × permission combination the user has an explicit record for.
  ///
  /// Permission resolution order:
  ///   1. role_module_permissions → role default
  ///   2. Missing row → DENIED (caller defaults to false)
  Future<List<ResolvedPermission>> resolveAllForUser(String userId) async {
    final resolved = <ResolvedPermission>[];

    // Step 1 — get user's role_id
    final user = await (select(db.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (user == null) return resolved;

    // Step 2 — collect role permissions
    final rolePerms = await (select(roleModulePermissions)
          ..where((r) => r.roleId.equals(user.roleId)))
        .get();

    for (final rp in rolePerms) {
      final module = await (select(modules)
            ..where((m) => m.id.equals(rp.moduleId)))
          .getSingleOrNull();
      final perm = await (select(permissions)
            ..where((p) => p.id.equals(rp.permissionId)))
          .getSingleOrNull();
      if (module == null || perm == null) continue;

      resolved.add(ResolvedPermission(
        moduleCode: module.code,
        permissionCode: perm.code,
        isGranted: rp.isGranted,
        source: 'role',
      ));
    }

    return resolved;
  }
}
