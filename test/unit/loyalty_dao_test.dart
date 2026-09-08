// `isNull`/`isNotNull` exist in both drift and matcher — hide drift's so the
// matcher versions win in expectations.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/database/daos/loyalty_dao.dart';
import 'package:bms/database/tables/loyalty_tables.dart';

void main() {
  late AppDatabase db;
  late LoyaltyDao dao;

  const userId = 'user-1';
  late String campaignId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.loyaltyDao;

    // Minimal graph: a role, a user, a product and a 3-stamp campaign.
    await db.customStatement(
      'INSERT INTO roles (id, code, name, is_system, is_active, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['role-1', 'MEMBER', 'Member', 0, 1, _now, _now],
    );
    await db.customStatement(
      'INSERT INTO users (id, role_id, username, password_hash, full_name, '
      'is_active, failed_login_count, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, 'role-1', 'member', 'x', 'Test Member', 1, 0, _now, _now],
    );

    await db.into(db.products).insert(
          ProductsCompanion.insert(code: 'PROD-001', name: 'Flat White'),
        );

    final campaign = await db.into(db.campaigns).insertReturning(
          CampaignsCompanion.insert(
            code: 'TEST',
            name: 'Test Campaign',
            requiredStamps: const Value(3),
          ),
        );
    campaignId = campaign.id;
  });

  tearDown(() async => db.close());

  group('earnStamp', () {
    test('opens a card on first stamp and records a transaction', () async {
      final card = await dao.earnStamp(
        userId: userId,
        campaignId: campaignId,
        scanToken: 'TOKEN-A',
        productName: 'Flat White',
      );

      expect(card.stampsCollected, 1);
      expect(card.cycle, 1);
      expect(card.completedAt, isNull);

      final txns = await dao.getTransactions(userId);
      expect(txns, hasLength(1));
      expect(txns.single.type, txnEarn);
      expect(txns.single.points, 1);
      expect(txns.single.scanToken, 'TOKEN-A');
    });

    test('accumulates across scans and marks the card complete', () async {
      for (final t in ['T1', 'T2', 'T3']) {
        await dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: t);
      }

      final progress = await dao.getCampaignProgress(userId);
      expect(progress.single.stamps, 3);
      expect(progress.single.isUnlocked, isTrue);
      expect(progress.single.card!.completedAt, isNotNull);
    });

    test('rejects a replayed scan token', () async {
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'REPLAY');

      expect(
        () => dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: 'REPLAY'),
        throwsA(isA<LoyaltyException>()),
      );

      // The rejected attempt must not have granted a second stamp.
      final progress = await dao.getCampaignProgress(userId);
      expect(progress.single.stamps, 1);
    });

    test('refuses to overfill a completed card', () async {
      for (final t in ['A', 'B', 'C']) {
        await dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: t);
      }

      expect(
        () => dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: 'D'),
        throwsA(isA<LoyaltyException>()),
      );
    });

    test('refuses an inactive campaign', () async {
      await (db.update(db.campaigns)..where((c) => c.id.equals(campaignId)))
          .write(const CampaignsCompanion(isActive: Value(false)));

      expect(
        () => dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: 'X'),
        throwsA(isA<LoyaltyException>()),
      );
    });

    test('refuses an expired campaign', () async {
      await (db.update(db.campaigns)..where((c) => c.id.equals(campaignId)))
          .write(CampaignsCompanion(
        endsAt: Value(DateTime.now().toUtc().subtract(const Duration(days: 1))),
      ));

      expect(
        () => dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: 'X'),
        throwsA(isA<LoyaltyException>()),
      );
    });
  });

  group('redeemReward', () {
    test('closes the full card and opens the next cycle', () async {
      for (final t in ['A', 'B', 'C']) {
        await dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: t);
      }

      await dao.redeemReward(userId: userId, campaignId: campaignId);

      final progress = await dao.getCampaignProgress(userId);
      // A fresh, empty card for cycle 2.
      expect(progress.single.card!.cycle, 2);
      expect(progress.single.stamps, 0);
      expect(progress.single.isUnlocked, isFalse);

      final txns = await dao.getTransactions(userId);
      final redemption = txns.firstWhere((t) => t.type == txnRedeem);
      expect(redemption.points, -3);
    });

    test('refuses to redeem an incomplete card', () async {
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'A');

      expect(
        () => dao.redeemReward(userId: userId, campaignId: campaignId),
        throwsA(isA<LoyaltyException>()),
      );
    });

    test('stamps can be collected again after redeeming', () async {
      for (final t in ['A', 'B', 'C']) {
        await dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: t);
      }
      await dao.redeemReward(userId: userId, campaignId: campaignId);
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'D');

      final progress = await dao.getCampaignProgress(userId);
      expect(progress.single.stamps, 1);
      expect(progress.single.card!.cycle, 2);
    });
  });

  group('ledger totals', () {
    test('nets earned against redeemed', () async {
      for (final t in ['A', 'B', 'C']) {
        await dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: t);
      }
      await dao.redeemReward(userId: userId, campaignId: campaignId);
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'D');

      final totals = await dao.getLedgerTotals(userId);
      expect(totals.earned, 4);
      expect(totals.redeemed, 3);
      expect(totals.balance, 1);
    });

    test('is zero for a member with no activity', () async {
      final totals = await dao.getLedgerTotals(userId);
      expect(totals.earned, 0);
      expect(totals.redeemed, 0);
      expect(totals.balance, 0);
    });
  });

  group('getLedgerEntries', () {
    test('carries the campaign name for each row', () async {
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'A');

      final entries = await dao.getLedgerEntries(userId);

      expect(entries, hasLength(1));
      expect(entries.single.campaignName, 'Test Campaign',
          reason: 'a member with several campaigns cannot otherwise tell '
              'one "+3 stamps" row from another');
      expect(entries.single.transaction.type, txnEarn);
    });

    test('names each row against its own campaign', () async {
      final other = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(
                code: 'OTHER', name: 'Other Campaign',
                requiredStamps: const Value(5)),
          );
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'A');
      await dao.earnStamp(
          userId: userId, campaignId: other.id, scanToken: 'B');

      final entries = await dao.getLedgerEntries(userId);

      expect(
        entries.map((e) => e.campaignName).toSet(),
        {'Test Campaign', 'Other Campaign'},
      );
    });

    test('a row whose campaign is gone still renders', () async {
      await dao.earnStamp(
          userId: userId, campaignId: campaignId, scanToken: 'A');
      // campaignId is nullable, and history must outlive the link.
      await (db.update(db.loyaltyTransactions)
            ..where((t) => t.userId.equals(userId)))
          .write(const LoyaltyTransactionsCompanion(campaignId: Value(null)));

      final entries = await dao.getLedgerEntries(userId);

      expect(entries, hasLength(1));
      expect(entries.single.campaignName, isNull);
    });

    test('no activity gives an empty list, not an error', () async {
      expect(await dao.getLedgerEntries(userId), isEmpty);
    });
  });

  group('progress helpers', () {
    test('featured picks the unlocked campaign over a fuller one', () async {
      // A second campaign needing 10 stamps, which we part-fill.
      final other = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(
              code: 'OTHER',
              name: 'Other',
              requiredStamps: const Value(10),
            ),
          );
      for (var i = 0; i < 6; i++) {
        await dao.earnStamp(
            userId: userId, campaignId: other.id, scanToken: 'O$i');
      }
      // First campaign completed → unlocked.
      for (final t in ['A', 'B', 'C']) {
        await dao.earnStamp(
            userId: userId, campaignId: campaignId, scanToken: t);
      }

      final featured = await dao.getFeaturedProgress(userId);
      expect(featured!.campaign.id, campaignId);
      expect(featured.isUnlocked, isTrue);
    });

    test('remaining never goes negative', () async {
      // getCampaignProgress only returns campaigns the member has a real
      // card for (see that method's doc) — insert a fresh, untouched one
      // directly, mirroring what SyncManager._pullProgress creates for a
      // newly-scanned member (stampsCollected: 0).
      await db.into(db.stampCards).insert(
            StampCardsCompanion.insert(userId: userId, campaignId: campaignId),
          );

      final progress = await dao.getCampaignProgress(userId);
      expect(progress.single.remaining, 3);
      expect(progress.single.progress, 0);
    });

    test('a campaign nobody has a card for yet is not listed', () async {
      final progress = await dao.getCampaignProgress(userId);
      expect(progress, isEmpty);
    });

    // Staff can keep stamping while a full card waits to be redeemed, so a
    // member legitimately holds two OPEN cards for one campaign. Home shows one
    // entry per campaign, so which of the two it speaks for must be decided,
    // not left to row order.
    group('two open cards for one campaign', () {
      Future<void> seedFullAndFresh() async {
        // Full, awaiting redemption (cycle 1) + the replacement it opened.
        await db.into(db.stampCards).insert(StampCardsCompanion.insert(
              userId: userId,
              campaignId: campaignId,
              stampsCollected: const Value(3),
              cycle: const Value(1),
              completedAt: Value(DateTime.now().toUtc()),
            ));
        await db.into(db.stampCards).insert(StampCardsCompanion.insert(
              userId: userId,
              campaignId: campaignId,
              stampsCollected: const Value(1),
              cycle: const Value(2),
            ));
      }

      test('the campaign is listed once, showing the collectable card',
          () async {
        await seedFullAndFresh();

        final progress = await dao.getCampaignProgress(userId);
        expect(progress, hasLength(1));
        // The fresh card — the one the next scan lands on — not the full one.
        expect(progress.single.stamps, 1);
        expect(progress.single.isUnlocked, isFalse);
      });

      test('the full card is still reachable for redemption', () async {
        await seedFullAndFresh();

        final all = await dao.getAllCardProgress(userId);
        expect(all, hasLength(2));
        expect(all.where((p) => p.isUnlocked), hasLength(1));
      });

      test('a new stamp on the second card raises the total', () async {
        await seedFullAndFresh();

        // What scan_screen.dart watches. Per-campaign totals would report 1
        // here (only the fresh card is listed), and would not move when the
        // second card gained its stamp — so the celebration never fired.
        expect(await dao.getTotalStampsOnCards(userId), 4);

        await (db.update(db.stampCards)..where((s) => s.cycle.equals(2)))
            .write(const StampCardsCompanion(stampsCollected: Value(2)));

        expect(await dao.getTotalStampsOnCards(userId), 5);
      });

      test('redeemed cards keep counting, so the total never falls back',
          () async {
        await seedFullAndFresh();
        final before = await dao.getTotalStampsOnCards(userId);

        // Staff hand the reward over: the full card closes. A total that
        // dropped here would need a fresh baseline to avoid a missed stamp.
        await (db.update(db.stampCards)..where((s) => s.cycle.equals(1)))
            .write(StampCardsCompanion(
                redeemedAt: Value(DateTime.now().toUtc())));

        expect(await dao.getTotalStampsOnCards(userId), before);
      });
    });

    // History's "On your cards" figure. Counted off the cards rather than as
    // `earned - redeemed`, so it stays true even when a stamp reaches a card
    // without a matching ledger row.
    group('getOpenCardStampsByCampaign', () {
      test('sums BOTH open cards when a member is mid-rollover', () async {
        await db.into(db.stampCards).insert(StampCardsCompanion.insert(
              userId: userId,
              campaignId: campaignId,
              stampsCollected: const Value(3),
              cycle: const Value(1),
              completedAt: Value(DateTime.now().toUtc()),
            ));
        await db.into(db.stampCards).insert(StampCardsCompanion.insert(
              userId: userId,
              campaignId: campaignId,
              stampsCollected: const Value(2),
              cycle: const Value(2),
            ));

        final held = await dao.getOpenCardStampsByCampaign(userId);
        // Both cards are the member's to see — not collapsed to one.
        expect(held[campaignId], 5);
      });

      test('a redeemed card stops counting', () async {
        await db.into(db.stampCards).insert(StampCardsCompanion.insert(
              userId: userId,
              campaignId: campaignId,
              stampsCollected: const Value(3),
              cycle: const Value(1),
              redeemedAt: Value(DateTime.now().toUtc()),
            ));

        final held = await dao.getOpenCardStampsByCampaign(userId);
        expect(held[campaignId], isNull);
      });

      test('a member with no cards gets an empty map, not an error', () async {
        expect(await dao.getOpenCardStampsByCampaign(userId), isEmpty);
      });
    });

    test('keeps an open card whose program was deactivated', () async {
      // Deactivating a program in ghelpdesk leaves the cards already issued
      // against it Active — staff can still add stamps. Hiding it here made a
      // member's own in-progress card disappear from Home, which in turn hid
      // the campaign picker (it needs two or more choices).
      await db.into(db.stampCards).insert(
            StampCardsCompanion.insert(userId: userId, campaignId: campaignId),
          );
      await (db.update(db.campaigns)..where((c) => c.id.equals(campaignId)))
          .write(const CampaignsCompanion(isActive: Value(false)));

      final progress = await dao.getCampaignProgress(userId);
      expect(progress.single.campaign.id, campaignId);
      // Expiry is a separate axis and still applies.
      expect(progress.single.isExpired, isFalse);
    });
  });

  // The Rewards tab's source. Unlike getCampaignProgress it keeps redeemed
  // cards — a member whose only card was redeemed used to see "You haven't
  // started a card yet" there while History showed the claimed reward.
  group('getAllCardProgress', () {
    Future<String> insertCard({
      required int stamps,
      required int cycle,
      DateTime? redeemedAt,
      String? campaign,
    }) async {
      final row = await db.into(db.stampCards).insertReturning(
            StampCardsCompanion.insert(
              userId: userId,
              campaignId: campaign ?? campaignId,
              stampsCollected: Value(stamps),
              cycle: Value(cycle),
              redeemedAt: Value(redeemedAt),
              completedAt: Value(redeemedAt),
            ),
          );
      return row.id;
    }

    test('keeps redeemed cards that getCampaignProgress drops', () async {
      await insertCard(
          stamps: 3, cycle: 1, redeemedAt: DateTime.utc(2026, 9, 2));

      expect(await dao.getCampaignProgress(userId), isEmpty);

      final cards = await dao.getAllCardProgress(userId);
      expect(cards, hasLength(1));
      expect(cards.single.isRedeemed, isTrue);
      expect(cards.single.campaign.name, 'Test Campaign');
    });

    test('lists every cycle of one campaign separately', () async {
      await insertCard(
          stamps: 3, cycle: 1, redeemedAt: DateTime.utc(2026, 8, 1));
      await insertCard(
          stamps: 3, cycle: 2, redeemedAt: DateTime.utc(2026, 9, 2));
      await insertCard(stamps: 1, cycle: 3);

      final cards = await dao.getAllCardProgress(userId);
      expect(cards, hasLength(3),
          reason: 'collapsing by campaign would hide all but one');

      // Still in play first, then redeemed most-recent first.
      expect(cards.map((p) => p.isRedeemed), [false, true, true]);
      expect(cards[0].stamps, 1);
      expect(cards[1].card?.redeemedAt, DateTime.utc(2026, 9, 2));
      expect(cards[2].card?.redeemedAt, DateTime.utc(2026, 8, 1));
    });

    test('an unlocked card sorts above other cards still in play', () async {
      await insertCard(stamps: 1, cycle: 1);
      final full = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(
                code: 'FULL',
                name: 'Full One',
                requiredStamps: const Value(3)),
          );
      await insertCard(stamps: 3, cycle: 1, campaign: full.id);

      final cards = await dao.getAllCardProgress(userId);
      expect(cards.first.campaign.name, 'Full One');
      expect(cards.first.isUnlocked, isTrue);
    });

    test('a card on a retired campaign still shows its history', () async {
      // _pullCatalog deactivates campaigns rather than deleting them, so a
      // reward claimed on a since-retired campaign must not vanish.
      final retired = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(
              code: 'OLD',
              name: 'Retired Campaign',
              requiredStamps: const Value(3),
              isActive: const Value(false),
            ),
          );
      await insertCard(
        stamps: 3,
        cycle: 1,
        campaign: retired.id,
        redeemedAt: DateTime.utc(2026, 7, 1),
      );

      final cards = await dao.getAllCardProgress(userId);
      expect(cards.map((p) => p.campaign.name), contains('Retired Campaign'));
    });

    test('a member with no cards gets an empty list, not an error', () async {
      expect(await dao.getAllCardProgress(userId), isEmpty);
    });
  });
}

final String _now = DateTime.now().toUtc().toIso8601String();
