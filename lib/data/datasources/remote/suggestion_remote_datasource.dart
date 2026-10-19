import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Profile → Suggestion Box: a member's free-text message to the team.
///
/// ## Backend contract
///
/// ```
/// POST /api/loyalty/suggestions   { "subject": "...", "message": "..." }   (auth:sanctum)
///   201 { "id": 12, "message": "Thank you! Your message has been sent." }
///   422 { "message": "...", "errors": { "message": ["..."] } }
///   429 { "message": "..." }                                throttle:5,1
/// ```
///
/// `subject` is optional (max 120), `message` is required (max 2000). Staff
/// read what arrives on the web console's Stamps → Suggestions tab. Nothing is
/// queued offline: the member is still on the screen with their text, so a
/// failure is reported and they send again.
class SuggestionRemoteDatasource {
  const SuggestionRemoteDatasource(this._api);

  final ApiClient _api;

  static const String path = '/api/loyalty/suggestions';
  static const int maxSubjectLength = 120;
  static const int maxMessageLength = 2000;

  Future<SuggestionOutcome> send({
    String? subject,
    required String message,
  }) async {
    final trimmedSubject = subject?.trim() ?? '';

    try {
      final response = await _api.post(path, {
        if (trimmedSubject.isNotEmpty) 'subject': trimmedSubject,
        'message': message.trim(),
      });
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
        case 201:
          return const SuggestionSent();
        case 401:
          return const SuggestionFailed(
              'Your sign-in expired. Please sign in again and retry.');
        case 422:
          return SuggestionRejected(_firstError(body) ??
              body['message'] as String? ??
              'Please check your message and try again.');
        case 429:
          return SuggestionFailed(body['message'] as String? ??
              'Too many messages. Please try again in a minute.');
        default:
          return SuggestionFailed(body['message'] as String? ??
              'We could not send your message (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('Suggestion send failed: $e');
      return const SuggestionFailed(
          'We could not reach the server. Check your connection and try again.');
    }
  }

  /// Laravel's 422 carries per-field messages under `errors`; the first one is
  /// the most specific thing to show.
  String? _firstError(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is! Map) return null;
    for (final messages in errors.values) {
      if (messages is List && messages.isNotEmpty && messages.first is String) {
        return messages.first as String;
      }
    }
    return null;
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}

sealed class SuggestionOutcome {
  const SuggestionOutcome();
}

class SuggestionSent extends SuggestionOutcome {
  const SuggestionSent();
}

/// The server refused the content (validation); the member edits and resends.
class SuggestionRejected extends SuggestionOutcome {
  const SuggestionRejected(this.message);
  final String message;
}

/// Nothing was saved — network, session or server trouble.
class SuggestionFailed extends SuggestionOutcome {
  const SuggestionFailed(this.message);
  final String message;
}
