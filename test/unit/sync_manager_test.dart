// `isNull`/`isNotNull` exist in both drift and matcher — hide drift's so the
// matcher versions win in expectations (same convention as loyalty_dao_test).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bms/core/sync/sync_manager.dart';
import 'package:bms/data/datasources/remote/api_client.dart';
import 'package:bms/data/datasources/remote/catalog_remote_datasource.dart';
import 'package:bms/data/datasources/remote/loyalty_member_remote_datasource.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/database/tables/loyalty_tables.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Scripted stand-in for the server round trip — same shape as the fakes in
/// otp_controller_test.dart.
class _FakeCatalog implements CatalogRemoteDatasource {
  final List<CampaignsSyncOutcome> queue = [];
  int calls = 0;

  // Consumes queued outcomes in order, then repeats the last one forever —
  // never drops to empty-and-throws on a second call once at least one
  // outcome was queued, unlike a plain removeAt(0)-or-.last would.
  @override
  Future<CampaignsSyncOutcome> fetchCampaigns() async {
    calls++;
    return queue.length > 1 ? queue.removeAt(0) : queue.first;
  }
}

/// Same scripted-queue pattern, for the member-progress/history endpoints.
class _FakeLoyaltyMember implements LoyaltyMemberRemoteDatasource {
  final List<MyCardsOutcome> cardsQueue = [];
  final List<MyTransactionsOutcome> transactionsQueue = [];
  int cardsCalls = 0;
  int transactionsCalls = 0;

  // Defaults to an empty-but-successful outcome when nothing (or nothing
  // more) was queued, rather than the "repeat the last queued value"
  // convention `_FakeCatalog` uses — sync() always calls both of these
  // together once a userId is given, so a test that only cares about one of
  // them would otherwise crash on the other's untouched, empty queue.
  @override
  Future<MyCardsOutcome> fetchMyCards() async {
    cardsCalls++;
    if (cardsQueue.isEmpty) return const MyCardsSucceeded([]);
    return cardsQueue.length > 1 ? cardsQueue.removeAt(0) : cardsQueue.first;
  }

  @override
  Future<MyTransactionsOutcome> fetchMyTransactions() async {
    transactionsCalls++;
    if (transactionsQueue.isEmpty) return const MyTransactionsSucceeded([]);
    return transactionsQueue.length > 1
        ? transactionsQueue.removeAt(0)
        : transactionsQueue.first;
  }

  @override
  Future<MemberQrOutcome> fetchMemberQrCard() async =>
      throw UnimplementedError('not exercised by SyncManager');
}

Future<bool> _online() async => true;
Future<bool> _offline() async => false;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  // A real ApiClient is never actually called — SyncManager only touches it
  // when no fake `catalog` is supplied, which every test here overrides.
  ApiClient apiClient() => ApiClient(const FlutterSecureStorage());

  Future<Campaign?> findByCode(String code) async {
    return (db.select(db.campaigns)..where((c) => c.code.equals(code)))
        .getSingleOrNull();
  }

  group('SyncManager — pulling the campaign catalogue', () {
    test('upserts a new campaign and fires onCatalogUpdated', () async {
      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncSucceeded([
          RemoteCampaign(
            code: 'SP-1',
            name: 'CBTL Campaign',
            requiredStamps: 12,
            isActive: true,
            emoji: '🍂',
          ),
        ]));
      var updated = false;
      final manager = SyncManager(
        db, apiClient(),
        isOnline: _online,
        catalog: catalog,
        onCatalogUpdated: () => updated = true,
      );

      await manager.sync();

      final row = await findByCode('SP-1');
      expect(row, isNotNull);
      expect(row!.name, 'CBTL Campaign');
      expect(row.requiredStamps, 12);
      expect(row.emoji, '🍂');
      expect(row.isActive, isTrue);
      expect(updated, isTrue);
      expect(catalog.calls, 1);
    });

    test('updates an existing row with the same code rather than duplicating',
        () async {
      await db.into(db.campaigns).insert(CampaignsCompanion.insert(
            code: 'SP-1',
            name: 'Old Name',
            requiredStamps: const Value(5),
          ));

      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncSucceeded([
          RemoteCampaign(
              code: 'SP-1', name: 'New Name', requiredStamps: 20, isActive: true),
        ]));
      final manager = SyncManager(db, apiClient(), isOnline: _online, catalog: catalog);

      await manager.sync();

      final all = await db.select(db.campaigns).get();
      expect(all, hasLength(1));
      expect(all.single.name, 'New Name');
      expect(all.single.requiredStamps, 20);
    });

    test('deactivates a local campaign the server no longer returns',
        () async {
      await db.into(db.campaigns).insert(CampaignsCompanion.insert(
            code: 'DEMO_SEED',
            name: 'Demo Seed Campaign',
            isActive: const Value(true),
          ));

      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncSucceeded([
          RemoteCampaign(code: 'SP-1', name: 'Real Campaign', requiredStamps: 10, isActive: true),
        ]));
      final manager = SyncManager(db, apiClient(), isOnline: _online, catalog: catalog);

      await manager.sync();

      final demo = await findByCode('DEMO_SEED');
      expect(demo, isNotNull); // never deleted...
      expect(demo!.isActive, isFalse); // ...only deactivated

      final real = await findByCode('SP-1');
      expect(real!.isActive, isTrue);
    });

    test('an empty campaign list deactivates every local campaign', () async {
      await db.into(db.campaigns).insert(CampaignsCompanion.insert(
            code: 'DEMO_SEED',
            name: 'Demo Seed Campaign',
            isActive: const Value(true),
          ));

      final catalog = _FakeCatalog()..queue.add(const CampaignsSyncSucceeded([]));
      final manager = SyncManager(db, apiClient(), isOnline: _online, catalog: catalog);

      await manager.sync();

      final demo = await findByCode('DEMO_SEED');
      expect(demo!.isActive, isFalse);
    });

    test('a malformed row with an empty code is skipped, not a crash',
        () async {
      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncSucceeded([
          RemoteCampaign(code: '', name: 'No Code', requiredStamps: 10, isActive: true),
          RemoteCampaign(code: 'SP-1', name: 'Has Code', requiredStamps: 10, isActive: true),
        ]));
      final manager = SyncManager(db, apiClient(), isOnline: _online, catalog: catalog);

      await manager.sync();

      final all = await db.select(db.campaigns).get();
      expect(all, hasLength(1));
      expect(all.single.code, 'SP-1');
    });

    test('server not deployed yet (unsupported) leaves local data untouched',
        () async {
      await db.into(db.campaigns).insert(CampaignsCompanion.insert(
            code: 'DEMO_SEED',
            name: 'Demo Seed Campaign',
            isActive: const Value(true),
          ));

      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncUnsupported('404 from /api/campaigns'));
      var updated = false;
      final manager = SyncManager(
        db, apiClient(),
        isOnline: _online,
        catalog: catalog,
        onCatalogUpdated: () => updated = true,
      );

      await manager.sync();

      final demo = await findByCode('DEMO_SEED');
      expect(demo!.isActive, isTrue); // untouched
      expect(updated, isFalse);
    });

    test('an unreachable server leaves local data untouched', () async {
      await db.into(db.campaigns).insert(CampaignsCompanion.insert(
            code: 'DEMO_SEED',
            name: 'Demo Seed Campaign',
            isActive: const Value(true),
          ));

      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncUnreachable('No connection.'));
      final manager = SyncManager(db, apiClient(), isOnline: _online, catalog: catalog);

      await manager.sync();

      final demo = await findByCode('DEMO_SEED');
      expect(demo!.isActive, isTrue);
    });

    test('sync() never touches the catalog while offline', () async {
      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncSucceeded([
          RemoteCampaign(code: 'SP-1', name: 'X', requiredStamps: 10, isActive: true),
        ]));
      final manager = SyncManager(db, apiClient(), isOnline: _offline, catalog: catalog);

      await manager.sync();

      expect(catalog.calls, 0);
      expect(await findByCode('SP-1'), isNull);
    });

    test('a second concurrent sync() call is a no-op while one is in flight',
        () async {
      final catalog = _FakeCatalog()
        ..queue.add(const CampaignsSyncSucceeded([
          RemoteCampaign(code: 'SP-1', name: 'X', requiredStamps: 10, isActive: true),
        ]));
      final manager = SyncManager(db, apiClient(), isOnline: _online, catalog: catalog);

      final first = manager.sync();
      final second = manager.sync(); // manager._isSyncing is already true
      await Future.wait([first, second]);

      expect(catalog.calls, 1);
    });
  });

  group('SyncManager — pulling real stamp progress', () {
    // A campaign must exist locally before progress can attach to it —
    // every test here seeds one via a fake catalog that sync() pulls first.
    _FakeCatalog catalogWith(String code) => _FakeCatalog()
      ..queue.add(CampaignsSyncSucceeded([
        RemoteCampaign(code: code, name: 'CBTL Campaign', requiredStamps: 12, isActive: true),
      ]));

    test('creates a local card for a member with no card yet', () async {
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([
          RemoteCardProgress(code: 'SP-1', stampsCount: 4, stampsRequired: 12, status: 'active'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final campaign = await findByCode('SP-1');
      final card = await (db.select(db.stampCards)
            ..where((s) => s.userId.equals('user-1') & s.campaignId.equals(campaign!.id)))
          .getSingle();
      expect(card.stampsCollected, 4);
      expect(card.completedAt, isNull);
    });

    test('updates an existing card rather than duplicating it', () async {
      final campaign = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(code: 'SP-1', name: 'X', requiredStamps: const Value(12)),
          );
      await db.into(db.stampCards).insert(
            StampCardsCompanion.insert(
                userId: 'user-1', campaignId: campaign.id, stampsCollected: const Value(2)),
          );

      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([
          RemoteCardProgress(code: 'SP-1', stampsCount: 9, stampsRequired: 12, status: 'active'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final cards = await (db.select(db.stampCards)..where((s) => s.userId.equals('user-1'))).get();
      expect(cards, hasLength(1));
      expect(cards.single.stampsCollected, 9);
    });

    test('a card with no matching local campaign yet is skipped, not a crash',
        () async {
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([
          RemoteCardProgress(code: 'SP-UNKNOWN', stampsCount: 1, stampsRequired: 12, status: 'active'),
        ]));
      // Catalog pull returns nothing matching SP-UNKNOWN.
      final manager = SyncManager(db, apiClient(),
          isOnline: _online,
          catalog: _FakeCatalog()..queue.add(const CampaignsSyncSucceeded([])),
          loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      expect(await db.select(db.stampCards).get(), isEmpty);
    });

    test('a server-side redemption closes the local card', () async {
      final campaign = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(code: 'SP-1', name: 'X', requiredStamps: const Value(12)),
          );
      await db.into(db.stampCards).insert(
            StampCardsCompanion.insert(
              userId: 'user-1',
              campaignId: campaign.id,
              remoteCardId: const Value('77'),
              redeemToken: const Value('LRDM1:77:abc'),
              stampsCollected: const Value(12),
              completedAt: Value(DateTime.utc(2026, 1, 1)),
            ),
          );

      final redeemedAt = DateTime.utc(2026, 9, 4, 10, 30);
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(MyCardsSucceeded([
          RemoteCardProgress(
            code: 'SP-1',
            cardId: '77',
            stampsCount: 12,
            stampsRequired: 12,
            status: 'redeemed',
            redeemedAt: redeemedAt,
          ),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final card = await (db.select(db.stampCards)
            ..where((s) => s.remoteCardId.equals('77')))
          .getSingle();
      expect(card.redeemedAt, redeemedAt,
          reason: 'the reward was handed over — the card must not still read as claimable');
      // The whole point: no stale code left on a spent card.
      expect(card.redeemToken, isNull);
    });

    test('the replacement card issued after a redemption is a separate row',
        () async {
      final campaign = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(code: 'SP-1', name: 'X', requiredStamps: const Value(12)),
          );
      await db.into(db.stampCards).insert(
            StampCardsCompanion.insert(
              userId: 'user-1',
              campaignId: campaign.id,
              remoteCardId: const Value('77'),
              stampsCollected: const Value(12),
              redeemedAt: Value(DateTime.utc(2026, 9, 4)),
            ),
          );

      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(MyCardsSucceeded([
          RemoteCardProgress(
            code: 'SP-1',
            cardId: '77',
            stampsCount: 12,
            stampsRequired: 12,
            status: 'redeemed',
            redeemedAt: DateTime.utc(2026, 9, 4),
          ),
          // Same campaign code, different server card — the state ghelpdesk
          // is in the moment staff scan the member again after a redemption.
          const RemoteCardProgress(
            code: 'SP-1',
            cardId: '78',
            stampsCount: 1,
            stampsRequired: 12,
            status: 'active',
          ),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final cards = await (db.select(db.stampCards)
            ..where((s) => s.userId.equals('user-1'))
            ..orderBy([(s) => OrderingTerm.asc(s.cycle)]))
          .get();
      expect(cards, hasLength(2),
          reason: 'keying on the campaign code alone would have merged these');
      expect(cards.first.redeemedAt, isNotNull);
      expect(cards.last.stampsCollected, 1);
      expect(cards.last.redeemedAt, isNull);
      expect(cards.map((c) => c.cycle), [1, 2]);
    });

    test('a pre-existing local card is adopted by the server card once', () async {
      final campaign = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(code: 'SP-1', name: 'X', requiredStamps: const Value(12)),
          );
      // Written before remoteCardId existed — no server identity yet.
      await db.into(db.stampCards).insert(
            StampCardsCompanion.insert(
                userId: 'user-1', campaignId: campaign.id, stampsCollected: const Value(3)),
          );

      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([
          RemoteCardProgress(
              code: 'SP-1', cardId: '77', stampsCount: 5, stampsRequired: 12, status: 'active'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final cards = await (db.select(db.stampCards)..where((s) => s.userId.equals('user-1'))).get();
      expect(cards, hasLength(1), reason: 'adoption must not fork a second card');
      expect(cards.single.remoteCardId, '77');
      expect(cards.single.stampsCollected, 5);
    });

    test('a full card carries the redeem code the member shows staff', () async {
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([
          RemoteCardProgress(
            code: 'SP-1',
            cardId: '77',
            stampsCount: 12,
            stampsRequired: 12,
            status: 'completed',
            redeemToken: 'LRDM1:77:0123456789abcdef01234567',
          ),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final card = await (db.select(db.stampCards)
            ..where((s) => s.userId.equals('user-1')))
          .getSingle();
      expect(card.redeemToken, 'LRDM1:77:0123456789abcdef01234567');
      expect(card.completedAt, isNotNull);
      expect(card.redeemedAt, isNull);
    });

    test('sync() without a userId skips progress entirely', () async {
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([
          RemoteCardProgress(code: 'SP-1', stampsCount: 4, stampsRequired: 12, status: 'active'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(); // no userId

      expect(loyaltyMember.cardsCalls, 0);
      expect(await db.select(db.stampCards).get(), isEmpty);
    });
  });

  group('SyncManager — pulling real transaction history', () {
    _FakeCatalog catalogWith(String code) => _FakeCatalog()
      ..queue.add(CampaignsSyncSucceeded([
        RemoteCampaign(code: code, name: 'CBTL Campaign', requiredStamps: 12, isActive: true),
      ]));

    _FakeLoyaltyMember memberWithNoCards() =>
        _FakeLoyaltyMember()..cardsQueue.add(const MyCardsSucceeded([]));

    test('upserts a real earn as a local transaction', () async {
      final loyaltyMember = memberWithNoCards()
        ..transactionsQueue.add(const MyTransactionsSucceeded([
          RemoteTransaction(
            reference: 'SE-42',
            type: 'earn',
            points: 1,
            campaignCode: 'SP-1',
            storeName: 'A30 — CBTL Ayala 30th',
          ),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final row = await (db.select(db.loyaltyTransactions)
            ..where((t) => t.reference.equals('SE-42')))
          .getSingle();
      expect(row.type, txnEarn);
      expect(row.points, 1);
      expect(row.storeName, 'A30 — CBTL Ayala 30th');
      expect(row.userId, 'user-1');
    });

    test('a redemption with no server product name gets the same wording '
        'local redeemReward uses', () async {
      final loyaltyMember = memberWithNoCards()
        ..transactionsQueue.add(const MyTransactionsSucceeded([
          RemoteTransaction(
            reference: 'SR-7',
            type: 'redeem',
            points: -12,
            campaignCode: 'SP-1',
          ),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final row = await (db.select(db.loyaltyTransactions)
            ..where((t) => t.reference.equals('SR-7')))
          .getSingle();
      expect(row.type, txnRedeem);
      expect(row.points, -12);
      expect(row.productName, 'CBTL Campaign (Free Reward)');
    });

    test('a redemption WITH a server product name keeps it as-is', () async {
      final loyaltyMember = memberWithNoCards()
        ..transactionsQueue.add(const MyTransactionsSucceeded([
          RemoteTransaction(
            reference: 'SR-8',
            type: 'redeem',
            points: -12,
            campaignCode: 'SP-1',
            productName: 'Free Latte',
          ),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final row = await (db.select(db.loyaltyTransactions)
            ..where((t) => t.reference.equals('SR-8')))
          .getSingle();
      expect(row.productName, 'Free Latte');
    });

    test('re-syncing the same reference updates in place, never duplicates',
        () async {
      final loyaltyMember = memberWithNoCards()
        ..transactionsQueue.addAll([
          const MyTransactionsSucceeded([
            RemoteTransaction(reference: 'SE-1', type: 'earn', points: 1, campaignCode: 'SP-1'),
          ]),
          const MyTransactionsSucceeded([
            RemoteTransaction(
                reference: 'SE-1', type: 'earn', points: 1, campaignCode: 'SP-1',
                storeName: 'Updated Store'),
          ]),
        ]);
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');
      await manager.sync(userId: 'user-1');

      final rows = await (db.select(db.loyaltyTransactions)
            ..where((t) => t.reference.equals('SE-1')))
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.storeName, 'Updated Store');
    });

    test('links stampCardId to the member\'s local card for that campaign',
        () async {
      final campaign = await db.into(db.campaigns).insertReturning(
            CampaignsCompanion.insert(code: 'SP-1', name: 'X', requiredStamps: const Value(12)),
          );
      final card = await db.into(db.stampCards).insertReturning(
            StampCardsCompanion.insert(userId: 'user-1', campaignId: campaign.id),
          );
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([]))
        ..transactionsQueue.add(const MyTransactionsSucceeded([
          RemoteTransaction(reference: 'SE-1', type: 'earn', points: 1, campaignCode: 'SP-1'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online,
          catalog: _FakeCatalog()
            ..queue.add(const CampaignsSyncSucceeded([
              RemoteCampaign(code: 'SP-1', name: 'X', requiredStamps: 12, isActive: true),
            ])),
          loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final row = await (db.select(db.loyaltyTransactions)
            ..where((t) => t.reference.equals('SE-1')))
          .getSingle();
      expect(row.stampCardId, card.id);
    });

    test('a transaction with no matching local campaign is skipped', () async {
      final loyaltyMember = _FakeLoyaltyMember()
        ..cardsQueue.add(const MyCardsSucceeded([]))
        ..transactionsQueue.add(const MyTransactionsSucceeded([
          RemoteTransaction(reference: 'SE-1', type: 'earn', points: 1, campaignCode: 'SP-UNKNOWN'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online,
          catalog: _FakeCatalog()..queue.add(const CampaignsSyncSucceeded([])),
          loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      expect(await db.select(db.loyaltyTransactions).get(), isEmpty);
    });

    test('sync() without a userId never touches transaction history', () async {
      final loyaltyMember = _FakeLoyaltyMember()
        ..transactionsQueue.add(const MyTransactionsSucceeded([
          RemoteTransaction(reference: 'SE-1', type: 'earn', points: 1, campaignCode: 'SP-1'),
        ]));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync();

      expect(loyaltyMember.transactionsCalls, 0);
    });

    test('server not deployed yet leaves local history untouched', () async {
      await db.into(db.loyaltyTransactions).insert(
            LoyaltyTransactionsCompanion.insert(
                reference: 'LOCAL-1', userId: 'user-1', type: txnEarn),
          );
      final loyaltyMember = memberWithNoCards()
        ..transactionsQueue.add(
            const MyTransactionsUnsupported('404 from /api/loyalty/my-transactions'));
      final manager = SyncManager(db, apiClient(),
          isOnline: _online, catalog: catalogWith('SP-1'), loyaltyMember: loyaltyMember);

      await manager.sync(userId: 'user-1');

      final rows = await db.select(db.loyaltyTransactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.reference, 'LOCAL-1');
    });
  });
}
