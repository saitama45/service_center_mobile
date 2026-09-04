// `isNull`/`isNotNull` exist in both drift and matcher — hide drift's so the
// matcher versions win in expectations (same convention as loyalty_dao_test).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/database/tables/loyalty_tables.dart';

/// The v6 migration, which clears the phantom redemptions the retired
/// on-device "Redeem Now" path left behind.
///
/// The bug it repairs, as seen on a real device: History listed one real
/// redemption pulled from ghelpdesk ("OREO TUMBLER", reference `SR-4`) AND a
/// local one for the same event ("CBTL Campaign (Free Reward)", `TXN-…`), so
/// the summary read −24 redeemed against +12 earned.
///
/// Runs against NativeDatabase.memory(), never a developer database.
void main() {
  // Mirrors what a pre-v6 device actually held.
  Future<void> seedPreV6Ledger(AppDatabase db, {required String campaignId}) async {
    await db.into(db.loyaltyTransactions).insert(
          LoyaltyTransactionsCompanion.insert(
            reference: 'SR-4',
            userId: 'user-1',
            campaignId: Value(campaignId),
            type: txnRedeem,
            points: const Value(-12),
            productName: const Value('OREO TUMBLER'),
            storeName: const Value('CBTL EWM'),
            occurredAt: Value(DateTime.utc(2026, 9, 2, 3, 35)),
            // Pulled down from the server, so already synced.
            syncStatus: const Value(loyaltySynced),
          ),
        );
    await db.into(db.loyaltyTransactions).insert(
          LoyaltyTransactionsCompanion.insert(
            reference: 'TXN-578909',
            userId: 'user-1',
            campaignId: Value(campaignId),
            type: txnRedeem,
            points: const Value(-12),
            productName: const Value('CBTL Campaign (Free Reward)'),
            occurredAt: Value(DateTime.utc(2026, 9, 4, 14, 9)),
            // Written on-device by the retired path; never uploaded anywhere.
            syncStatus: const Value(loyaltySyncPending),
          ),
        );
    await db.into(db.loyaltyTransactions).insert(
          LoyaltyTransactionsCompanion.insert(
            reference: 'TXN-485039',
            userId: 'user-1',
            campaignId: Value(campaignId),
            type: txnEarn,
            points: const Value(1),
            productName: const Value('Autumn Harvest Latte'),
            occurredAt: Value(DateTime.utc(2026, 8, 25, 6, 14)),
            syncStatus: const Value(loyaltySyncPending),
          ),
        );
  }

  test('v6 drops the phantom local redemption but keeps the real one',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final campaign = await db.into(db.campaigns).insertReturning(
          CampaignsCompanion.insert(
              code: 'SP-3', name: 'CBTL Campaign', requiredStamps: const Value(12)),
        );
    await seedPreV6Ledger(db, campaignId: campaign.id);

    // Run just the upgrade step the released build will run on a v5 device.
    await db.migration.onUpgrade(Migrator(db), 5, 6);

    final rows = await db.select(db.loyaltyTransactions).get();
    final references = rows.map((r) => r.reference).toList();

    expect(references, contains('SR-4'),
        reason: 'the real, server-backed redemption must survive');
    expect(references, isNot(contains('TXN-578909')),
        reason: 'the phantom that double-counted the same redemption must go');

    // Earn rows are deliberately untouched — a never-synced earn can be the
    // only record of a stamp, unlike a phantom redeem which always has a
    // server twin.
    expect(references, contains('TXN-485039'));

    final redeemed = rows
        .where((r) => r.type == txnRedeem)
        .fold<int>(0, (sum, r) => sum + r.points);
    expect(redeemed, -12, reason: 'History totals stop double-counting');
  });

  // v7: the CARD half of the same cleanup. v6 removed the phantom ledger
  // rows; the cards the retired path closed stayed, and became visible once
  // the Rewards tab started listing redeemed cards — a member saw two claimed
  // cards for a campaign ghelpdesk had redeemed once.
  group('v7 — phantom cards', () {
    late AppDatabase db;
    late String campaignId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final campaign = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(
                code: 'SP-3',
                name: 'CBTL Campaign',
                requiredStamps: const Value(12)),
          );
      campaignId = campaign.id;
    });
    tearDown(() async => db.close());

    Future<String> card({
      required int cycle,
      String? remoteCardId,
      DateTime? redeemedAt,
      int syncStatus = loyaltySyncPending,
    }) async {
      final row = await db.into(db.stampCards).insertReturning(
            StampCardsCompanion.insert(
              userId: 'user-1',
              campaignId: campaignId,
              cycle: Value(cycle),
              stampsCollected: const Value(12),
              remoteCardId: Value(remoteCardId),
              redeemedAt: Value(redeemedAt),
              syncStatus: Value(syncStatus),
            ),
          );
      return row.id;
    }

    test('drops the locally-closed card and keeps the ghelpdesk one', () async {
      // Exactly the device state that produced the duplicate.
      final phantom = await card(
          cycle: 1, redeemedAt: DateTime.utc(2026, 9, 4, 14, 9));
      final real = await card(
        cycle: 2,
        remoteCardId: '9',
        redeemedAt: DateTime.utc(2026, 9, 2, 3, 35),
      );

      await db.migration.onUpgrade(Migrator(db), 6, 7);

      final ids = (await db.select(db.stampCards).get()).map((c) => c.id);
      expect(ids, [real]);
      expect(ids, isNot(contains(phantom)));
    });

    test('an open card the server has not seen yet is untouched', () async {
      // No remote id, but still in play — a real card mid-sync, not a fiction.
      final open = await card(cycle: 1);

      await db.migration.onUpgrade(Migrator(db), 6, 7);

      expect((await db.select(db.stampCards).get()).map((c) => c.id), [open]);
    });

    test('a card the ledger still references is kept, duplicate or not',
        () async {
      final referenced = await card(
          cycle: 1, redeemedAt: DateTime.utc(2026, 9, 4));
      await db.into(db.loyaltyTransactions).insert(
            LoyaltyTransactionsCompanion.insert(
              reference: 'SE-99',
              userId: 'user-1',
              campaignId: Value(campaignId),
              stampCardId: Value(referenced),
              type: txnEarn,
              points: const Value(1),
              occurredAt: Value(DateTime.utc(2026, 8, 20)),
              syncStatus: const Value(loyaltySynced),
            ),
          );

      await db.migration.onUpgrade(Migrator(db), 6, 7);

      expect((await db.select(db.stampCards).get()).map((c) => c.id),
          [referenced],
          reason: 'orphaning real history is worse than leaving a duplicate');
    });

    test('a synced card is never treated as a phantom', () async {
      final synced = await card(
        cycle: 1,
        redeemedAt: DateTime.utc(2026, 9, 4),
        syncStatus: loyaltySynced,
      );

      await db.migration.onUpgrade(Migrator(db), 6, 7);

      expect((await db.select(db.stampCards).get()).map((c) => c.id), [synced]);
    });
  });

  test('a fresh install is unaffected — nothing to clean', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final campaign = await db.into(db.campaigns).insertReturning(
          CampaignsCompanion.insert(
              code: 'SP-3', name: 'CBTL Campaign', requiredStamps: const Value(12)),
        );
    await db.into(db.loyaltyTransactions).insert(
          LoyaltyTransactionsCompanion.insert(
            reference: 'SR-9',
            userId: 'user-1',
            campaignId: Value(campaign.id),
            type: txnRedeem,
            points: const Value(-12),
            occurredAt: Value(DateTime.utc(2026, 9, 2)),
            syncStatus: const Value(loyaltySynced),
          ),
        );

    await db.migration.onUpgrade(Migrator(db), 5, 6);

    expect(await db.select(db.loyaltyTransactions).get(), hasLength(1));
  });
}
