import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../data/datasources/local/member_qr_cache.dart';
import '../../../data/datasources/local/totp_secret_store.dart';
import '../../../data/datasources/remote/account_remote_datasource.dart';
import '../../../database/app_database.dart';

/// Closes the signed-in member's account, then removes the copy of their data
/// this handset holds.
///
/// The order matters. The server call goes first: if it fails the account is
/// untouched and the member keeps working exactly as before. Only once the
/// server confirms closure is local state wiped, and from that point the wipe
/// must finish even if part of it throws — the account is already closed, so
/// leaving a signed-in-looking app behind would be worse than a failed clean-up.
///
/// The local user row is deleted along with everything else deliberately:
/// `LoginUseCase` falls back to an on-device bcrypt check when the network is
/// down, so a closed account whose row survived here could still sign in
/// offline.
class DeleteAccountUseCase {
  const DeleteAccountUseCase(
    this._db,
    this._secureStorage,
    this._remote,
    this._totpSecrets,
    this._memberQr,
  );

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;
  final AccountRemoteDatasource _remote;
  final TotpSecretStore _totpSecrets;
  final MemberQrCache _memberQr;

  static const String _tokenStorageKey = 'session_token';

  Future<AccountDeletionOutcome> call({
    required String userId,
    required String password,
  }) async {
    final outcome = await _remote.delete(password: password);
    if (outcome is! AccountDeleted) return outcome;

    await _wipeLocal(userId);
    return outcome;
  }

  Future<void> _wipeLocal(String userId) async {
    await _swallow(() => _db.sessionDao.invalidateAllUserSessions(userId));
    await _swallow(() => _secureStorage.delete(key: _tokenStorageKey));
    await _swallow(() => _totpSecrets.deleteSecret(userId));
    await _swallow(() => _memberQr.clear(userId));
    await _swallow(() => _db.loyaltyDao.purgeMemberData(userId));
    // Device-wide opt-in that only ever protected this account.
    await _swallow(() => _db.settingsDao.setSetting('biometric_enabled', '0'));
    await _swallow(() => _db.userDao.deleteUser(userId));
  }

  Future<void> _swallow(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // Deliberate: see the class doc — the account is already closed.
    }
  }
}
