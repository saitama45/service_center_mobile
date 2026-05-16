import 'package:bcrypt/bcrypt.dart';

/// Password hashing utilities using bcrypt with cost factor 12.
/// ~300 ms on mid-range Android — only call from login / change-password flows.
class BcryptUtil {
  BcryptUtil._();

  static const int _cost = 12;

  /// Hash [plaintext] with bcrypt. Run on an isolate for non-blocking UI.
  static String hash(String plaintext) {
    final salt = BCrypt.gensalt(logRounds: _cost);
    return BCrypt.hashpw(plaintext, salt);
  }

  /// Verify [plaintext] against a bcrypt [hash]. Returns true if matching.
  static bool verify(String plaintext, String hash) {
    try {
      return BCrypt.checkpw(plaintext, hash);
    } catch (_) {
      return false;
    }
  }

  /// Basic password strength check.
  /// Requires: ≥8 chars, 1 uppercase, 1 digit, 1 special character.
  static bool isStrong(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'))) return false;
    return true;
  }
}
