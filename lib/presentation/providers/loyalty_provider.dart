import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/loyalty_member_remote_datasource.dart';
import '../../database/app_database.dart';
import '../../database/daos/loyalty_dao.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

// Re-exported so every existing `import 'loyalty_provider.dart'` (campaigns
// screen, ledger screen, ...) keeps resolving loyaltyRevisionProvider without
// each needing its own app_providers.dart import — the declaration itself
// had to move there to avoid a circular import (see the comment below).
export 'app_providers.dart' show loyaltyRevisionProvider;

final loyaltyDaoProvider = Provider<LoyaltyDao>((ref) {
  return ref.read(appDatabaseProvider).loyaltyDao;
});

// loyaltyRevisionProvider lives in app_providers.dart — SyncManager bumps it
// directly after a successful catalog pull, and app_providers.dart can't
// import this file back (that would be circular), so the shared signal has
// to live on the side both files can reach.

/// Every active campaign with the signed-in member's progress.
final campaignProgressProvider =
    FutureProvider<List<CampaignProgress>>((ref) async {
  ref.watch(loyaltyRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(loyaltyDaoProvider).getCampaignProgress(user.id);
});

/// The campaign shown on the home hero — furthest along, unlocked first.
final featuredCampaignProvider = FutureProvider<CampaignProgress?>((ref) async {
  ref.watch(loyaltyRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(loyaltyDaoProvider).getFeaturedProgress(user.id);
});

/// Every stamp card the member holds, redeemed ones included — the Rewards
/// tab's source. See `LoyaltyDao.getAllCardProgress` for why this is separate
/// from [campaignProgressProvider] rather than replacing it: the home hero,
/// the campaign picker and the redemption sheet all depend on redeemed cards
/// dropping out.
final campaignCardsProvider =
    FutureProvider<List<CampaignProgress>>((ref) async {
  ref.watch(loyaltyRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(loyaltyDaoProvider).getAllCardProgress(user.id);
});

/// The campaigns the member can switch the home stamp card between — the ones
/// they hold a live (non-expired) card for, in the same order the campaigns
/// screen lists them.
///
/// Expired campaigns are excluded for the same reason `getFeaturedProgress`
/// excludes them: you can't collect on them, so offering them as a choice
/// would only be a dead end.
final homeCampaignChoicesProvider =
    FutureProvider<List<CampaignProgress>>((ref) async {
  final all = await ref.watch(campaignProgressProvider.future);
  return all.where((p) => !p.isExpired).toList();
});

/// Which campaign the member picked on Home, or null for "decide for me".
///
/// Session state on purpose — it resets to the automatic pick on a cold
/// start rather than pinning a member to a card they chose once weeks ago.
/// Holding the campaign id (not an index) is what makes it survive the list
/// changing underneath: a stale id simply falls back, see
/// [homeCampaignProvider].
final selectedHomeCampaignIdProvider = StateProvider<String?>((ref) => null);

/// The campaign the home stamp card shows: the member's pick when they've
/// made one, otherwise the automatic choice (`getFeaturedProgress` — unlocked
/// first, then furthest along).
///
/// Falls back rather than failing when the selected id is no longer in the
/// list, which happens routinely: a redeemed card leaves
/// `getCampaignProgress` entirely, so the campaign a member was looking at
/// can vanish the moment staff hand over their reward.
final homeCampaignProvider = FutureProvider<CampaignProgress?>((ref) async {
  final choices = await ref.watch(homeCampaignChoicesProvider.future);
  final selectedId = ref.watch(selectedHomeCampaignIdProvider);

  if (selectedId != null) {
    for (final p in choices) {
      if (p.campaign.id == selectedId) return p;
    }
  }

  return ref.watch(featuredCampaignProvider.future);
});

final transactionsProvider =
    FutureProvider<List<LoyaltyTransaction>>((ref) async {
  ref.watch(loyaltyRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(loyaltyDaoProvider).getTransactions(user.id);
});

final ledgerTotalsProvider =
    FutureProvider<({int earned, int redeemed, int balance})>((ref) async {
  ref.watch(loyaltyRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return (earned: 0, redeemed: 0, balance: 0);
  return ref.read(loyaltyDaoProvider).getLedgerTotals(user.id);
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.read(loyaltyDaoProvider).getProducts();
});

/// Actions that mutate loyalty state. Every method bumps the revision so the
/// providers above rebuild.
final loyaltyActionsProvider = Provider<LoyaltyActions>((ref) {
  return LoyaltyActions(ref);
});

class LoyaltyActions {
  LoyaltyActions(this._ref);
  final Ref _ref;

  LoyaltyDao get _dao => _ref.read(loyaltyDaoProvider);
  String? get _userId => _ref.read(currentUserProvider)?.id;

  void _invalidate() {
    _ref.read(loyaltyRevisionProvider.notifier).state++;
  }

  /// Grants a stamp. Returns null on success, or a message to show the member.
  Future<String?> earnStamp({
    required String campaignId,
    required String scanToken,
    String? productId,
    String? productName,
    String? storeName,
  }) async {
    final userId = _userId;
    if (userId == null) return 'You are not signed in.';

    try {
      await _dao.earnStamp(
        userId: userId,
        campaignId: campaignId,
        scanToken: scanToken,
        productId: productId,
        productName: productName,
        storeName: storeName,
      );
      _invalidate();
      return null;
    } on LoyaltyException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('LoyaltyActions: earnStamp failed: $e');
      return 'Could not record that stamp. Please try again.';
    }
  }

  /// Claims a completed reward. Returns null on success, else a message.
  Future<String?> redeem({
    required String campaignId,
    String? storeName,
  }) async {
    final userId = _userId;
    if (userId == null) return 'You are not signed in.';

    try {
      await _dao.redeemReward(
        userId: userId,
        campaignId: campaignId,
        storeName: storeName,
      );
      _invalidate();
      return null;
    } on LoyaltyException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('LoyaltyActions: redeem failed: $e');
      return 'Could not redeem that reward. Please try again.';
    }
  }
}

// ── Member QR ─────────────────────────────────────────────────────────────

/// The member QR shown on the "My Member Code" screen, plus where it came
/// from — the screen needs that distinction to tell a member "you're
/// offline, showing your last saved code" instead of silently passing off a
/// cached value as fresh.
class MemberQrResult {
  const MemberQrResult(
      {required this.token, required this.fromCache, this.error});

  final String? token;
  final bool fromCache;
  final String? error;
}

/// Loads the signed member QR: network first (so a rotated/updated code
/// always wins when reachable), falling back to the last cached copy when
/// offline or the server can't be reached. The code is static per member
/// (see `LoyaltyMemberRemoteDatasource`), so a cached copy is exactly as
/// valid as a freshly fetched one — this is what lets a member with **no
/// internet at all** still present their code at checkout, as long as it was
/// fetched at least once before (see `prefetchMemberQr`, called right after
/// every login/registration while the network call that got them signed in
/// is still fresh, and again on app resume — not left until the member
/// happens to open this screen while online).
final memberQrProvider =
    FutureProvider.autoDispose<MemberQrResult>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const MemberQrResult(
        token: null, fromCache: false, error: 'You are not signed in.');
  }

  final cache = ref.read(memberQrCacheProvider);
  final outcome =
      await ref.read(loyaltyMemberRemoteDatasourceProvider).fetchMemberQrCard();

  switch (outcome) {
    case MemberQrSucceeded(:final token):
      await cache.save(user.id, token);
      return MemberQrResult(token: token, fromCache: false);
    case MemberQrUnreachable():
    case MemberQrUnsupported():
    case MemberQrFailed():
      final cached = await cache.read(user.id);
      if (cached != null) {
        return MemberQrResult(token: cached, fromCache: true);
      }
      final reason = switch (outcome) {
        MemberQrFailed(:final message) => message,
        MemberQrUnreachable(:final message) => message,
        MemberQrUnsupported() =>
          'Your member code isn\'t available yet — try again once you\'re online.',
        _ => 'Could not load your member code.',
      };
      return MemberQrResult(token: null, fromCache: false, error: reason);
  }
});

/// Fire-and-forget: fetches and caches the member QR right after a
/// successful sign-in, while the device is known to be online (login itself
/// just required a network round trip, or an OTP/biometric step just ran).
/// Errors are swallowed — this is opportunistic pre-caching for the offline
/// case, not a step that should ever block reaching the dashboard.
Future<void> prefetchMemberQr(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  try {
    final outcome = await ref
        .read(loyaltyMemberRemoteDatasourceProvider)
        .fetchMemberQrCard();
    if (outcome case MemberQrSucceeded(:final token)) {
      await ref.read(memberQrCacheProvider).save(user.id, token);
    }
  } catch (e) {
    debugPrint('prefetchMemberQr: failed, will retry on next resume/scan: $e');
  }
}
