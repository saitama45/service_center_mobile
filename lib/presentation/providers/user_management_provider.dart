import '../../database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/module_codes.dart';
import '../../core/utils/bcrypt_util.dart';
import '../../database/tables/rbac_tables.dart';
import '../../domain/entities/user_entity.dart';
import 'app_providers.dart';
import 'permission_provider.dart';

// ── User list ─────────────────────────────────────────────────────────────────

class UserListFilter {
  const UserListFilter({
    this.search = '',
    this.roleId,
    this.includeInactive = false,
    this.page = 0,
  });

  final String search;
  final String? roleId;
  final bool includeInactive;
  final int page;

  static const int pageSize = 50;

  UserListFilter copyWith({
    String? search,
    String? roleId,
    bool? includeInactive,
    int? page,
  }) => UserListFilter(
        search: search ?? this.search,
        roleId: roleId ?? this.roleId,
        includeInactive: includeInactive ?? this.includeInactive,
        page: page ?? this.page,
      );
}

final userListFilterProvider =
    StateProvider<UserListFilter>((ref) => const UserListFilter());

final userCountProvider = FutureProvider<int>((ref) async {
  final filter = ref.watch(userListFilterProvider);
  final db = ref.read(appDatabaseProvider);
  return db.userDao.countUsers(
    includeInactive: filter.includeInactive,
    search: filter.search.isEmpty ? null : filter.search,
  );
});

final userListProvider = StreamProvider<List<UserEntity>>((ref) {
  final filter = ref.watch(userListFilterProvider);
  final db = ref.read(appDatabaseProvider);

  final query = db.select(db.users).join([
    leftOuterJoin(db.roles, db.roles.id.equalsExp(db.users.roleId)),
  ]);

  if (!filter.includeInactive) {
    query.where(db.users.isActive.equals(true));
  }
  if (filter.roleId != null) {
    query.where(db.users.roleId.equals(filter.roleId!));
  }
  if (filter.search.isNotEmpty) {
    query.where(db.users.fullName.like('%${filter.search}%') |
        db.users.username.like('%${filter.search}%'));
  }

  query
    ..orderBy([OrderingTerm.asc(db.users.fullName)])
    ..limit(UserListFilter.pageSize, offset: filter.page * UserListFilter.pageSize);

  return query.watch().map((rows) {
    return rows.map((row) {
      final u = row.readTable(db.users);
      final role = row.readTableOrNull(db.roles);
      return UserEntity(
        id: u.id,
        roleId: u.roleId,
        roleCode: role?.code ?? '',
        roleName: role?.name ?? '',
        deoId: u.deoId?.toString(),
        username: u.username,
        fullName: u.fullName,
        email: u.email,
        employeeId: u.employeeId,
        isActive: u.isActive,
        lastLoginAt: u.lastLoginAt,
        failedLoginCount: u.failedLoginCount,
        lockedUntil: u.lockedUntil,
        createdBy: u.createdBy,
        createdAt: u.createdAt,
        updatedAt: u.updatedAt,
      );
    }).toList();
  });
});

// ── User CRUD operations ──────────────────────────────────────────────────────

class UserManagementNotifier extends StateNotifier<AsyncValue<void>> {
  UserManagementNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createUser({
    required String roleId,
    required String username,
    required String password,
    required String fullName,
    String? deoId,
    String? email,
    String? employeeId,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      final hash = BcryptUtil.hash(password);
      final userId = await db.userDao.insertUser(
        UsersCompanion.insert(
          roleId: roleId,
          username: username.trim(),
          passwordHash: hash,
          fullName: fullName.trim(),
          deoId: Value(deoId),
          email: Value(email),
          employeeId: Value(employeeId),
          createdBy: Value(createdBy),
        ),
      );
      await db.auditLogDao.logAction(
        userId: createdBy,
        moduleCode: ModuleCodes.userManagement,
        actionDetail: 'Created user: $username (id=$userId)',
        targetTable: 'users',
        targetId: userId.toString(),
      );
      _ref.invalidate(userListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateUser({
    required String userId,
    required String roleId,
    required String fullName,
    String? deoId,
    String? email,
    String? employeeId,
    required bool isActive,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      await db.userDao.updateUser(
        UsersCompanion(
          id: Value(userId),
          roleId: Value(roleId),
          fullName: Value(fullName.trim()),
          deoId: Value(deoId),
          email: Value(email),
          employeeId: Value(employeeId),
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await db.auditLogDao.logAction(
        userId: updatedBy,
        moduleCode: ModuleCodes.userManagement,
        actionDetail: 'Updated user id=$userId',
        targetTable: 'users',
        targetId: userId,
      );
      _ref.invalidate(userListProvider);
      // If the updated user is the current user, invalidate permissions
      _ref.invalidate(userPermissionsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deactivateUser(String userId, String byUserId) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      await db.userDao.updateUser(
        UsersCompanion(
          id: Value(userId),
          isActive: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await db.sessionDao.invalidateAllUserSessions(userId);
      await db.auditLogDao.logAction(
        userId: byUserId,
        moduleCode: ModuleCodes.userManagement,
        actionDetail: 'Deactivated user id=$userId',
        targetTable: 'users',
        targetId: userId,
      );
      _ref.invalidate(userListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteUser(String userId, String byUserId) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      final user = await db.userDao.findById(userId);
      await db.userDao.deleteUser(userId);
      await db.auditLogDao.logAction(
        userId: byUserId,
        moduleCode: ModuleCodes.userManagement,
        actionDetail: 'Deleted user: ${user?.username} (id=$userId)',
        targetTable: 'users',
        targetId: userId,
      );
      _ref.invalidate(userListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> resetUserPassword(
      String userId, String newPassword, String byUserId) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(appDatabaseProvider);
      final hash = BcryptUtil.hash(newPassword);
      await db.userDao.updatePassword(userId, hash);
      await db.sessionDao.invalidateAllUserSessions(userId);
      await db.auditLogDao.logAction(
        userId: byUserId,
        moduleCode: ModuleCodes.userManagement,
        actionDetail: 'Reset password for user id=$userId',
        targetTable: 'users',
        targetId: userId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final userManagementProvider =
    StateNotifierProvider<UserManagementNotifier, AsyncValue<void>>((ref) {
  return UserManagementNotifier(ref);
});
