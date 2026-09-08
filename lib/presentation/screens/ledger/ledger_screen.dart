import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/bms_card.dart';
import '../../../core/widgets/bms_empty_state.dart';
import '../../../database/daos/loyalty_dao.dart';
import '../../../database/tables/loyalty_tables.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';

/// Prefixes a total with its sign, but leaves a zero unsigned — "−0" is
/// meaningless and reads like a bug.
String _signed(int value, String sign) => value == 0 ? '0' : '$sign$value';

/// Full stamp history — every earn and redemption, newest first.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(
        title: 'History',
        subtitle: 'Your stamp activity',
      ),
      body: RefreshIndicator(
        color: AppColors.amber,
        backgroundColor: AppColors.white,
        // Real server sync — transactions now have a genuine pull direction
        // (SyncManager._pullTransactions), not just local `loyalty_transactions`
        // rows. See the same comment in campaigns_screen.dart / home_screen.dart.
        onRefresh: () => ref
            .read(syncManagerProvider)
            .sync(userId: ref.read(currentUserProvider)?.id),
        child: txns.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.amber)),
          error: (e, _) => BmsEmptyState(
            title: 'Could not load history',
            message: '$e',
            icon: Icons.error_outline,
          ),
          data: (list) {
            final selectedId = ref.watch(ledgerCampaignFilterProvider);
            final onCards = ref.watch(openCardStampsProvider).valueOrNull ?? {};

            // The campaigns this member actually has history for, in the order
            // they last appeared — offering a campaign with nothing to show
            // would just be a dead end.
            final campaigns = <String, String>{};
            for (final e in list) {
              final id = e.transaction.campaignId;
              if (id != null) campaigns[id] = e.campaignName ?? 'Campaign';
            }

            // A filter that no longer matches anything (its campaign dropped
            // out of the window of rows we hold) falls back to "All" rather
            // than showing an empty screen with no way back.
            final activeId =
                selectedId != null && campaigns.containsKey(selectedId)
                    ? selectedId
                    : null;

            final rows = activeId == null
                ? list
                : list
                    .where((e) => e.transaction.campaignId == activeId)
                    .toList();

            // Totals are computed from the rows on screen, so the numbers can
            // never disagree with the list under them.
            var earned = 0;
            var rewards = 0;
            for (final e in rows) {
              if (e.transaction.type == txnEarn) {
                earned += e.transaction.points;
              } else {
                // Counted as rewards, not as the stamps they consumed. "−36"
                // was arithmetically true but nobody thinks "I spent 36
                // stamps"; they think "I claimed 3 rewards".
                rewards += 1;
              }
            }

            final held = activeId == null
                ? onCards.values.fold<int>(0, (sum, v) => sum + v)
                : (onCards[activeId] ?? 0);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppDimensions.md,
                  AppDimensions.md, AppDimensions.md, 32),
              children: [
                // ── Summary strip ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _Total(
                        label: 'Stamps earned',
                        value: _signed(earned, '+'),
                        // Zero is neutral — colouring it green implies activity.
                        color: earned > 0
                            ? AppColors.success
                            : AppColors.espresso,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Total(
                        label: rewards == 1 ? 'Reward claimed' : 'Rewards claimed',
                        value: '$rewards',
                        color: rewards > 0
                            ? AppColors.amber
                            : AppColors.espresso,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Total(
                        // Counted off the member's actual cards, not derived
                        // as `earned - redeemed` — see
                        // `LoyaltyDao.getOpenCardStampsByCampaign`. This is
                        // the one figure they can check against the cards in
                        // front of them.
                        label: 'On your cards',
                        value: '$held',
                        color: AppColors.espresso,
                      ),
                    ),
                  ],
                ),

                // ── Campaign filter ────────────────────────────────────────
                // Stamps are not interchangeable between campaigns, so a
                // single pooled figure answers nothing a member can act on.
                // Scoping the whole screen — list and totals together — is
                // what turns it into "how am I doing on this one?".
                if (campaigns.length > 1) ...[
                  const SizedBox(height: AppDimensions.sm + 2),
                  _CampaignFilterBar(
                    campaigns: campaigns,
                    selectedId: activeId,
                    onSelect: (id) => ref
                        .read(ledgerCampaignFilterProvider.notifier)
                        .state = id,
                  ),
                ],
                const SizedBox(height: AppDimensions.md),

                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: BmsEmptyState(
                      title: list.isEmpty
                          ? 'No activity yet'
                          : 'Nothing on this campaign yet',
                      message: list.isEmpty
                          ? 'Scan the code at checkout to collect your first stamp.'
                          : 'Stamps you collect on this campaign will show up here.',
                      icon: Icons.receipt_long_outlined,
                    ),
                  )
                else
                  ...rows.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TransactionRow(entry: entry),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Horizontal chips scoping History to one campaign — "All" plus every
/// campaign the member has activity on.
class _CampaignFilterBar extends StatelessWidget {
  const _CampaignFilterBar({
    required this.campaigns,
    required this.selectedId,
    required this.onSelect,
  });

  /// Campaign id → display name.
  final Map<String, String> campaigns;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = campaigns.entries.toList();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final id = i == 0 ? null : entries[i - 1].key;
          final label = i == 0 ? 'All' : entries[i - 1].value;
          final selected = id == selectedId;

          return GestureDetector(
            onTap: () => onSelect(id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.espresso : AppColors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.espresso : AppColors.latte,
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.chip.copyWith(
                  color: selected ? AppColors.cream : AppColors.espresso,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BmsCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.monoMedium
                .copyWith(fontSize: 17, color: color),
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final txn = entry.transaction;
    final isEarn = txn.type == txnEarn;
    final local = txn.occurredAt.toLocal();

    return BmsCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isEarn ? AppColors.latteLight : AppColors.dangerSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Text(isEarn ? '☕' : '🎁',
                style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        txn.productName ?? (isEarn ? 'Stamp earned' : 'Reward redeemed'),
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEarn ? '+${txn.points}' : '−${txn.points.abs()}',
                      style: AppTextStyles.monoMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isEarn ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                // Which card this landed on. A member collecting on more
                // than one campaign cannot otherwise tell "+3 stamps" apart
                // from "+3 stamps" — the store says where, not what for.
                if (entry.campaignName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.campaignName!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.espresso),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (txn.storeName != null) ...[
                  const SizedBox(height: 2),
                  Text(txn.storeName!, style: AppTextStyles.caption),
                ],
                const SizedBox(height: 3),
                // The sync reference (e.g. "SE-19") used to show here too —
                // it's an internal identifier from the server, meaningless
                // to a member and unreadable at that size/color besides.
                Text(
                  '${DateFormat('MMM d').format(local)} at ${DateFormat('HH:mm').format(local)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
