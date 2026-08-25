import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Fetches the signed member QR code shown on the "My Member Code" screen,
/// and pulls back the member's real stamp progress after ghelpdesk staff
/// scan them in. The staff-facing counterpart is ghelpdesk's Stamps module
/// "Scan Customer" flow (`StampController::resolveScan` / `scanAddStamp`),
/// which verifies the signature and looks up the member. See that repo's
/// `app/Services/LoyaltyQrService.php` for the exact QR format.
///
/// Deliberately a STATIC code, not a rotating one — this is a membership
/// number (like a physical loyalty card barcode), not a one-time payment
/// authorization. Nothing sensitive leaks if it's seen: the worst case of it
/// being copied is someone else's stamp landing on the rightful member's own
/// card. The real boundary is that only ghelpdesk staff signed in with the
/// `stamps.create` permission can act on a scan at all.
///
/// ## Backend contract
///
/// ```
/// GET /api/loyalty/qr-card   (auth:sanctum)
///   200 { "token": "LCARD1:123:abcdef0123456789abcdef01" }
///   422 { "message": "This account is not linked to a loyalty member record." }
/// ```
class LoyaltyMemberRemoteDatasource {
  const LoyaltyMemberRemoteDatasource(this._api);

  final ApiClient _api;

  static const String qrCardPath = '/api/loyalty/qr-card';

  Future<MemberQrOutcome> fetchMemberQrCard() async {
    try {
      final response = await _api.get(qrCardPath);
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          final token = body['token'] as String?;
          if (token == null || token.isEmpty) {
            return const MemberQrFailed(
                'Unexpected response shape from the server.');
          }
          return MemberQrSucceeded(token);
        case 401:
        case 403:
          return const MemberQrFailed(
              'Your session expired before your member code could load.');
        case 404:
        case 501:
          return MemberQrUnsupported(
              'This server does not issue member codes yet '
              '(HTTP ${response.statusCode} from $qrCardPath).');
        case 422:
          return MemberQrFailed(
              body['message'] as String? ??
                  'This account is not linked to a loyalty member record.');
        default:
          return MemberQrFailed(
              body['message'] as String? ??
                  'Could not load your member code (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('LoyaltyMember: fetchMemberQrCard failed: $e');
      return const MemberQrUnreachable(
          'Could not reach the server to load your member code.');
    }
  }

  static const String myCardsPath = '/api/loyalty/my-cards';

  /// The member's real stamp progress, keyed by the same campaign `code`
  /// `CatalogRemoteDatasource` upserts local campaigns by — so a returned row
  /// always has a matching local campaign as long as the catalogue was
  /// pulled first (see `SyncManager._pullCatalog` running before
  /// `_pullProgress`).
  Future<MyCardsOutcome> fetchMyCards() async {
    try {
      final response = await _api.get(myCardsPath);
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          final raw = body['cards'];
          if (raw is! List) {
            return const MyCardsFailed('Unexpected response shape from the server.');
          }
          final cards = raw
              .whereType<Map<String, dynamic>>()
              .map(RemoteCardProgress.fromJson)
              .where((c) => c.code.isNotEmpty)
              .toList(growable: false);
          return MyCardsSucceeded(cards);
        case 401:
        case 403:
          return const MyCardsFailed('Your session expired before progress could sync.');
        case 404:
        case 501:
          return MyCardsUnsupported(
              'This server does not offer real stamp progress yet '
              '(HTTP ${response.statusCode} from $myCardsPath).');
        default:
          return MyCardsFailed(
              body['message'] as String? ??
                  'Could not sync your stamp progress (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('LoyaltyMember: fetchMyCards failed: $e');
      return const MyCardsUnreachable('Could not reach the server to sync your progress.');
    }
  }

  static const String myTransactionsPath = '/api/loyalty/my-transactions';

  /// The member's real earn/redeem ledger — `GET /api/loyalty/my-transactions`
  /// (ghelpdesk `LoyaltyMemberController::myTransactions`), the individual-
  /// event counterpart to [fetchMyCards]'s running totals. Without this,
  /// nothing ever populated the History screen's transaction list for a
  /// stamp a real staff scan added — `myCards` alone only moves the count.
  Future<MyTransactionsOutcome> fetchMyTransactions() async {
    try {
      final response = await _api.get(myTransactionsPath);
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          final raw = body['transactions'];
          if (raw is! List) {
            return const MyTransactionsFailed('Unexpected response shape from the server.');
          }
          final transactions = raw
              .whereType<Map<String, dynamic>>()
              .map(RemoteTransaction.fromJson)
              .where((t) => t.reference.isNotEmpty && t.campaignCode.isNotEmpty)
              .toList(growable: false);
          return MyTransactionsSucceeded(transactions);
        case 401:
        case 403:
          return const MyTransactionsFailed('Your session expired before history could sync.');
        case 404:
        case 501:
          return MyTransactionsUnsupported(
              'This server does not offer real transaction history yet '
              '(HTTP ${response.statusCode} from $myTransactionsPath).');
        default:
          return MyTransactionsFailed(
              body['message'] as String? ??
                  'Could not sync your history (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('LoyaltyMember: fetchMyTransactions failed: $e');
      return const MyTransactionsUnreachable('Could not reach the server to sync your history.');
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
}

/// One card's real progress as ghelpdesk reports it — a plain data holder,
/// independent of the local Drift `StampCard` row type.
class RemoteCardProgress {
  const RemoteCardProgress({
    required this.code,
    required this.stampsCount,
    required this.stampsRequired,
    required this.status,
  });

  final String code;
  final int stampsCount;
  final int stampsRequired;

  /// active | completed | redeemed — mirrors ghelpdesk's `stamp_cards.status`.
  final String status;

  factory RemoteCardProgress.fromJson(Map<String, dynamic> json) {
    return RemoteCardProgress(
      code: json['code'] as String? ?? '',
      stampsCount: _intOrDefault(json['stamps_count'], 0),
      stampsRequired: _intOrDefault(json['stamps_required'], 0),
      status: json['status'] as String? ?? 'active',
    );
  }

  static int _intOrDefault(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

sealed class MyCardsOutcome {
  const MyCardsOutcome();
}

class MyCardsSucceeded extends MyCardsOutcome {
  const MyCardsSucceeded(this.cards);
  final List<RemoteCardProgress> cards;
}

class MyCardsUnsupported extends MyCardsOutcome {
  const MyCardsUnsupported(this.reason);
  final String reason;
}

class MyCardsUnreachable extends MyCardsOutcome {
  const MyCardsUnreachable(this.message);
  final String message;
}

class MyCardsFailed extends MyCardsOutcome {
  const MyCardsFailed(this.message);
  final String message;
}

/// One real earn or redeem event as the server reports it — a plain data
/// holder, independent of the local Drift `LoyaltyTransaction` row type.
class RemoteTransaction {
  const RemoteTransaction({
    required this.reference,
    required this.type,
    required this.points,
    required this.campaignCode,
    this.productName,
    this.storeName,
    this.occurredAt,
  });

  /// e.g. "SE-42" (earn) / "SR-7" (redeem) — the sync key rows are upserted
  /// by, mirroring how campaigns upsert by `code`.
  final String reference;

  /// 'earn' or 'redeem' — mirrors the local `txnEarn`/`txnRedeem` constants.
  final String type;

  /// Positive for an earn, negative for a redeem (the full card's worth,
  /// not the reward item count — see the server's own doc comment).
  final int points;

  final String campaignCode;
  final String? productName;
  final String? storeName;
  final DateTime? occurredAt;

  factory RemoteTransaction.fromJson(Map<String, dynamic> json) {
    return RemoteTransaction(
      reference: json['reference'] as String? ?? '',
      type: json['type'] as String? ?? 'earn',
      points: _intOrDefault(json['points'], 0),
      campaignCode: json['campaign_code'] as String? ?? '',
      productName: json['product_name'] as String?,
      storeName: json['store_name'] as String?,
      occurredAt: _dateOrNull(json['occurred_at']),
    );
  }

  static int _intOrDefault(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

sealed class MyTransactionsOutcome {
  const MyTransactionsOutcome();
}

class MyTransactionsSucceeded extends MyTransactionsOutcome {
  const MyTransactionsSucceeded(this.transactions);
  final List<RemoteTransaction> transactions;
}

class MyTransactionsUnsupported extends MyTransactionsOutcome {
  const MyTransactionsUnsupported(this.reason);
  final String reason;
}

class MyTransactionsUnreachable extends MyTransactionsOutcome {
  const MyTransactionsUnreachable(this.message);
  final String message;
}

class MyTransactionsFailed extends MyTransactionsOutcome {
  const MyTransactionsFailed(this.message);
  final String message;
}

sealed class MemberQrOutcome {
  const MemberQrOutcome();
}

class MemberQrSucceeded extends MemberQrOutcome {
  const MemberQrSucceeded(this.token);
  final String token;
}

/// The deployment has no member-QR route — a rollout gap, not a failure.
/// Mirrors `CampaignsSyncUnsupported`'s treatment in `catalog_remote_datasource.dart`.
class MemberQrUnsupported extends MemberQrOutcome {
  const MemberQrUnsupported(this.reason);
  final String reason;
}

class MemberQrUnreachable extends MemberQrOutcome {
  const MemberQrUnreachable(this.message);
  final String message;
}

class MemberQrFailed extends MemberQrOutcome {
  const MemberQrFailed(this.message);
  final String message;
}
