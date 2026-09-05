import 'dart:math';
import 'package:drift/drift.dart';
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

  double get progress =>
      required == 0 ? 0 : (stamps / required).clamp(0.0, 1.0);

  /// Card is full and the reward has not been claimed yet.
  bool get isUnlocked => stamps >= required && card?.redeemedAt == null;

  /// Staff have already handed this reward over (ghelpdesk redeemed the card
  /// and the progress pull closed it here).
  bool get isRedeemed => card?.redeemedAt != null;

  /// The signed code the member shows staff to claim this card's reward —
  /// issued by ghelpdesk with the progress pull, cached on the card so it
  /// still displays with no connectivity. Null until the card is full, and
  /// cleared again once it's been redeemed.
  String? get redeemToken => card?.redeemToken;

  /// Whether tapping "Redeem Now" can actually show a scannable code. A full
  /// card with no token means this member has never been online since it
  /// filled up — there's nothing for staff to scan yet.
  bool get canShowRedeemCode =>
      isUnlocked && (redeemToken?.isNotEmpty ?? false);

  bool get isExpired {
    final ends = campaign.endsAt;
    return ends != null && ends.isBefore(DateTime.now().toUtc());
  }
}

/// One row of the History screen: a ledger entry plus the campaign it was
/// earned or redeemed against.
class LedgerEntry {
  const LedgerEntry({required this.transaction, required this.campaignName});

  final LoyaltyTransaction transaction;

  /// Null when the campaign row is gone or was never linked — the entry still
  /// shows, just without a campaign line.
  final String? campaignName;
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

  /// Every stamp card the member holds — **including redeemed ones** — as one
  /// entry per card rather than one per campaign.
  ///
  /// This is the Rewards tab's source, and it deliberately differs from
  /// [getCampaignProgress] in two ways:
  ///
  ///  * Redeemed cards are kept. `getCampaignProgress` drops them because the
  ///    home hero and the "what can I collect on" question only care about
  ///    open cards — but dropping them left the Rewards tab reading
  ///    "You haven't started a card yet" for a member whose History plainly
  ///    showed a redeemed reward.
  ///  * One entry per *card*, not per campaign. Since redemption became
  ///    server-authoritative a member legitimately holds several cards for one
  ///    campaign (each redeemed cycle, plus the current one), and collapsing
  ///    them by campaign would hide all but one.
  ///
  /// Campaigns are looked up by id without the `is_active` filter, so a card
  /// redeemed on a campaign that has since been retired still shows its
  /// history — `SyncManager._pullCatalog` deactivates rather than deletes.
  ///
  /// Ordered the way the member thinks about them: cards still in play first
  /// (unlocked before the rest, then furthest along), then redeemed ones
  /// most-recent first.
  Future<List<CampaignProgress>> getAllCardProgress(String userId) async {
    final cards =
        await (select(stampCards)..where((s) => s.userId.equals(userId))).get();
    if (cards.isEmpty) return const [];

    final campaignIds = cards.map((c) => c.campaignId).toSet();
    final rows =
        await (select(campaigns)..where((c) => c.id.isIn(campaignIds))).get();
    final byId = {for (final c in rows) c.id: c};

    final progress = <CampaignProgress>[
      for (final card in cards)
        if (byId[card.campaignId] case final campaign?)
          CampaignProgress(campaign: campaign, card: card),
    ];

    progress.sort((a, b) {
      if (a.isRedeemed != b.isRedeemed) return a.isRedeemed ? 1 : -1;

      if (a.isRedeemed && b.isRedeemed) {
        return (b.card?.redeemedAt ?? DateTime(0))
            .compareTo(a.card?.redeemedAt ?? DateTime(0));
      }

      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      return b.progress.compareTo(a.progress);
    });

    return progress;
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

  /// The History screen's rows: each transaction with the campaign it belongs
  /// to, so a member can tell which card a stamp landed on.
  ///
  /// Resolved with a second query keyed on the distinct campaign ids rather
  /// than a join, because the ledger holds at most [limit] rows and a member
  /// only ever has a handful of campaigns — one small extra SELECT keeps the
  /// row type a plain `LoyaltyTransaction` instead of a generated join class
  /// that every caller would then have to unpick.
  ///
  /// The name is nullable on purpose: a transaction can outlive its local
  /// campaign row (`campaignId` is nullable, and a retired campaign is
  /// deactivated rather than deleted), and history must still render.
  Future<List<LedgerEntry>> getLedgerEntries(
    String userId, {
    int limit = 100,
  }) async {
    final txns = await getTransactions(userId, limit: limit);
    if (txns.isEmpty) return const [];

    final campaignIds =
        txns.map((t) => t.campaignId).whereType<String>().toSet();

    final names = <String, String>{};
    if (campaignIds.isNotEmpty) {
      final rows = await (select(campaigns)
            ..where((c) => c.id.isIn(campaignIds)))
          .get();
      for (final row in rows) {
        names[row.id] = row.name;
      }
    }

    return [
      for (final txn in txns)
        LedgerEntry(
          transaction: txn,
          campaignName: txn.campaignId == null ? null : names[txn.campaignId],
        ),
    ];
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
  String _newReference() => 'TXN-${(100000 + _rand.nextInt(900000))}';
}
