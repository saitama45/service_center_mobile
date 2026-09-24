import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// In-app "Forgot Password": an emailed one-time code, then a new password.
///
/// ## Backend contract (ghelpdesk `PasswordResetOtpController`)
///
/// All three routes are public — the member is signed out by definition —
/// so each names the account by email.
///
/// ```
/// POST /api/password/forgot  { "email" }
///   200 { "message", "expires_in": 600, "resend_after": 30 }
///   429 { "message", "retry_after": 22 }
///
/// POST /api/password/verify  { "email", "code" }
///   200 { "verified": true }                 // checks, does not spend the code
///   410 { "message" }                        // expired, or none requested
///   422 { "message", "attempts_remaining" }
///   429 { "message" }                        // attempts exhausted
///
/// POST /api/password/reset   { "email", "code", "password", "password_confirmation" }
///   200 { "message" }                        // spends the code, signs all devices out
///   410 / 422 / 429 as /verify; a 422 with an "errors" map is a password rule
/// ```
///
/// `/forgot` answers the same for an unknown email as for a real one, so a
/// 200 does not prove the account exists — the copy says "if an account uses
/// that email".
class PasswordResetRemoteDatasource {
  const PasswordResetRemoteDatasource(this._api);

  final ApiClient _api;

  static const String forgotPath = '/api/password/forgot';
  static const String verifyPath = '/api/password/verify';
  static const String resetPath = '/api/password/reset';

  /// `/forgot` sends mail over SMTP inline — same budget as the login OTP.
  static const Duration _sendTimeout = Duration(seconds: 25);

  Future<PasswordResetResult> requestCode(String email) async {
    try {
      final response = await _api.post(
        forgotPath,
        {'email': email},
        timeout: _sendTimeout,
      );
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          return PasswordResetCodeSent(
            resendAfter:
                _durationFrom(body['resend_after'], fallbackSeconds: 30),
            validity: _durationFrom(body['expires_in'], fallbackSeconds: 600),
          );
        case 429:
          return PasswordResetThrottled(
            retryAfter: _durationFrom(body['retry_after'], fallbackSeconds: 60),
            message: body['message'] as String? ??
                'Too many code requests. Please wait a moment.',
          );
        case 422:
          return PasswordResetFailed(_firstError(body) ??
              'Enter a valid email address.');
        default:
          return PasswordResetFailed(body['message'] as String? ??
              'We could not send your code (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('PasswordReset: forgot failed: $e');
      return const PasswordResetFailed(
          'Could not connect to the server. Check your internet connection and try again.');
    }
  }

  Future<PasswordResetResult> verifyCode(String email, String code) =>
      _codeCall(verifyPath, {'email': email, 'code': code});

  Future<PasswordResetResult> resetPassword({
    required String email,
    required String code,
    required String password,
  }) =>
      _codeCall(resetPath, {
        'email': email,
        'code': code,
        'password': password,
        'password_confirmation': password,
      });

  Future<PasswordResetResult> _codeCall(
      String path, Map<String, dynamic> payload) async {
    try {
      final response = await _api.post(path, payload);
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          return const PasswordResetOk();
        case 410:
          return PasswordResetCodeExpired(body['message'] as String? ??
              'That code has expired. Request a new one.');
        case 422:
          // A field-level validation error (e.g. a weak password) carries an
          // `errors` map; a wrong code carries `attempts_remaining` instead.
          final fieldError = _firstError(body);
          if (fieldError != null) return PasswordResetFailed(fieldError);
          return PasswordResetWrongCode(
            message: body['message'] as String? ?? 'Incorrect code.',
            attemptsRemaining: _intOrNull(body['attempts_remaining']),
          );
        case 429:
          return PasswordResetCodeExpired(body['message'] as String? ??
              'Too many attempts. Request a new code.');
        default:
          return PasswordResetFailed(body['message'] as String? ??
              'Something went wrong (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('PasswordReset: $path failed: $e');
      return const PasswordResetFailed(
          'Could not connect to the server. Check your internet connection and try again.');
    }
  }

  static String? _firstError(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is! Map) return null;
    for (final messages in errors.values) {
      if (messages is List && messages.isNotEmpty) {
        return messages.first.toString();
      }
    }
    return null;
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Duration _durationFrom(Object? value, {required int fallbackSeconds}) {
    final seconds = _intOrNull(value);
    if (seconds == null || seconds <= 0) {
      return Duration(seconds: fallbackSeconds);
    }
    return Duration(seconds: seconds);
  }
}

// ── Outcomes ─────────────────────────────────────────────────────────────────

sealed class PasswordResetResult {
  const PasswordResetResult();
}

class PasswordResetCodeSent extends PasswordResetResult {
  const PasswordResetCodeSent({
    required this.resendAfter,
    required this.validity,
  });
  final Duration resendAfter;
  final Duration validity;
}

class PasswordResetOk extends PasswordResetResult {
  const PasswordResetOk();
}

class PasswordResetThrottled extends PasswordResetResult {
  const PasswordResetThrottled({required this.retryAfter, required this.message});
  final Duration retryAfter;
  final String message;
}

class PasswordResetWrongCode extends PasswordResetResult {
  const PasswordResetWrongCode({required this.message, this.attemptsRemaining});
  final String message;
  final int? attemptsRemaining;
}

/// The code is gone — expired, spent, or out of attempts. The member needs a
/// new one.
class PasswordResetCodeExpired extends PasswordResetResult {
  const PasswordResetCodeExpired(this.message);
  final String message;
}

class PasswordResetFailed extends PasswordResetResult {
  const PasswordResetFailed(this.message);
  final String message;
}
