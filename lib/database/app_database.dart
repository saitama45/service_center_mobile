import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/rbac_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/loyalty_tables.dart';
import 'daos/role_dao.dart';
import 'daos/permission_dao.dart';
import 'daos/module_dao.dart';
import 'daos/user_dao.dart';
import 'daos/session_dao.dart';
import 'daos/permission_matrix_dao.dart';
import 'daos/audit_log_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/loyalty_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Roles,
    Permissions,
    Modules,
    Users,
    RoleModulePermissions,
    Sessions,
    AuditLogs,
    SyncLog,
    AppSettings,
    Products,
    Campaigns,
    StampCards,
    LoyaltyTransactions,
  ],
  daos: [
    RoleDao,
    PermissionDao,
    ModuleDao,
    UserDao,
    SessionDao,
    PermissionMatrixDao,
    AuditLogDao,
    SettingsDao,
    LoyaltyDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v4 replaced the DTR/attendance tables with the loyalty schema.
          // The old tables carried only cached server data and a local upload
          // queue, so dropping them loses nothing that isn't re-derivable.
          if (from < 4) {
            for (final legacy in const [
              'offline_dtr_logs',
              'cached_dtr_schedules',
              'cached_attendance_logs',
            ]) {
              await m.database.customStatement('DROP TABLE IF EXISTS $legacy');
            }
            await m.createTable(products);
            await m.createTable(campaigns);
            await m.createTable(stampCards);
            await m.createTable(loyaltyTransactions);
          }

          // v5 made redemption server-authoritative: a card now carries
          // ghelpdesk's own id (so a redeemed card and its replacement stay
          // distinct locally) and the signed code the member shows staff to
          // claim the reward. Both are additive and nullable — existing rows
          // stay valid and are backfilled by the next progress pull.
          if (from < 5) {
            await m.addColumn(stampCards, stampCards.remoteCardId);
            await m.addColumn(stampCards, stampCards.redeemToken);
          }

          // v6 clears the phantom redemptions the retired on-device redeem
          // path left in the ledger.
          //
          // Until v5, tapping "Redeem Now" wrote a local `redeem` row that no
          // server event ever backed. Once ghelpdesk's real redemption
          // started syncing down (`SR-…`), a member saw the SAME redemption
          // twice — e.g. the real "OREO TUMBLER" plus a local "CBTL Campaign
          // (Free Reward)" — and the History totals double-counted it
          // (redeemed −24 against +12 earned).
          //
          // A never-synced `redeem` row is now, by construction, one of those
          // phantoms: redeeming is server-authoritative, `redeemReward` has
          // no UI caller left, and every genuine redemption arrives already
          // synced from `/api/loyalty/my-transactions`. Running this once at
          // upgrade time is what makes that reasoning airtight — it can only
          // ever see rows written by the retired path.
          //
          // Deliberately limited to redemptions. A never-synced `earn` row is
          // NOT safely removable the same way: it can be the only record of a
          // stamp that never reached the server, so deleting it would shrink
          // a member's history with nothing taking its place. A phantom
          // redeem always has a real server twin.
          //
          // Cards are handled separately, in v7 below.
          if (from < 6) {
            await m.database.customStatement(
              'DELETE FROM loyalty_transactions '
              'WHERE type = ? AND sync_status = ?',
              [txnRedeem, loyaltySyncPending],
            );
          }

          // v7 removes the closed CARDS that same retired path left behind.
          //
          // v6 cleared its ledger rows but deliberately left the cards, on the
          // reasoning that a redeemed card is invisible to every screen. The
          // Rewards tab then started listing redeemed cards on purpose, which
          // made them visible after all: a member saw TWO claimed cards for a
          // campaign ghelpdesk had only ever redeemed once.
          //
          // The predicate names exactly that leftover and nothing else:
          //   * `remote_card_id IS NULL` — ghelpdesk has never acknowledged
          //     this card. A real redemption always arrives attached to a
          //     server card id.
          //   * `redeemed_at IS NOT NULL` — it is closed. An OPEN card with no
          //     server id is untouched: that is a card the server simply
          //     hasn't caught up with, not a fiction.
          //   * `sync_status = pending` — it was never reconciled upward.
          //
          // The NOT EXISTS guard is the safety net: if any ledger row still
          // points at the card, it stays, because deleting it would orphan
          // real history (`loyalty_transactions.stamp_card_id` references
          // this table) to tidy up a duplicate. Losing a member's record is
          // the worse failure of the two.
          if (from < 7) {
            await m.database.customStatement(
              'DELETE FROM stamp_cards '
              'WHERE remote_card_id IS NULL '
              '  AND redeemed_at IS NOT NULL '
              '  AND sync_status = ? '
              '  AND NOT EXISTS ('
              '    SELECT 1 FROM loyalty_transactions t '
              '    WHERE t.stamp_card_id = stamp_cards.id'
              '  )',
              [loyaltySyncPending],
            );
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_database.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
