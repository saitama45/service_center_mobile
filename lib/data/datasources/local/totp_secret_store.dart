import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds each member's authenticator-app secret in the platform keystore
/// (Android Keystore / iOS Keychain) — never in Drift, never in `app_settings`.
///
/// The secret is keyed by user id so that signing in as somebody else on a
/// shared handset cannot reuse the previous member's authenticator.
class TotpSecretStore {
  const TotpSecretStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _prefix = 'totp_secret_';
  static const String _enrolledAtPrefix = 'totp_enrolled_at_';

  static String _secretKey(String userId) => '$_prefix$userId';
  static String _enrolledAtKey(String userId) => '$_enrolledAtPrefix$userId';

  /// The base32 secret, or null when this member has not enrolled on this
  /// device. Returns null rather than throwing if the keystore is unreadable
  /// — a locked or wiped keystore must read as "not enrolled", not crash the
  /// sign-in screen.
  Future<String?> readSecret(String userId) async {
    try {
      final value = await _storage.read(key: _secretKey(userId));
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (e) {
      debugPrint('TOTP: could not read secret for $userId: $e');
      return null;
    }
  }

  Future<bool> isEnrolled(String userId) async =>
      (await readSecret(userId)) != null;

  Future<void> saveSecret(String userId, String base32Secret) async {
    await _storage.write(key: _secretKey(userId), value: base32Secret);
    await _storage.write(
      key: _enrolledAtKey(userId),
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> enrolledAt(String userId) async {
    try {
      final raw = await _storage.read(key: _enrolledAtKey(userId));
      if (raw == null) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSecret(String userId) async {
    await _storage.delete(key: _secretKey(userId));
    await _storage.delete(key: _enrolledAtKey(userId));
  }
}
