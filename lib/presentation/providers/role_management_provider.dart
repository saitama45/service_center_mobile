import '../../database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/module_codes.dart';
import '../../database/tables/rbac_tables.dart';
import '../../domain/entities/role_entity.dart';
import 'app_providers.dart';
import 'permission_provider.dart';

// ── Role list ─────────────────────────────────────────────────────────────────

final roleListProvider = FutureProvider<List<RoleEntity>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final roles = await db.roleDao.getAllRoles(includeInactive: true);
  return roles
      .map((r) => RoleEntity(
            id: r.id,
            code: r.code,
            name: r.name,
            description: r.description,
            isSystem: r.isSystem,
            isActive: r.isActive,
            createdBy: r.createdBy,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ))
      .toList();
});

// ── Permission matrix for a specific role ────────────────────────────────────

final rolePermissionMatrixProvider =
    FutureProvider.family<Map<String, Map<String, bool>>, String>(
        (ref, roleId) async {
  final db = ref.read(appDatabaseProvider);
  final rmpRows = await db.permissionMatrixDao.getPermissionsForRole(roleId);
  final allModules = await db.moduleDao.getAllModules(activeOnly: false);
  final allPerms = await db.permissionDao.getAllPermissions();

  // Build lookup maps
  final moduleById = {for (final m in allModules) m.id: m};
  final permById = {for (final p in allPerms) p.id: p};

  // matrix[moduleCode][permCode] = isGranted
  // Initialize with all modules and all permissions as false
  final matrix = <String, Map<String, bool>>{};
  for (final m in allModules) {
    matrix[m.code] = {for (final p in allPerms) p.code: false};
  }

  // Overlay with actual values from DB
  for (final row in rmpRows) {
    final module = moduleById[row.moduleId];
    final perm = permById[row.permissionId];
    if (module == null || perm == null) continue;
    matrix[module.code]?[perm.code] = row.isGranted;
  }

  return matrix;
});

// ── Role CRUD ──────────────────────────────────────────────────────────────────

class RoleManagementNotifier extends StateNotifier<AsyncValue<void>> {
  RoleManagementNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createRole({
    required String code,
    required String name,
    String? description,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      final newRoleId = const Uuid().v4();
      await db.roleDao.insertRole(
        RolesCompanion.insert(
          id: Value(newRoleId),
          code: code.toUpperCase().trim(),
          name: name.trim(),
          description: Value(description),
          isSystem: const Value(false),
          isActive: const Value(true),
          createdBy: Value(createdBy),
        ),
      );
      await db.auditLogDao.logAction(
        userId: createdBy,
        moduleCode: ModuleCodes.roleManagement,
        actionDetail: 'Created role: $code (id=$newRoleId)',
        targetTable: 'roles',
        targetId: newRoleId,
      );
      _ref.invalidate(roleListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateRole({
    required String roleId,
    required String name,
    String? description,
    required bool isActive,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);

      // Protect system roles from deactivation
      final role = await db.roleDao.getRoleById(roleId);
      if (role != null && role.isSystem && !isActive) {
        throw Exception('System roles cannot be deactivated.');
      }

      // Protect roles with active users from deactivation
      if (!isActive) {
        final activeUserCount =
            await db.roleDao.countActiveUsersForRole(roleId);
        if (activeUserCount > 0) {
          throw Exception(
              'Cannot deactivate a role with $activeUserCount active user(s).');
        }
      }

      await db.roleDao.updateRole(
        RolesCompanion(
          id: Value(roleId),
          name: Value(name.trim()),
          description: Value(description),
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await db.auditLogDao.logAction(
        userId: updatedBy,
        moduleCode: ModuleCodes.roleManagement,
        actionDetail: 'Updated role id=$roleId',
        targetTable: 'roles',
        targetId: roleId,
      );
      _ref.invalidate(roleListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Save permission matrix for a role. Invalidates permission cache.
  Future<bool> savePermissionMatrix({
    required String roleId,
    required Map<String, Map<String, bool>> matrix,
    required String savedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      final allModules = await db.moduleDao.getAllModules(activeOnly: false);
      final allPerms = await db.permissionDao.getAllPermissions();
      final moduleByCode = {for (final m in allModules) m.code: m};
      final permByCode = {for (final p in allPerms) p.code: p};

      final entries = <RoleModulePermissionsCompanion>[];
      for (final moduleEntry in matrix.entries) {
        final module = moduleByCode[moduleEntry.key];
        if (module == null) continue;
        for (final permEntry in moduleEntry.value.entries) {
          final perm = permByCode[permEntry.key];
          if (perm == null) continue;
          entries.add(RoleModulePermissionsCompanion(
            roleId: Value(roleId),
            moduleId: Value(module.id),
            permissionId: Value(perm.id),
            isGranted: Value(permEntry.value),
            grantedBy: Value(savedBy),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
        }
      }

      await db.permissionMatrixDao.setRolePermissionsBatch(roleId, entries);

      await db.auditLogDao.logAction(
        userId: savedBy,
        moduleCode: ModuleCodes.roleManagement,
        actionDetail: 'Updated permission matrix for role id=$roleId',
        targetTable: 'role_module_permissions',
        targetId: roleId,
      );

      // !! Critical: invalidate permission cache so all active users see the change
      _ref.invalidate(userPermissionsProvider);
      _ref.invalidate(rolePermissionMatrixProvider(roleId));

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteRole(String roleId, String byUserId) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      final role = await db.roleDao.getRoleById(roleId);

      if (role != null && role.isSystem) {
        throw Exception('System roles cannot be deleted.');
      }

      final activeUserCount = await db.roleDao.countActiveUsersForRole(roleId);
      if (activeUserCount > 0) {
        throw Exception(
            'Cannot delete a role with $activeUserCount active user(s).');
      }

      await db.roleDao.deleteRole(roleId);
      await db.auditLogDao.logAction(
        userId: byUserId,
        moduleCode: ModuleCodes.roleManagement,
        actionDetail: 'Deleted role: ${role?.code} (id=$roleId)',
        targetTable: 'roles',
        targetId: roleId,
      );
      _ref.invalidate(roleListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final roleManagementProvider =
    StateNotifierProvider<RoleManagementNotifier, AsyncValue<void>>((ref) {
  return RoleManagementNotifier(ref);
});
