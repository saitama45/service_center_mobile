import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Server-issued email one-time codes.
///
/// ## Backend contract
///
/// Both routes sit behind `auth:sanctum` — the caller is already
/// password-authenticated and `ApiClient` attaches the bearer token, so
/// neither request needs to name the member.
///
/// ```
/// POST /api/otp/send
///   200 { "destination": "j***@example.com",
///         "expires_in": 300,          // seconds the code stays valid
///         "resend_after": 30 }        // seconds before /send is allowed again
///   429 { "message": "...", "retry_after": 22 }
///
/// POST /api/otp/verify   { "code": "123456" }
///   200 { "verified": true }
///   410 { "message": "That code has expired. Request a new one." }
///   422 { "message": "Incorrect code.", "attempts_remaining": 3 }
///   429 { "message": "Too many attempts. Request a new code." }
/// ```
///
/// The server owns generation, hashing, expiry and the attempt counter. The
/// client never sees the code, which is the whole point of moving off the
/// old on-device placeholder.
///
/// **These routes do not exist on `support.tablegroup.com.ph` yet.** Until they
/// are deployed a `404` comes back, which this class reports as
/// [OtpSendUnsupported] / [OtpVerifyUnsupported] so the caller can fall back
/// rather than strand the member. See `OtpPolicy` in `auth_flow_provider.dart`.
class OtpRemoteDatasource {
  const OtpRemoteDatasource(this._api);

  final ApiClient _api;

  static const String sendPath = '/api/otp/send';
  static const String verifyPath = '/api/otp/verify';

  /// The server sends the email inline (no queue — matches the rest of this
  /// backend's Mailables), so this request genuinely waits on an SMTP round
  /// trip rather than just a database query. Gmail's TLS handshake alone can
  /// take several seconds depending on network path, so this call gets a
  /// longer budget than `ApiClient`'s default 10s.
  static const Duration _sendTimeout = Duration(seconds: 25);

  Future<OtpSendOutcome> send() async {
    try {
      final response = await _api.post(
        sendPath,
        const <String, dynamic>{},
        timeout: _sendTimeout,
      );
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
        case 201:
        case 202:
          return OtpSendAccepted(
            destination: body['destination'] as String?,
            validity: _durationFrom(body['expires_in'], fallbackSeconds: 300),
            resendAfter: _durationFrom(body['resend_after'], fallbackSeconds: 30),
          );
        case 429:
          return OtpSendThrottled(
            retryAfter:
                _durationFrom(body['retry_after'], fallbackSeconds: 60),
            message: body['message'] as String? ??
                'Too many code requests. Please wait a moment.',
          );
        case 401:
        case 403:
          return const OtpSendFailed(
              'Your sign-in expired before the code was sent. Please sign in again.');
        case 404:
        case 405:
        case 501:
          return OtpSendUnsupported(
              'This server does not offer email verification codes yet '
              '(HTTP ${response.statusCode} from $sendPath).');
        default:
          return OtpSendFailed(body['message'] as String? ??
              'We could not send your code (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('OTP: send failed: $e');
      return const OtpSendUnreachable(
          'We could not reach the server to send your code.');
    }
  }

  Future<OtpVerifyOutcome> verify(String code) async {
    try {
      final response = await _api.post(verifyPath, {'code': code});
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          // Trust the flag when present; a bare 200 also counts as success.
          final verified = body['verified'];
          if (verified is bool && !verified) {
            return OtpVerifyRejected(
              message: body['message'] as String? ?? 'Incorrect code.',
              attemptsRemaining: _intOrNull(body['attempts_remaining']),
            );
          }
          return const OtpVerifyAccepted();
        case 410:
          return OtpVerifyExpired(body['message'] as String? ??
              'That code has expired. Request a new one.');
        case 422:
          return OtpVerifyRejected(
            message: body['message'] as String? ?? 'Incorrect code.',
            attemptsRemaining: _intOrNull(body['attempts_remaining']),
          );
        case 429:
          return OtpVerifyRejected(
            message: body['message'] as String? ??
                'Too many attempts. Request a new code.',
            attemptsRemaining: 0,
          );
        case 401:
        case 403:
          return const OtpVerifyFailed(
              'Your sign-in expired before the code was checked. Please sign in again.');
        case 404:
        case 405:
        case 501:
          return OtpVerifyUnsupported(
              'This server does not offer email verification codes yet '
              '(HTTP ${response.statusCode} from $verifyPath).');
        default:
          return OtpVerifyFailed(body['message'] as String? ??
              'We could not check your code (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('OTP: verify failed: $e');
      return const OtpVerifyUnreachable(
          'We could not reach the server to check your code.');
    }
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

// ── Send outcomes ────────────────────────────────────────────────────────────

sealed class OtpSendOutcome {
  const OtpSendOutcome();
}

class OtpSendAccepted extends OtpSendOutcome {
  const OtpSendAccepted({
    this.destination,
    required this.validity,
    required this.resendAfter,
  });

  /// Masked address the server actually mailed, e.g. `j***@example.com`.
  final String? destination;
  final Duration validity;
  final Duration resendAfter;
}

class OtpSendThrottled extends OtpSendOutcome {
  const OtpSendThrottled({required this.retryAfter, required this.message});
  final Duration retryAfter;
  final String message;
}

/// The deployment has no OTP routes — a rollout gap, not a failure.
class OtpSendUnsupported extends OtpSendOutcome {
  const OtpSendUnsupported(this.reason);
  final String reason;
}

/// The network or the server was unavailable.
class OtpSendUnreachable extends OtpSendOutcome {
  const OtpSendUnreachable(this.message);
  final String message;
}

class OtpSendFailed extends OtpSendOutcome {
  const OtpSendFailed(this.message);
  final String message;
}

// ── Verify outcomes ──────────────────────────────────────────────────────────

sealed class OtpVerifyOutcome {
  const OtpVerifyOutcome();
}

class OtpVerifyAccepted extends OtpVerifyOutcome {
  const OtpVerifyAccepted();
}

class OtpVerifyRejected extends OtpVerifyOutcome {
  const OtpVerifyRejected({required this.message, this.attemptsRemaining});
  final String message;
  final int? attemptsRemaining;
}

class OtpVerifyExpired extends OtpVerifyOutcome {
  const OtpVerifyExpired(this.message);
  final String message;
}

class OtpVerifyUnsupported extends OtpVerifyOutcome {
  const OtpVerifyUnsupported(this.reason);
  final String reason;
}

class OtpVerifyUnreachable extends OtpVerifyOutcome {
  const OtpVerifyUnreachable(this.message);
  final String message;
}

class OtpVerifyFailed extends OtpVerifyOutcome {
  const OtpVerifyFailed(this.message);
  final String message;
}
