import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 4648 base32 — the encoding every authenticator app expects for a
/// shared secret. Uppercase alphabet, padding accepted on decode but never
/// produced on encode (Google Authenticator dislikes `=` in `otpauth://`).
abstract class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xFF);
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) {
      out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    }
    return out.toString();
  }

  /// Tolerates the spaces and dashes people introduce when they retype a key
  /// by hand, plus `=` padding. Throws [FormatException] on anything else.
  static Uint8List decode(String input) {
    final cleaned =
        input.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (var i = 0; i < cleaned.length; i++) {
      final index = _alphabet.indexOf(cleaned[i]);
      if (index < 0) {
        throw FormatException('Not a base32 character: "${cleaned[i]}"');
      }
      buffer = (buffer << 5) | index;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }
    return Uint8List.fromList(out);
  }
}

/// RFC 6238 time-based one-time passwords, HMAC-SHA1 / 6 digits / 30 seconds
/// — the defaults Google Authenticator, Authy and Microsoft Authenticator all
/// assume when they are handed a bare `otpauth://totp/` URI.
///
/// This is the **offline** verification path. The code is checked against a
/// secret held in the platform keystore, so it needs no network — but it is
/// therefore only as strong as the device's secure storage. The online path
/// (a server-issued code emailed to the member) is the stronger factor; see
/// `OtpRemoteDatasource`.
abstract class TotpUtil {
  static const int digits = 6;
  static const Duration period = Duration(seconds: 30);

  /// How many steps either side of "now" still count, to absorb clock drift
  /// between the phone and the authenticator. 1 → a ±30s tolerance.
  static const int defaultWindow = 1;

  static final Random _rand = Random.secure();

  /// A fresh 160-bit secret, base32-encoded. 20 bytes is what RFC 4226
  /// recommends for HMAC-SHA1 and what authenticator apps expect.
  static String generateSecret({int byteLength = 20}) {
    final bytes =
        Uint8List.fromList(List.generate(byteLength, (_) => _rand.nextInt(256)));
    return Base32.encode(bytes);
  }

  /// The code for the time step containing [at] (defaults to now).
  static String codeFor(String base32Secret, {DateTime? at}) {
    final moment = at ?? DateTime.now();
    final counter =
        moment.millisecondsSinceEpoch ~/ 1000 ~/ period.inSeconds;
    return codeForCounter(Base32.decode(base32Secret), counter);
  }

  /// HOTP (RFC 4226) — the primitive TOTP is built on.
  static String codeForCounter(Uint8List key, int counter) {
    final message = Uint8List(8);
    var remaining = counter;
    for (var i = 7; i >= 0; i--) {
      message[i] = remaining & 0xFF;
      remaining >>= 8;
    }

    final digest = Hmac(sha1, key).convert(message).bytes;

    // Dynamic truncation: the low nibble of the last byte picks the window.
    final offset = digest[digest.length - 1] & 0x0F;
    final binary = ((digest[offset] & 0x7F) << 24) |
        ((digest[offset + 1] & 0xFF) << 16) |
        ((digest[offset + 2] & 0xFF) << 8) |
        (digest[offset + 3] & 0xFF);

    final modulus = pow(10, digits).toInt();
    return (binary % modulus).toString().padLeft(digits, '0');
  }

  /// True when [entered] matches the current step or one within [window].
  ///
  /// Returns false rather than throwing on a malformed secret — a corrupt
  /// keystore entry should read as "wrong code", not crash the sign-in.
  static bool verify(
    String base32Secret,
    String entered, {
    DateTime? at,
    int window = defaultWindow,
  }) {
    final normalised = entered.replaceAll(RegExp(r'\D'), '');
    if (normalised.length != digits) return false;

    final Uint8List key;
    try {
      key = Base32.decode(base32Secret);
    } on FormatException {
      return false;
    }
    if (key.isEmpty) return false;

    final moment = at ?? DateTime.now();
    final counter =
        moment.millisecondsSinceEpoch ~/ 1000 ~/ period.inSeconds;

    // Check every candidate step even after a hit, so the time taken does not
    // leak which step matched.
    var matched = false;
    for (var drift = -window; drift <= window; drift++) {
      if (_constantTimeEquals(
          codeForCounter(key, counter + drift), normalised)) {
        matched = true;
      }
    }
    return matched;
  }

  /// Seconds until the current code rolls over — drives the countdown ring.
  static int secondsRemaining({DateTime? at}) {
    final seconds = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return period.inSeconds - (seconds % period.inSeconds);
  }

  /// The `otpauth://` URI an authenticator app scans.
  ///
  /// [issuer] and [account] are percent-encoded; the label keeps the
  /// conventional `Issuer:account` form so apps group entries correctly.
  static String provisioningUri({
    required String base32Secret,
    required String account,
    required String issuer,
  }) {
    final label = Uri.encodeComponent('$issuer:$account');
    final query = <String, String>{
      'secret': base32Secret,
      'issuer': issuer,
      'algorithm': 'SHA1',
      'digits': '$digits',
      'period': '${period.inSeconds}',
    }
        .entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'otpauth://totp/$label?$query';
  }

  /// Groups the secret into 4-character blocks for the "can't scan?" panel.
  static String formatSecretForDisplay(String base32Secret) {
    final chunks = <String>[];
    for (var i = 0; i < base32Secret.length; i += 4) {
      chunks.add(base32Secret.substring(
          i, min(i + 4, base32Secret.length)));
    }
    return chunks.join(' ');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
