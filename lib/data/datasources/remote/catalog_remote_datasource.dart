import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// The campaign catalogue synced down from ghelpdesk's `stamp_programs`
/// table (the staff-facing Loyalty Stamps module — see
/// `docs/knowledge/Integrations.md`).
///
/// ## Backend contract
///
/// ```
/// GET /api/campaigns   (auth:sanctum)
///   200 { "campaigns": [ {
///     "code": "SP-3",                          // stable, server-derived
///     "name": "CBTL Campaign",
///     "description": "...",  | null
///     "emoji": "🍂",          | null
///     "tag": "Hot Drinks",    | null
///     "required_stamps": 12,
///     "eligible_items_description": "...",  | null   // free text, not codes
///     "reward_description": "...",          | null
///     "terms_and_conditions": "...",        | null
///     "starts_at": "2026-01-01T00:00:00+00:00",  | null
///     "ends_at": "2026-12-31T23:59:59+00:00",    | null
///     "is_active": true,
///     "display_order": 1,
///     "updated_at": "..."   | null
///   } ] }
/// ```
///
/// Strictly scoped server-side to the CBTL entity — see the doc comment on
/// ghelpdesk's `Api\CampaignsController`. A program the ghelpdesk admin
/// hasn't assigned a Company to yet simply doesn't appear here; that's
/// working as intended, not a bug to chase from this side.
class CatalogRemoteDatasource {
  const CatalogRemoteDatasource(this._api);

  final ApiClient _api;

  static const String campaignsPath = '/api/campaigns';

  Future<CampaignsSyncOutcome> fetchCampaigns() async {
    try {
      final response = await _api.get(campaignsPath);
      final body = _decode(response.body);

      switch (response.statusCode) {
        case 200:
          final raw = body['campaigns'];
          if (raw is! List) {
            return const CampaignsSyncFailed(
                'Unexpected response shape from the server.');
          }
          final campaigns = raw
              .whereType<Map<String, dynamic>>()
              .map(RemoteCampaign.fromJson)
              .toList(growable: false);
          return CampaignsSyncSucceeded(campaigns);
        case 401:
        case 403:
          return const CampaignsSyncFailed(
              'Your session expired before the catalogue could sync.');
        case 404:
        case 501:
          return CampaignsSyncUnsupported(
              'This server does not offer the campaign catalogue yet '
              '(HTTP ${response.statusCode} from $campaignsPath).');
        default:
          return CampaignsSyncFailed(
              body['message'] as String? ??
                  'Could not sync campaigns (server error ${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('Catalog: fetchCampaigns failed: $e');
      return const CampaignsSyncUnreachable(
          'Could not reach the server to sync campaigns.');
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

/// One campaign as the server sent it — a plain data holder, not the Drift
/// row type, so this datasource stays independent of the local schema.
class RemoteCampaign {
  const RemoteCampaign({
    required this.code,
    required this.name,
    this.description,
    this.emoji,
    this.tag,
    required this.requiredStamps,
    this.eligibleItemsDescription,
    this.rewardDescription,
    this.termsAndConditions,
    this.startsAt,
    this.endsAt,
    required this.isActive,
    this.displayOrder = 0,
  });

  final String code;
  final String name;
  final String? description;
  final String? emoji;
  final String? tag;
  final int requiredStamps;
  final String? eligibleItemsDescription;
  final String? rewardDescription;
  final String? termsAndConditions;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final int displayOrder;

  factory RemoteCampaign.fromJson(Map<String, dynamic> json) {
    return RemoteCampaign(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled campaign',
      description: json['description'] as String?,
      emoji: json['emoji'] as String?,
      tag: json['tag'] as String?,
      requiredStamps: _intOrDefault(json['required_stamps'], 10),
      eligibleItemsDescription: json['eligible_items_description'] as String?,
      rewardDescription: json['reward_description'] as String?,
      termsAndConditions: json['terms_and_conditions'] as String?,
      startsAt: _dateOrNull(json['starts_at']),
      endsAt: _dateOrNull(json['ends_at']),
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: _intOrDefault(json['display_order'], 0),
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

sealed class CampaignsSyncOutcome {
  const CampaignsSyncOutcome();
}

class CampaignsSyncSucceeded extends CampaignsSyncOutcome {
  const CampaignsSyncSucceeded(this.campaigns);
  final List<RemoteCampaign> campaigns;
}

/// The deployment has no campaigns route — a rollout gap, not a failure.
/// Mirrors `OtpSendUnsupported`'s treatment in `otp_remote_datasource.dart`.
class CampaignsSyncUnsupported extends CampaignsSyncOutcome {
  const CampaignsSyncUnsupported(this.reason);
  final String reason;
}

class CampaignsSyncUnreachable extends CampaignsSyncOutcome {
  const CampaignsSyncUnreachable(this.message);
  final String message;
}

class CampaignsSyncFailed extends CampaignsSyncOutcome {
  const CampaignsSyncFailed(this.message);
  final String message;
}
