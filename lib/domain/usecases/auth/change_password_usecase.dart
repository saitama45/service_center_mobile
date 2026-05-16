import 'package:drift/drift.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/bcrypt_util.dart';
import '../../../database/app_database.dart';
import '../../../database/tables/sync_tables.dart';

sealed class ChangePasswordResult {
  const ChangePasswordResult();
}

class ChangePasswordSuccess extends ChangePasswordResult {
  const ChangePasswordSuccess();
}

class ChangePasswordFailure extends ChangePasswordResult {
  const ChangePasswordFailure(this.failure);
  final Failure failure;
}

class ChangePasswordUseCase {
  const ChangePasswordUseCase(this._db);

  final AppDatabase _db;

  Future<ChangePasswordResult> call({
    required String userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // Validate match
    if (newPassword != confirmPassword) {
      return const ChangePasswordFailure(
          ValidationFailure('Passwords do not match.'));
    }

    // Validate strength
    if (!BcryptUtil.isStrong(newPassword)) {
      return const ChangePasswordFailure(ValidationFailure(
          'Password must be at least 8 characters with 1 uppercase, 1 digit, and 1 special character.'));
    }

    // Verify current password
    final user = await _db.userDao.findById(userId);
    if (user == null) {
      return const ChangePasswordFailure(
          NotFoundFailure('User not found.'));
    }

    final valid = BcryptUtil.verify(currentPassword, user.passwordHash);
    if (!valid) {
      return const ChangePasswordFailure(
          ValidationFailure('Current password is incorrect.'));
    }

    // Hash and save
    final newHash = BcryptUtil.hash(newPassword);
    await _db.userDao.updatePassword(userId, newHash);

    // Mark admin password as changed
    await _db.settingsDao.setSetting('admin_password_changed', '1');

    // Audit
    await _db.auditLogDao.insertLog(
      AuditLogsCompanion.insert(
        userId: Value(userId),
        actionDetail: const Value('Password changed'),
      ),
    );

    return const ChangePasswordSuccess();
  }
}
