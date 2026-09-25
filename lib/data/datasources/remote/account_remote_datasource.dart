import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Member-initiated account closure.
///
/// ## Backend contract
///
/// ```
/// DELETE /api/account   { "password": "..." }        (auth:sanctum)
///   200 { "message": "Your account has been closed." }
///   422 { "message": "That password is incorrect." }
///   403 { "message": "Staff accounts are closed by your administrator..." }
///   429 { "message": "..." }                          throttle:5,1
/// ```
///
/// The server archives the member's `users` + `customers` pair and revokes
/// every token it had issued, so the session this call was made with is dead
/// by the time the response arrives. The caller must therefore clear local
/// state unconditionally after [AccountDeleted] — there is nothing left to
/// sign out of.
///
/// Required by App Store Review Guideline 5.1.1(v): an app that creates
/// accounts must let people delete theirs from inside the app.
class AccountRemoteDatasource {
  const AccountRemoteDatasource(this._api);

  final ApiClient _api;

  static const String deletePath = '/api/account';

  Future<AccountDeletionOutcome> delete({required String password}) async {
    try {
      final response = await _api.delete(deletePath, {'password': password});
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
        case 202:
        case 204:
          return const AccountDeleted();
        case 401:
          return const AccountDeletionFailed(
              'Your sign-in expired. Please sign in again and retry.');
        case 403:
          return AccountDeletionRefused(body['message'] as String? ??
              'This account cannot be deleted from the app.');
        case 422:
          return AccountDeletionWrongPassword(
              body['message'] as String? ?? 'That password is incorrect.');
        case 429:
          return AccountDeletionFailed(body['message'] as String? ??
              'Too many attempts. Please try again later.');
        default:
          return AccountDeletionFailed(body['message'] as String? ??
              'We could not close your account (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('Account deletion request failed: $e');
      return const AccountDeletionFailed(
          'We could not reach the server. Check your connection and try again.');
    }
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

sealed class AccountDeletionOutcome {
  const AccountDeletionOutcome();
}

/// The account is closed. Local state must be wiped and the member returned
/// to the login screen.
class AccountDeleted extends AccountDeletionOutcome {
  const AccountDeleted();
}

/// Re-authentication failed; the account is untouched and the member can retry.
class AccountDeletionWrongPassword extends AccountDeletionOutcome {
  const AccountDeletionWrongPassword(this.message);
  final String message;
}

/// The server will not close this kind of account (a staff login).
class AccountDeletionRefused extends AccountDeletionOutcome {
  const AccountDeletionRefused(this.message);
  final String message;
}

class AccountDeletionFailed extends AccountDeletionOutcome {
  const AccountDeletionFailed(this.message);
  final String message;
}
