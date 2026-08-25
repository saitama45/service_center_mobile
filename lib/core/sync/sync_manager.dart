import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../data/datasources/remote/catalog_remote_datasource.dart';
import '../../data/datasources/remote/loyalty_member_remote_datasource.dart';
import '../../database/app_database.dart';
import '../../database/tables/loyalty_tables.dart';

typedef OnlineCheck = Future<bool> Function();

/// Reconciles loyalty data with the server in both directions.
///
/// **Pull** — two steps, always in this order:
///   1. the campaign catalogue (`stamp_programs` on ghelpdesk, mirrored via
///      `GET /api/campaigns`) is synced down and upserted over whatever is
///      locally seeded, so real campaign data replaces the on-device demo
///      seed the first time the app ever reaches the server (`_pullCatalog`).
///   2. the signed-in member's real stamp progress (`GET
///      /api/loyalty/my-cards`) overwrites the local open card's count for
///      each campaign — this is what makes a stamp ghelpdesk staff just
///      added on the Stamps module's "Scan Customer" flow show up here
///      (`_pullProgress`, needs step 1 done first so there's a local
///      campaign row to attach progress to).
///   3. the same member's real earn/redeem ledger (`GET
///      /api/loyalty/my-transactions`) is upserted into local
///      `loyalty_transactions` by `reference` — step 2 only moves a card's
///      running count, it never populated the History screen's actual
///      transaction list (`_pullTransactions`, needs step 1 for the same
///      reason step 2 does).
///
/// **Push** — stamps and redemptions are written to the local database first
/// so the app works with no signal; this queue is what would eventually
/// reconcile them upward.
///
/// NOTE: the upload-direction loyalty endpoints do not exist server-side
/// yet. Until they do, [_pushChanges] counts what is pending and leaves the
/// rows queued rather than firing requests that would 404 and mark good
/// records as failed. When the API lands, fill in [_uploadTransactions] —
/// the queue is already correct.
class SyncManager {
  SyncManager(
    this._db,
    this._apiClient, {
    OnlineCheck? isOnline,
    CatalogRemoteDatasource? catalog,
    LoyaltyMemberRemoteDatasource? loyaltyMember,
    this.onCatalogUpdated,
  })  : _isOnline = isOnline ?? _defaultIsOnline,
        _catalog = catalog ?? CatalogRemoteDatasource(_apiClient),
        _loyaltyMember = loyaltyMember ?? LoyaltyMemberRemoteDatasource(_apiClient);

  final AppDatabase _db;
  // ignore: unused_field — retained for the loyalty upload endpoints (see class doc).
  final ApiClient _apiClient;
  final OnlineCheck _isOnline;
  final CatalogRemoteDatasource _catalog;
  final LoyaltyMemberRemoteDatasource _loyaltyMember;

  /// Fired after a catalog pull actually changes the local `campaigns`
  /// table, so a Riverpod-aware caller can refetch the derived providers.
  /// Kept a plain callback (not a Riverpod `Ref`) so this class has no
  /// dependency on the provider layer — `syncManagerProvider` is what wires
  /// it up, in `app_providers.dart`.
  final VoidCallback? onCatalogUpdated;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// [userId] drives the progress pull (a member's stamp counts are personal,
  /// unlike the shared catalogue) — pass the signed-in member's id so a real
  /// stamp added by ghelpdesk staff shows up here without them having to
  /// wait for the campaign catalogue itself to change. Omit it (e.g. no one
  /// signed in yet) to just sync the catalogue.
  Future<void> sync({String? userId}) async {
    // Claim the flag before the first `await` — a second synchronous call to
    // sync() must see this set immediately, or two calls can both pass the
    // guard while the first is still suspended on _isOnline().
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      if (!await _isOnline()) {
        debugPrint('Sync: Skipped — device is offline.');
        return;
      }

      debugPrint('Sync: Starting sync cycle...');
      await _pullCatalog();
      if (userId != null) {
        await _pullProgress(userId);
        await _pullTransactions(userId);
      }
      await _pushChanges();
      debugPrint('Sync: Sync cycle completed.');
    } catch (e) {
      debugPrint('Sync: Sync cycle failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Pulls the campaign catalogue down and makes the local `campaigns` table
  /// match it exactly: synced rows are upserted by `code`, and any local
  /// campaign the server did NOT return (the on-device demo seed, or a
  /// program the server has since retired) is deactivated rather than
  /// deleted — a member's `stamp_cards`/`loyalty_transactions` FK-reference
  /// campaigns, so rows are never dropped, only hidden.
  Future<void> _pullCatalog() async {
    final outcome = await _catalog.fetchCampaigns();

    switch (outcome) {
      case CampaignsSyncSucceeded(:final campaigns):
        await _db.transaction(() async {
          final seenCodes = <String>{};
          for (final remote in campaigns) {
            if (remote.code.isEmpty) continue; // malformed row — skip, don't crash the sync
            seenCodes.add(remote.code);
            final companion = _toCompanion(remote);
            // insertOnConflictUpdate resolves conflicts on the PRIMARY KEY
            // (id) — useless here, since id is a fresh client-generated UUID
            // every call and so never collides. The real identity for a
            // synced row is `code` (its unique key), so the upsert target
            // has to be named explicitly.
            await _db.into(_db.campaigns).insert(
                  companion,
                  onConflict: DoUpdate((_) => companion, target: [_db.campaigns.code]),
                );
          }

          if (seenCodes.isEmpty) {
            // An empty catalogue is a real answer (e.g. every program was
            // deactivated server-side) — deactivate everything local rather
            // than leaving stale demo/previously-synced rows showing.
            await (_db.update(_db.campaigns)).write(
              const CampaignsCompanion(isActive: Value(false)),
            );
          } else {
            await (_db.update(_db.campaigns)
                  ..where((c) => c.code.isNotIn(seenCodes)))
                .write(const CampaignsCompanion(isActive: Value(false)));
          }
        });
        debugPrint('Sync: Pulled ${campaigns.length} campaign(s).');
        onCatalogUpdated?.call();

      case CampaignsSyncUnsupported(:final reason):
        // Not deployed yet on this server — keep the local seed as-is.
        debugPrint('Sync: $reason');

      case CampaignsSyncUnreachable(:final message):
      case CampaignsSyncFailed(:final message):
        // Transient — keep whatever the app already has (seed or a
        // previous successful sync) rather than clearing anything.
        debugPrint('Sync: Campaign pull failed: $message');
    }
  }

  CampaignsCompanion _toCompanion(RemoteCampaign r) {
    return CampaignsCompanion(
      code: Value(r.code),
      name: Value(r.name),
      description: Value(r.description),
      emoji: Value(r.emoji),
      tag: Value(r.tag),
      requiredStamps: Value(r.requiredStamps),
      // The server models eligibility as free text, not discrete product
      // codes — this column is otherwise unused by the app today (nothing
      // reads it back), so it doubles as that free-text description rather
      // than adding a schema migration for a field nothing renders yet.
      eligibleProductCodes: Value(r.eligibleItemsDescription ?? ''),
      rewardDescription: Value(r.rewardDescription),
      termsAndConditions: Value(r.termsAndConditions),
      startsAt: Value(r.startsAt),
      endsAt: Value(r.endsAt),
      isActive: Value(r.isActive),
      displayOrder: Value(r.displayOrder),
      syncStatus: const Value(loyaltySynced),
    );
  }

  /// Pulls the member's real stamp progress and overwrites the local open
  /// card's count to match — this is what makes a stamp ghelpdesk staff just
  /// added on the "Scan Customer" flow show up here, instead of the app only
  /// ever reflecting its own local (now largely vestigial) earn action.
  ///
  /// Deliberately runs AFTER `_pullCatalog`: a remote card's `code` needs a
  /// matching local campaign row to attach to, or it's silently skipped and
  /// picked up on the next sync once the catalogue has caught up.
  ///
  /// Only distinguishes "open" (active/completed) vs not — ghelpdesk's
  /// separate asset-based redemption flow (`StampController::redeem`) isn't
  /// mirrored down here yet, so a server-side `redeemed` status is treated
  /// the same as `completed` (still shown as a full, unclaimed-looking card)
  /// rather than silently starting a new local cycle the member never asked
  /// for. Wiring that up is a separate, deliberately deferred change.
  Future<void> _pullProgress(String userId) async {
    final outcome = await _loyaltyMember.fetchMyCards();

    switch (outcome) {
      case MyCardsSucceeded(:final cards):
        var changed = false;
        await _db.transaction(() async {
          for (final remote in cards) {
            final campaign = await (_db.select(_db.campaigns)
                  ..where((c) => c.code.equals(remote.code)))
                .getSingleOrNull();
            if (campaign == null) continue;

            final existing = await (_db.select(_db.stampCards)
                  ..where((s) =>
                      s.userId.equals(userId) &
                      s.campaignId.equals(campaign.id) &
                      s.redeemedAt.isNull()))
                .getSingleOrNull();

            final now = DateTime.now().toUtc();
            final isFull = remote.status == 'completed' || remote.status == 'redeemed';

            if (existing == null) {
              await _db.into(_db.stampCards).insert(
                    StampCardsCompanion.insert(
                      userId: userId,
                      campaignId: campaign.id,
                      stampsCollected: Value(remote.stampsCount),
                      completedAt: Value(isFull ? now : null),
                    ),
                  );
              changed = true;
            } else if (existing.stampsCollected != remote.stampsCount ||
                (existing.completedAt != null) != isFull) {
              await (_db.update(_db.stampCards)..where((s) => s.id.equals(existing.id)))
                  .write(
                StampCardsCompanion(
                  stampsCollected: Value(remote.stampsCount),
                  completedAt: Value(isFull ? (existing.completedAt ?? now) : null),
                  updatedAt: Value(now),
                ),
              );
              changed = true;
            }
          }
        });
        debugPrint('Sync: Pulled progress for ${cards.length} card(s).');
        if (changed) onCatalogUpdated?.call();

      case MyCardsUnsupported(:final reason):
        // Not deployed yet on this server — keep local progress as-is.
        debugPrint('Sync: $reason');

      case MyCardsUnreachable(:final message):
      case MyCardsFailed(:final message):
        // Transient — keep whatever the app already has rather than
        // clearing anything a member may currently be looking at.
        debugPrint('Sync: Progress pull failed: $message');
    }
  }

  /// Pulls the member's real earn/redeem events and upserts them into the
  /// local ledger — `_pullProgress` alone only moves a card's running count,
  /// it never populated the History screen's transaction list for a stamp a
  /// real staff scan added. This is that missing piece.
  ///
  /// Runs AFTER `_pullProgress` for the same reason `_pullProgress` runs
  /// after `_pullCatalog`: a transaction needs a local campaign row (by
  /// `campaignCode`) to attach to, and benefits from the freshest local card
  /// row (by `campaignId`) to link `stampCardId` to — a card created moments
  /// earlier in this same sync cycle is what a transaction usually refers to.
  /// A transaction whose campaign hasn't synced down yet is skipped and
  /// retried next cycle, same as `_pullProgress`'s own card-attachment gap.
  Future<void> _pullTransactions(String userId) async {
    final outcome = await _loyaltyMember.fetchMyTransactions();

    switch (outcome) {
      case MyTransactionsSucceeded(:final transactions):
        await _db.transaction(() async {
          for (final remote in transactions) {
            final campaign = await (_db.select(_db.campaigns)
                  ..where((c) => c.code.equals(remote.campaignCode)))
                .getSingleOrNull();
            if (campaign == null) continue;

            // Most-recent card for this campaign — a completed/redeemed one
            // is a perfectly good link for a redemption event that just
            // closed it, so this isn't restricted to only the open card the
            // way _pullProgress's own lookup is.
            final card = await (_db.select(_db.stampCards)
                  ..where((s) =>
                      s.userId.equals(userId) & s.campaignId.equals(campaign.id))
                  ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
                  ..limit(1))
                .getSingleOrNull();

            final isEarn = remote.type == txnEarn;
            // Mirrors the local redeemReward's own wording exactly, so a
            // redemption reads the same regardless of which source it came
            // from — the server only sends a product name when a specific
            // reward asset was actually redeemed.
            final productName = remote.productName ??
                (isEarn ? null : '${campaign.name} (Free Reward)');

            final companion = LoyaltyTransactionsCompanion.insert(
              reference: remote.reference,
              userId: userId,
              type: isEarn ? txnEarn : txnRedeem,
              campaignId: Value(campaign.id),
              stampCardId: Value(card?.id),
              points: Value(remote.points),
              productName: Value(productName),
              storeName: Value(remote.storeName),
              occurredAt: Value(remote.occurredAt ?? DateTime.now().toUtc()),
              syncStatus: const Value(loyaltySynced),
            );

            // Same PK-vs-unique-key upsert fix as the campaign pull —
            // insertOnConflictUpdate would target `id` (a fresh UUID every
            // call, never colliding), not `reference`.
            await _db.into(_db.loyaltyTransactions).insert(
                  companion,
                  onConflict: DoUpdate((_) => companion,
                      target: [_db.loyaltyTransactions.reference]),
                );
          }
        });
        if (transactions.isNotEmpty) onCatalogUpdated?.call();
        debugPrint('Sync: Pulled ${transactions.length} transaction(s).');

      case MyTransactionsUnsupported(:final reason):
        debugPrint('Sync: $reason');

      case MyTransactionsUnreachable(:final message):
      case MyTransactionsFailed(:final message):
        debugPrint('Sync: Transaction pull failed: $message');
    }
  }

  Future<void> _pushChanges() async {
    final pending = await pendingTransactionCount();
    if (pending == 0) {
      debugPrint('Sync: Nothing to push.');
      return;
    }
    debugPrint(
      'Sync: $pending loyalty transaction(s) queued. Upload is a no-op until '
      'the loyalty API endpoints exist.',
    );
  }

  /// Number of loyalty transactions still waiting to reach the server.
  /// Drives the "pending sync" indicator in the UI.
  Future<int> pendingTransactionCount() async {
    final rows = await (_db.select(_db.loyaltyTransactions)
          ..where((t) => t.syncStatus.equals(loyaltySyncPending)))
        .get();
    return rows.length;
  }
}

Future<bool> _defaultIsOnline() async {
  final results = await Connectivity().checkConnectivity();
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}
