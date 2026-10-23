// `isNull`/`isNotNull` exist in both drift and matcher — hide drift's so the
// matcher versions win in expectations (same convention as loyalty_dao_test).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cbtl/database/app_database.dart';

/// The v9 migration (Holiday slots, per-member card cap) and v10 (the reason
/// on a stamp correction), upgraded from a v8 phone.
///
/// Runs against NativeDatabase.memory(), never a developer database.
void main() {
  test('a v8 database gains the new columns and keeps its rows', () async {
    // The three tables v9/v10 touch, exactly as v8 created them, with a row
    // in each — what a member's phone holds before the update.
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE campaigns (
          id TEXT NOT NULL PRIMARY KEY, code TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL, description TEXT NULL, emoji TEXT NULL,
          tag TEXT NULL, required_stamps INTEGER NOT NULL DEFAULT 10,
          eligible_product_codes TEXT NOT NULL DEFAULT '',
          reward_description TEXT NULL, terms_and_conditions TEXT NULL,
          starts_at TEXT NULL, ends_at TEXT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          display_order INTEGER NOT NULL DEFAULT 0,
          sync_status INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
      raw.execute('''
        CREATE TABLE stamp_cards (
          id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL,
          campaign_id TEXT NOT NULL, remote_card_id TEXT NULL,
          redeem_token TEXT NULL,
          stamps_collected INTEGER NOT NULL DEFAULT 0,
          cycle INTEGER NOT NULL DEFAULT 1,
          completed_at TEXT NULL, redeemed_at TEXT NULL,
          sync_status INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          UNIQUE (user_id, campaign_id, cycle))''');
      raw.execute('''
        CREATE TABLE loyalty_transactions (
          id TEXT NOT NULL PRIMARY KEY, reference TEXT NOT NULL UNIQUE,
          user_id TEXT NOT NULL, campaign_id TEXT NULL,
          stamp_card_id TEXT NULL, product_id TEXT NULL,
          type TEXT NOT NULL, points INTEGER NOT NULL DEFAULT 1,
          product_name TEXT NULL, store_name TEXT NULL,
          scan_token TEXT NULL UNIQUE, occurred_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
      const at = '2026-09-01T00:00:00.000Z';
      raw.execute(
        'INSERT INTO campaigns (id, code, name, required_stamps, created_at, updated_at) '
        "VALUES ('c-1', 'SP-1', 'CBTL Campaign', 12, '$at', '$at')",
      );
      raw.execute(
        'INSERT INTO stamp_cards (id, user_id, campaign_id, remote_card_id, '
        'stamps_collected, created_at, updated_at) '
        "VALUES ('s-1', 'user-1', 'c-1', '77', 5, '$at', '$at')",
      );
      raw.execute(
        'INSERT INTO loyalty_transactions (id, reference, user_id, campaign_id, '
        'type, points, occurred_at, created_at, updated_at) '
        "VALUES ('t-1', 'SE-1', 'user-1', 'c-1', 'earn', 5, '$at', '$at', '$at')",
      );
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    final campaign = await db.select(db.campaigns).getSingle();
    expect(campaign.code, 'SP-1');
    expect(campaign.holidayStamps, 0, reason: 'an existing program is a plain card');
    expect(campaign.maxCardsPerCustomer, isNull, reason: 'and has no cap');

    final card = await db.select(db.stampCards).getSingle();
    expect(card.stampsCollected, 5, reason: 'the member keeps their stamps');
    expect(card.remoteCardId, '77');
    expect(card.holidayCount, 0);
    expect(card.cardNumber, isNull);

    final txn = await db.select(db.loyaltyTransactions).getSingle();
    expect(txn.reference, 'SE-1', reason: 'history survives the upgrade');
    expect(txn.note, isNull, reason: 'only a stamp correction carries a reason');

    final version =
        await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });

  test('replaying the v9 step on an up-to-date database is harmless',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.campaigns).get(); // open: createAll at v9

    await db.migration.onUpgrade(Migrator(db), 8, 9);

    // Still usable, with the columns present exactly once.
    final columns = await db
        .customSelect('PRAGMA table_info(stamp_cards)')
        .map((r) => r.read<String>('name'))
        .get();
    expect(columns.where((c) => c == 'holiday_count'), hasLength(1));
    expect(columns.where((c) => c == 'card_number'), hasLength(1));
  });
}
