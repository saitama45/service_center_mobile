import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Caches the last successfully fetched member QR code per user, so the "My
/// Member Code" screen still has something to show offline — the code is
/// static (see `LoyaltyMemberRemoteDatasource`), so a stale cached copy is
/// exactly as valid as a freshly fetched one until it's explicitly rotated
/// server-side (not currently a feature).
///
/// Keyed by user id, same reasoning as `TotpSecretStore`: a shared handset
/// signing in as somebody else must never show the previous member's code.
class MemberQrCache {
  const MemberQrCache(this._storage);

  final FlutterSecureStorage _storage;

  static const String _prefix = 'member_qr_';

  static String _key(String userId) => '$_prefix$userId';

  Future<String?> read(String userId) async {
    try {
      final value = await _storage.read(key: _key(userId));
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (e) {
      debugPrint('MemberQrCache: could not read cache for $userId: $e');
      return null;
    }
  }

  Future<void> save(String userId, String token) async {
    try {
      await _storage.write(key: _key(userId), value: token);
    } catch (e) {
      debugPrint('MemberQrCache: could not save cache for $userId: $e');
    }
  }
}
