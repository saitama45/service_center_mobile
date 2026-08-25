import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'rbac_tables.dart';

/// Sync status shared by every loyalty table that can be created offline.
const int loyaltySyncPending = 0;
const int loyaltySynced = 1;
const int loyaltySyncing = 2;
const int loyaltySyncFailed = 3;

/// Transaction kinds recorded in the ledger.
const String txnEarn = 'earn';
const String txnRedeem = 'redeem';

// ── products ──────────────────────────────────────────────────────────────────

/// Items a stamp can be earned on. Campaigns reference these by code so a
/// campaign can be limited to, say, hot drinks only.
class Products extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};

  /// Stable external identifier (e.g. PROD-001) used by campaign rules.
  TextColumn get code => text().withLength(max: 40)();
  TextColumn get name => text().withLength(max: 120)();
  TextColumn get category => text().withLength(max: 60).nullable()();
  TextColumn get emoji => text().withLength(max: 8).nullable()();
  RealColumn get price => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {code}
      ];
}

// ── campaigns ─────────────────────────────────────────────────────────────────

/// A stamp-collection promotion. `requiredStamps` stamps on any product whose
/// code appears in `eligibleProductCodes` earns the reward.
class Campaigns extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get code => text().withLength(max: 40)();
  TextColumn get name => text().withLength(max: 120)();
  TextColumn get description => text().nullable()();
  TextColumn get emoji => text().withLength(max: 8).nullable()();

  /// Display grouping — drives the filter chips on the campaigns screen.
  TextColumn get tag => text().withLength(max: 40).nullable()();

  IntColumn get requiredStamps => integer().withDefault(const Constant(10))();

  /// Comma-separated product codes. Empty means every product qualifies.
  TextColumn get eligibleProductCodes => text().withDefault(const Constant(''))();

  TextColumn get rewardDescription => text().nullable()();
  TextColumn get termsAndConditions => text().nullable()();

  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  IntColumn get syncStatus =>
      integer().withDefault(const Constant(loyaltySyncPending))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {code}
      ];
}

// ── stamp_cards ───────────────────────────────────────────────────────────────

/// One member's progress on one campaign. A new card is opened when the
/// previous one is redeemed, so `cycle` tracks how many times they've completed
/// this campaign.
class StampCards extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get userId => text().references(Users, #id)();
  TextColumn get campaignId => text().references(Campaigns, #id)();

  IntColumn get stampsCollected => integer().withDefault(const Constant(0))();
  IntColumn get cycle => integer().withDefault(const Constant(1))();

  /// Set once the card fills up; cleared onto a fresh card after redemption.
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get redeemedAt => dateTime().nullable()();

  IntColumn get syncStatus =>
      integer().withDefault(const Constant(loyaltySyncPending))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// One open card per member per campaign per cycle.
  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, campaignId, cycle}
      ];
}

// ── loyalty_transactions ──────────────────────────────────────────────────────

/// The ledger. Every stamp earned and every reward redeemed lands here, so the
/// history screen and the stamp counts are derived from the same source.
class LoyaltyTransactions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  @override
  Set<Column> get primaryKey => {id};

  /// Human-facing reference shown in the ledger (e.g. TXN-8821).
  TextColumn get reference => text().withLength(max: 40)();

  TextColumn get userId => text().references(Users, #id)();
  TextColumn get campaignId => text().nullable().references(Campaigns, #id)();
  TextColumn get stampCardId => text().nullable().references(StampCards, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();

  /// 'earn' or 'redeem' — see [txnEarn] / [txnRedeem].
  TextColumn get type => text().withLength(max: 12)();

  /// Positive for earn, negative for redeem.
  IntColumn get points => integer().withDefault(const Constant(1))();

  TextColumn get productName => text().nullable()();
  TextColumn get storeName => text().nullable()();

  /// The one-time token this transaction was claimed with — the uniqueness
  /// constraint is what makes a scanned QR code non-replayable.
  TextColumn get scanToken => text().nullable()();

  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get syncStatus =>
      integer().withDefault(const Constant(loyaltySyncPending))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {reference},
        {scanToken},
      ];
}
