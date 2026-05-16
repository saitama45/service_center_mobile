import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/utils/token_util.dart';
import '../../../database/app_database.dart';
import '../../entities/user_entity.dart';

/// Validates the stored session token and returns the logged-in user,
/// or null if no valid session exists.
class CheckSessionUseCase {
  const CheckSessionUseCase(this._db, this._secureStorage);

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;

  static const String _tokenStorageKey = 'session_token';

  Future<UserEntity?> call() async {
    final rawToken = await _secureStorage.read(key: _tokenStorageKey);
    if (rawToken == null) return null;

    final tokenHash = TokenUtil.hashToken(rawToken);
    final session = await _db.sessionDao.findValidSession(tokenHash);
    if (session == null) {
      await _secureStorage.delete(key: _tokenStorageKey);
      return null;
    }

    final user = await _db.userDao.findById(session.userId);
    if (user == null || !user.isActive) {
      await _secureStorage.delete(key: _tokenStorageKey);
      return null;
    }

    final role = await _db.roleDao.getRoleById(user.roleId);

    return UserEntity(
      id: user.id,
      roleId: user.roleId,
      roleCode: role?.code ?? '',
      roleName: role?.name ?? '',
      deoId: user.deoId?.toString(),
      username: user.username,
      fullName: user.fullName,
      email: user.email,
      employeeId: user.employeeId,
      isActive: user.isActive,
      lastLoginAt: user.lastLoginAt,
      failedLoginCount: user.failedLoginCount,
      lockedUntil: user.lockedUntil,
      createdBy: user.createdBy,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}
