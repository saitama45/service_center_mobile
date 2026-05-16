import '../../../database/app_database.dart';
import '../../entities/permission_cache.dart';

/// The single source of truth for permission resolution.
///
/// Implements three-step resolution:
///   1. user_module_permission_overrides (not expired) → STOP
///   2. role_module_permissions for user's role → STOP
///   3. Default → DENIED (false)
///
/// Builds a complete [PermissionCache] for [userId] in one pass.
/// All screens, guards, and gates must read from this cache — never
/// query individual permissions directly.
class ResolvePermissionUseCase {
  const ResolvePermissionUseCase(this._db);

  final AppDatabase _db;

  Future<PermissionCache> call(String userId) async {
    final resolved =
        await _db.permissionMatrixDao.resolveAllForUser(userId);
    return PermissionCache.fromResolved(resolved);
  }
}
