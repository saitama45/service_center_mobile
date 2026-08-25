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
import '../../../database/app_database.dart';
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
    final totals = ref.watch(ledgerTotalsProvider);

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
            final t = totals.valueOrNull;

            final earned = t?.earned ?? 0;
            final redeemed = t?.redeemed ?? 0;

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
                        label: 'Earned',
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
                        label: 'Redeemed',
                        value: _signed(redeemed, '−'),
                        color: redeemed > 0
                            ? AppColors.danger
                            : AppColors.espresso,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Total(
                        // Not "how many more to my next reward" — that's
                        // campaign-specific and already on Home ("9 more to
                        // unlock"). This is a lifetime net total across
                        // every campaign, so it needs its own, unambiguous
                        // label rather than borrowing "Balance", which reads
                        // like the former to most people.
                        label: 'Total Stamps',
                        value: '${t?.balance ?? 0}',
                        color: AppColors.espresso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),

                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: BmsEmptyState(
                      title: 'No activity yet',
                      message:
                          'Scan the code at checkout to collect your first stamp.',
                      icon: Icons.receipt_long_outlined,
                    ),
                  )
                else
                  ...list.map((txn) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TransactionRow(txn: txn),
                      )),
              ],
            );
          },
        ),
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
  const _TransactionRow({required this.txn});
  final LoyaltyTransaction txn;

  @override
  Widget build(BuildContext context) {
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
