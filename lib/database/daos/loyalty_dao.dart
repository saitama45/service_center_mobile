import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../tables/loyalty_tables.dart';

part 'loyalty_dao.g.dart';

/// A campaign together with the signed-in member's progress on it.
class CampaignProgress {
  const CampaignProgress({
    required this.campaign,
    required this.card,
  });

  final Campaign campaign;

  /// Always non-null in practice — `getCampaignProgress` only returns
  /// campaigns the member actually has a card for (see that method's doc).
  /// Nullable because [getFeaturedProgress] builds on the same list and a
  /// missing card should read as "not started" rather than crash if that
  /// invariant is ever loosened later.
  final StampCard? card;

  int get stamps => card?.stampsCollected ?? 0;
  int get required => campaign.requiredStamps;
  int get remaining => (required - stamps).clamp(0, required);

  double get progress => required == 0 ? 0 : (stamps / required).clamp(0.0, 1.0);

  /// Card is full and the reward has not been claimed yet.
  bool get isUnlocked => stamps >= required && card?.redeemedAt == null;

  bool get isExpired {
    final ends = campaign.endsAt;
    return ends != null && ends.isBefore(DateTime.now().toUtc());
  }
}

/// Raised when a stamp cannot be granted. Carries a message safe to show.
class LoyaltyException implements Exception {
  LoyaltyException(this.message);
  final String message;
  @override
  String toString() => message;
}

@DriftAccessor(
  tables: [Products, Campaigns, StampCards, LoyaltyTransactions],
)
class LoyaltyDao extends DatabaseAccessor<AppDatabase> with _$LoyaltyDaoMixin {
  LoyaltyDao(super.db);

  static final _rand = Random.secure();

  // ── Reads ──────────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({bool activeOnly = true}) {
    final q = select(products);
    if (activeOnly) q.where((p) => p.isActive.equals(true));
    q.orderBy([(p) => OrderingTerm.asc(p.name)]);
    return q.get();
  }

  Future<List<Campaign>> getCampaigns({bool activeOnly = true}) {
    final q = select(campaigns);
    if (activeOnly) q.where((c) => c.isActive.equals(true));
    q.orderBy([(c) => OrderingTerm.asc(c.displayOrder)]);
    return q.get();
  }

  Future<Campaign?> getCampaignById(String id) =>
      (select(campaigns)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Campaign?> getCampaignByCode(String code) =>
      (select(campaigns)..where((c) => c.code.equals(code))).getSingleOrNull();

  /// Every active campaign the member has actually been enrolled in — i.e.
  /// has a real card for, which only ever happens server-side (ghelpdesk
  /// staff scanning the member's QR code the first time; see `scan_screen
  /// .dart` and `SyncManager._pullProgress`). A campaign nobody has scanned
  /// this member into yet is deliberately excluded rather than shown at
  /// "0/N stamps" — that would read as already-enrolled when nothing has
  /// actually started for them.
  Future<List<CampaignProgress>> getCampaignProgress(String userId) async {
    final all = await getCampaigns();
    final cards = await (select(stampCards)
          ..where((s) => s.userId.equals(userId) & s.redeemedAt.isNull()))
        .get();

    final byCampaign = {for (final c in cards) c.campaignId: c};
    return all
        .where((c) => byCampaign.containsKey(c.id))
        .map((c) => CampaignProgress(campaign: c, card: byCampaign[c.id]))
        .toList();
  }

  /// The campaign the member is furthest along on — what the home hero shows.
  /// Prefers an unlocked reward, then the highest progress.
  Future<CampaignProgress?> getFeaturedProgress(String userId) async {
    final all = await getCampaignProgress(userId);
    final live = all.where((p) => !p.isExpired).toList();
    if (live.isEmpty) return null;

    live.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      return b.progress.compareTo(a.progress);
    });
    return live.first;
  }

  Future<List<LoyaltyTransaction>> getTransactions(
    String userId, {
    int limit = 100,
  }) {
    return (select(loyaltyTransactions)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
  }

  /// Totals for the ledger summary strip: earned, redeemed, current balance.
  Future<({int earned, int redeemed, int balance})> getLedgerTotals(
    String userId,
  ) async {
    final rows = await (select(loyaltyTransactions)
          ..where((t) => t.userId.equals(userId)))
        .get();

    var earned = 0;
    var redeemed = 0;
    for (final r in rows) {
      if (r.type == txnEarn) {
        earned += r.points;
      } else {
        redeemed += r.points.abs();
      }
    }
    return (earned: earned, redeemed: redeemed, balance: earned - redeemed);
  }

  /// Lifetime stamps earned — the "Lifetime Stamps" stat on home.
  Future<int> getLifetimeStamps(String userId) async {
    final totals = await getLedgerTotals(userId);
    return totals.earned;
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Grants one stamp on [campaignId] for [productId].
  ///
  /// [scanToken] is the one-time code from the QR screen. It is stored on the
  /// transaction under a unique index, so replaying the same token — a
  /// screenshotted QR, a double tap — fails instead of granting a second stamp.
  ///
  /// Returns the updated card. Throws [LoyaltyException] with a user-safe
  /// message when the stamp cannot be granted.
  Future<StampCard> earnStamp({
    required String userId,
    required String campaignId,
    String? productId,
    String? productName,
    String? storeName,
    required String scanToken,
  }) async {
    return transaction(() async {
      final campaign = await getCampaignById(campaignId);
      if (campaign == null) {
        throw LoyaltyException('That campaign is no longer available.');
      }
      if (!campaign.isActive) {
        throw LoyaltyException('${campaign.name} is not currently running.');
      }
      final ends = campaign.endsAt;
      if (ends != null && ends.isBefore(DateTime.now().toUtc())) {
        throw LoyaltyException('${campaign.name} has expired.');
      }

      // Replay guard — the unique index on scan_token is the real enforcement,
      // this check just produces a friendlier message in the common case.
      final replay = await (select(loyaltyTransactions)
            ..where((t) => t.scanToken.equals(scanToken)))
          .getSingleOrNull();
      if (replay != null) {
        throw LoyaltyException('This code has already been used.');
      }

      final card = await _openCard(userId, campaignId);
      if (card.stampsCollected >= campaign.requiredStamps) {
        throw LoyaltyException(
          'This card is already full — redeem your reward first.',
        );
      }

      final now = DateTime.now().toUtc();
      final newCount = card.stampsCollected + 1;
      final isNowComplete = newCount >= campaign.requiredStamps;

      await (update(stampCards)..where((s) => s.id.equals(card.id))).write(
        StampCardsCompanion(
          stampsCollected: Value(newCount),
          completedAt: Value(isNowComplete ? now : null),
          syncStatus: const Value(loyaltySyncPending),
          updatedAt: Value(now),
        ),
      );

      await into(loyaltyTransactions).insert(
        LoyaltyTransactionsCompanion.insert(
          reference: _newReference(),
          userId: userId,
          type: txnEarn,
          campaignId: Value(campaignId),
          stampCardId: Value(card.id),
          productId: Value(productId),
          productName: Value(productName),
          storeName: Value(storeName),
          scanToken: Value(scanToken),
          points: const Value(1),
          occurredAt: Value(now),
        ),
      );

      return (await (select(stampCards)..where((s) => s.id.equals(card.id)))
          .getSingle());
    });
  }

  /// Claims the reward on a full card and opens a fresh card for the next
  /// cycle, mirroring how a paper punch card works.
  Future<void> redeemReward({
    required String userId,
    required String campaignId,
    String? storeName,
  }) async {
    await transaction(() async {
      final campaign = await getCampaignById(campaignId);
      if (campaign == null) {
        throw LoyaltyException('That campaign is no longer available.');
      }

      final card = await (select(stampCards)
            ..where((s) =>
                s.userId.equals(userId) &
                s.campaignId.equals(campaignId) &
                s.redeemedAt.isNull()))
          .getSingleOrNull();

      if (card == null || card.stampsCollected < campaign.requiredStamps) {
        throw LoyaltyException(
          'You need ${campaign.requiredStamps} stamps before redeeming.',
        );
      }

      final now = DateTime.now().toUtc();

      await (update(stampCards)..where((s) => s.id.equals(card.id))).write(
        StampCardsCompanion(
          redeemedAt: Value(now),
          syncStatus: const Value(loyaltySyncPending),
          updatedAt: Value(now),
        ),
      );

      await into(loyaltyTransactions).insert(
        LoyaltyTransactionsCompanion.insert(
          reference: _newReference(),
          userId: userId,
          type: txnRedeem,
          campaignId: Value(campaignId),
          stampCardId: Value(card.id),
          productName: Value('${campaign.name} (Free Reward)'),
          storeName: Value(storeName),
          points: Value(-campaign.requiredStamps),
          occurredAt: Value(now),
        ),
      );

      // Start the next cycle so the member can keep collecting immediately.
      await into(stampCards).insert(
        StampCardsCompanion.insert(
          userId: userId,
          campaignId: campaignId,
          cycle: Value(card.cycle + 1),
        ),
      );
    });
  }

  /// Returns the member's open card for a campaign, creating it on first use.
  Future<StampCard> _openCard(String userId, String campaignId) async {
    final existing = await (select(stampCards)
          ..where((s) =>
              s.userId.equals(userId) &
              s.campaignId.equals(campaignId) &
              s.redeemedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) return existing;

    final id = await into(stampCards).insertReturning(
      StampCardsCompanion.insert(userId: userId, campaignId: campaignId),
    );
    return id;
  }

  /// TXN-XXXXXX, matching the reference format used in the ledger design.
  String _newReference() =>
      'TXN-${(100000 + _rand.nextInt(900000))}';

  /// Wipes this member's loyalty activity. Used by the "reset demo data"
  /// action so the flow can be walked through repeatedly.
  Future<void> resetMemberActivity(String userId) async {
    try {
      await transaction(() async {
        await (delete(loyaltyTransactions)..where((t) => t.userId.equals(userId)))
            .go();
        await (delete(stampCards)..where((s) => s.userId.equals(userId))).go();
      });
    } catch (e) {
      debugPrint('LoyaltyDao: reset failed: $e');
    }
  }
}
