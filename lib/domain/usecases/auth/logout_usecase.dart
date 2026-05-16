import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/utils/token_util.dart';
import '../../../database/app_database.dart';
import '../../../database/tables/sync_tables.dart';

class LogoutUseCase {
  const LogoutUseCase(this._db, this._secureStorage);

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;

  static const String _tokenStorageKey = 'session_token';

  Future<void> call(String userId) async {
    // Invalidate session token in DB
    final rawToken = await _secureStorage.read(key: _tokenStorageKey);
    if (rawToken != null) {
      final tokenHash = TokenUtil.hashToken(rawToken);
      await _db.sessionDao.invalidateSession(tokenHash);
    }

    // Clear token from secure storage
    await _secureStorage.delete(key: _tokenStorageKey);

    // Audit log
    await _db.auditLogDao.insertLog(
      AuditLogsCompanion.insert(
        userId: Value(userId),
        actionDetail: const Value('User logged out'),
      ),
    );
  }
}
