import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Secure session token generation and hashing.
/// The raw token lives only in flutter_secure_storage.
/// The database only ever stores SHA-256(token).
class TokenUtil {
  TokenUtil._();

  static const int _tokenByteLength = 32; // 256-bit token

  /// Generate a cryptographically secure random token (base64url-encoded).
  static String generateSecureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(_tokenByteLength, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// SHA-256 hash of the raw token — stored in the sessions table.
  static String hashToken(String rawToken) {
    final bytes = utf8.encode(rawToken);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
