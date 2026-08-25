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
  });

  test('resetMemberActivity clears cards and ledger', () async {
    await dao.earnStamp(
        userId: userId, campaignId: campaignId, scanToken: 'A');
    await dao.resetMemberActivity(userId);

    expect(await dao.getTransactions(userId), isEmpty);
    // The card row itself is deleted, not zeroed — with no card left, the
    // campaign drops out of the (now card-gated) progress list entirely.
    expect(await dao.getCampaignProgress(userId), isEmpty);
  });
}

final String _now = DateTime.now().toUtc().toIso8601String();
