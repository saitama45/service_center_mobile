import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  Future<User?> findByUsername(String username) async {
    try {
      return await (select(users)..where((u) => u.username.equals(username)))
          .getSingleOrNull();
    } catch (e) {
      debugPrint('UserDao: Error mapping user "$username": $e');
      return null;
    }
  }

  Future<void> upsertUser(User user) async {
    await into(users).insertOnConflictUpdate(user);
  }

  /// Stores the server's copy of a signed-in user, keyed by `username` (their
  /// email) — the identity the server treats as stable.
  ///
  /// `users.id` is NOT stable across accounts: staff can delete a member in
  /// ghelpdesk (User Management, plus Stamps -> Customers) and the member can
  /// sign up again with the same email, and the server hands back a brand-new
  /// id. `insertOnConflictUpdate` resolves conflicts on the primary key only,
  /// so that second sign-up hit `UNIQUE (username)` and threw — surfacing to
  /// the member as "Could not connect to the server" even though the account
  /// had just been created. Re-point the existing row at the new id first, so
  /// one login keeps exactly one local row.
  ///
  /// Returns the id that was replaced, or null when nothing was re-keyed. Rows
  /// that referenced the old id (sessions, cached cards) belong to the account
  /// that no longer exists — the caller invalidates the sessions, and the rest
  /// is re-pulled from the server for the new identity.
  Future<String?> upsertUserForLogin(User user) async {
    return transaction(() async {
      final existing = await (select(users)
            ..where((u) => u.username.equals(user.username)))
          .getSingleOrNull();

      final replacedId =
          existing != null && existing.id != user.id ? existing.id : null;

      if (replacedId != null) {
        await (update(users)..where((u) => u.id.equals(replacedId)))
            .write(UsersCompanion(id: Value(user.id)));
      }

      await into(users).insertOnConflictUpdate(user);

      return replacedId;
    });
  }

  Future<User?> findById(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<List<User>> getAllUsers({
    bool includeInactive = false,
    String? roleId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(users);
    if (!includeInactive) {
      query.where((u) => u.isActive.equals(true));
    }
    if (roleId != null) {
      query.where((u) => u.roleId.equals(roleId));
    }
    if (search != null && search.isNotEmpty) {
      query.where((u) =>
          u.fullName.like('%$search%') | u.username.like('%$search%'));
    }
    query
      ..orderBy([(u) => OrderingTerm.asc(u.fullName)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<int> countUsers({
    bool includeInactive = false,
    String? search,
  }) async {
    final query = select(users);
    if (!includeInactive) query.where((u) => u.isActive.equals(true));
    if (search != null && search.isNotEmpty) {
      query.where((u) =>
          u.fullName.like('%$search%') | u.username.like('%$search%'));
    }
    final rows = await query.get();
    return rows.length;
  }

  Future<int> insertUser(UsersCompanion companion) =>
      into(users).insert(companion);

  Future<bool> updateUser(UsersCompanion companion) async {
    final count = await (update(users)
          ..where((u) => u.id.equals(companion.id.value)))
        .write(companion);
    return count > 0;
  }

  /// Increment failed login count; optionally set lockout.
  Future<void> updateLoginFailure(
      String userId, int newCount, DateTime? lockUntil) async {
    await (update(users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        failedLoginCount: Value(newCount),
        lockedUntil: Value(lockUntil),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Reset failed login count and clear lockout after successful login.
  Future<void> resetLoginFailures(String userId) async {
    await (update(users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        failedLoginCount: const Value(0),
        lockedUntil: const Value(null),
        lastLoginAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updatePassword(String userId, String passwordHash) async {
    await (update(users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        passwordHash: Value(passwordHash),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<int> deleteUser(String id) =>
      (delete(users)..where((u) => u.id.equals(id))).go();
}
