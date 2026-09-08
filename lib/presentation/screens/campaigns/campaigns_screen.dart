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
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import 'redeem_qr_sheet.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

/// Which cards the Rewards tab is showing.
///
/// [all] is the default so the tab is never mysteriously empty: a member
/// whose only cards are redeemed used to land on "You haven't started a card
/// yet" while History showed the reward they'd just claimed.
enum _CardFilter { all, current, redeemed }

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  static const _allTag = 'All';
  String _activeTag = _allTag;
  String? _expandedId;
  _CardFilter _filter = _CardFilter.all;

  @override
  Widget build(BuildContext context) {
    // Every card, redeemed included — unlike the home hero, this tab is the
    // member's whole stamp-card history.
    final async = ref.watch(campaignCardsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(
        title: 'Campaigns',
        subtitle: 'Earn stamps, unlock rewards',
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => BmsEmptyState(
          title: 'Could not load campaigns',
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (all) {
          if (all.isEmpty) {
            return const BmsEmptyState(
              title: "You haven't started a card yet",
              message: 'Show your member code at checkout and staff will '
                  'add your first stamp — your campaigns will show up here.',
              icon: Icons.local_cafe_outlined,
            );
          }

          // Tags are derived from the data, so a new campaign tag shows up
          // as a filter chip without any code change.
          final tags = <String>{
            _allTag,
            ...all.map((p) => p.campaign.tag).whereType<String>(),
          }.toList();

          final currentCount = all.where((p) => !p.isRedeemed).length;
          final redeemedCount = all.length - currentCount;

          final visible = all.where((p) {
            final matchesStatus = switch (_filter) {
              _CardFilter.all => true,
              _CardFilter.current => !p.isRedeemed,
              _CardFilter.redeemed => p.isRedeemed,
            };
            final matchesTag =
                _activeTag == _allTag || p.campaign.tag == _activeTag;
            return matchesStatus && matchesTag;
          }).toList();

          return Column(
            children: [
              _StatusFilter(
                active: _filter,
                allCount: all.length,
                currentCount: currentCount,
                redeemedCount: redeemedCount,
                onSelect: (f) => setState(() => _filter = f),
              ),
              // Only worth the row when there's more than one tag to pick
              // between — "All" alone filters nothing.
              if (tags.length > 1)
                _TagFilter(
                  tags: tags,
                  active: _activeTag,
                  onSelect: (t) => setState(() => _activeTag = t),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.amber,
                  backgroundColor: AppColors.white,
                  // A real server sync, not just a local re-query — pulling
                  // down only bumps loyaltyRevisionProvider AFTER sync()
                  // actually reaches the catalog endpoint (see SyncManager's
                  // onCatalogUpdated), otherwise a campaign the staff just
                  // added never appears until the next cold start. The
                  // userId is what also pulls real progress, so a stamp
                  // ghelpdesk staff just scanned in shows up here too.
                  onRefresh: () => ref
                      .read(syncManagerProvider)
                      .sync(userId: ref.read(currentUserProvider)?.id),
                  child: visible.isEmpty
                      ? BmsEmptyState(
                          title: switch (_filter) {
                            _CardFilter.current => 'No cards in play',
                            _CardFilter.redeemed => 'No rewards claimed yet',
                            _CardFilter.all => 'Nothing here',
                          },
                          message: switch (_filter) {
                            _CardFilter.current =>
                              'Every card you have has been redeemed. Show '
                                  'your member code at checkout to start a '
                                  'new one.',
                            _CardFilter.redeemed =>
                              'Rewards you claim will be kept here.',
                            _CardFilter.all => 'No cards match this filter.',
                          },
                          icon: Icons.filter_alt_off_outlined,
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                              AppDimensions.md, 0, AppDimensions.md, 32),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppDimensions.sm + 4),
                          itemBuilder: (_, i) {
                            final p = visible[i];
                            // Keyed on the CARD, not the campaign: a member
                            // can hold several cards for one campaign now
                            // (each redeemed cycle plus the current one), and
                            // a campaign key would expand all of them at once.
                            final key = p.card?.id ?? p.campaign.id;
                            return _CampaignCard(
                              progress: p,
                              expanded: _expandedId == key,
                              onToggleTerms: () => setState(() {
                                _expandedId = _expandedId == key ? null : key;
                              }),
                              onRedeem: () => _redeem(p),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens the member's redemption code for staff to scan.
  ///
  /// This used to redeem the card on-device and tell the member it was done —
  /// which was a fiction: ghelpdesk holds the real card, and its redemption
  /// deducts specific inventory units that only staff at the counter can
  /// pick. Worse, a card staff had *already* redeemed still showed "Redeem
  /// Now" here, because the progress pull flattened the server's `redeemed`
  /// status into `completed`.
  ///
  /// So redeeming now works exactly like earning a stamp does: the app shows
  /// a signed code, ghelpdesk staff scan it ("Scan Redeem QR"), and the
  /// result comes back down through `SyncManager`. No confirmation dialog —
  /// opening the code spends nothing, so there is nothing to confirm.
  Future<void> _redeem(CampaignProgress p) => showRedeemQrSheet(context, p);
}

// ── Status filter ─────────────────────────────────────────────────────────────

/// Current-vs-redeemed segmented control, with counts so a member can see at
/// a glance that claimed rewards are kept here rather than lost.
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.active,
    required this.allCount,
    required this.currentCount,
    required this.redeemedCount,
    required this.onSelect,
  });

  final _CardFilter active;
  final int allCount;
  final int currentCount;
  final int redeemedCount;
  final ValueChanged<_CardFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final segments = <(_CardFilter, String, int)>[
      (_CardFilter.all, 'All', allCount),
      (_CardFilter.current, 'Current', currentCount),
      (_CardFilter.redeemed, 'Redeemed', redeemedCount),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.md,
          AppDimensions.md, AppDimensions.sm + 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.latteLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
        ),
        child: Row(
          children: [
            for (final (filter, label, count) in segments)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(filter),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filter == active ? AppColors.white : null,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusRound),
                      boxShadow: filter == active ? AppColors.cardShadow : null,
                    ),
                    child: Text(
                      '$label ($count)',
                      style: AppTextStyles.chip.copyWith(
                        color: filter == active
                            ? AppColors.espresso
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.active,
    required this.onSelect,
  });

  final List<String> tags;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Tall enough for the chips plus breathing room below. No top padding:
      // the status filter above already supplies the gap under the app bar.
      height: 40 + AppDimensions.sm + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppDimensions.md, 0, AppDimensions.md, AppDimensions.sm + 4),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final selected = tag == active;
          return GestureDetector(
            onTap: () => onSelect(tag),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.espresso : AppColors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                border: Border.all(
                  color: selected ? AppColors.espresso : AppColors.latte,
                  width: 1.5,
                ),
              ),
              child: Text(
                tag,
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

// ── Campaign card ─────────────────────────────────────────────────────────────

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.progress,
    required this.expanded,
    required this.onToggleTerms,
    required this.onRedeem,
  });

  final CampaignProgress progress;
  final bool expanded;
  final VoidCallback onToggleTerms;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final c = progress.campaign;
    final unlocked = progress.isUnlocked;
    final redeemed = progress.isRedeemed;
    final redeemedAt = progress.card?.redeemedAt;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: unlocked
              ? AppColors.amber
              : redeemed
                  ? AppColors.success
                  : AppColors.latte,
          width: unlocked || redeemed ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unlocked)
            Container(
              width: double.infinity,
              color: AppColors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '🎉  REWARD UNLOCKED — Ready to redeem!',
                style: AppTextStyles.chip.copyWith(color: AppColors.white),
              ),
            ),

          // A claimed reward is a settled fact, so it is stated as firmly as
          // the amber "unlocked" bar states an unclaimed one: a solid success
          // bar, white type, a filled seal. It previously whispered it — muted
          // text on `latteLight` behind the 0.75 opacity below — which read as
          // "greyed out / inactive" rather than "you received this".
          if (redeemed)
            Container(
              width: double.infinity,
              color: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 16, color: AppColors.white),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      redeemedAt == null
                          ? 'REWARD CLAIMED'
                          : 'REWARD CLAIMED — '
                              '${DateFormat('MMM d, y').format(redeemedAt.toLocal())}',
                      style: AppTextStyles.chip.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Only the card's *body* is dimmed. The claim banner stays at full
          // strength — dimming the very label that says "redeemed" was what
          // made it easy to miss.
          Opacity(
            opacity: redeemed ? 0.75 : 1,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.latteLight,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Text(c.emoji ?? '☕',
                            style: const TextStyle(fontSize: 22)),
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
                                  child: Text(c.name, style: AppTextStyles.h3),
                                ),
                                if (c.tag != null) ...[
                                  const SizedBox(width: 8),
                                  BmsStatusPill.neutral(c.tag!),
                                ],
                              ],
                            ),
                            if (c.description != null) ...[
                              const SizedBox(height: 3),
                              Text(c.description!,
                                  style: AppTextStyles.caption),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Row(
                    children: [
                      Text('${progress.stamps} / ${progress.required} stamps',
                          style: AppTextStyles.monoSmall),
                      const Spacer(),
                      if (c.endsAt != null)
                        Text(
                          progress.isExpired
                              ? 'Expired'
                              : 'Expires ${DateFormat('MMM d, y').format(c.endsAt!.toLocal())}',
                          style: AppTextStyles.caption.copyWith(
                            color: progress.isExpired
                                ? AppColors.danger
                                : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  BmsProgressBar(
                    value: progress.progress,
                    gradient: unlocked
                        ? const LinearGradient(
                            colors: [AppColors.amber, AppColors.gold])
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.sm + 2),
                  if (c.termsAndConditions != null)
                    GestureDetector(
                      onTap: onToggleTerms,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 17,
                              color: AppColors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              expanded ? 'Hide Terms' : 'Terms & Conditions',
                              style: AppTextStyles.chip
                                  .copyWith(color: AppColors.amber),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (expanded && c.termsAndConditions != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Text(c.termsAndConditions!,
                          style: AppTextStyles.caption),
                    ),
                  ],
                  if (unlocked) ...[
                    const SizedBox(height: AppDimensions.sm + 4),
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: onRedeem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                        ),
                        child: Text('Redeem Now  →',
                            style: AppTextStyles.button
                                .copyWith(color: AppColors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
