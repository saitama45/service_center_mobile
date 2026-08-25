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
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../database/daos/loyalty_dao.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  static const _allTag = 'All';
  String _activeTag = _allTag;
  String? _expandedId;
  bool _isRedeeming = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(campaignProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(
        title: 'Campaigns',
        subtitle: 'Earn stamps, unlock rewards',
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
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

          final visible = _activeTag == _allTag
              ? all
              : all.where((p) => p.campaign.tag == _activeTag).toList();

          return Column(
            children: [
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
                      ? const BmsEmptyState(
                          title: 'Nothing here',
                          message: 'No campaigns match this filter.',
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
                            return _CampaignCard(
                              progress: p,
                              expanded: _expandedId == p.campaign.id,
                              isBusy: _isRedeeming,
                              onToggleTerms: () => setState(() {
                                _expandedId = _expandedId == p.campaign.id
                                    ? null
                                    : p.campaign.id;
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

  Future<void> _redeem(CampaignProgress p) async {
    if (_isRedeeming) return;

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Redeem reward',
      message: 'Claim your ${p.campaign.rewardDescription ?? p.campaign.name}? '
          'This uses all ${p.required} stamps on this card and starts a new one.',
      confirmLabel: 'Redeem',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRedeeming = true);
    final error = await ref
        .read(loyaltyActionsProvider)
        .redeem(campaignId: p.campaign.id);
    if (!mounted) return;
    setState(() => _isRedeeming = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Reward redeemed. Enjoy!'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
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
      // Tall enough for the chips plus breathing room above and below, so the
      // row doesn't sit flush against the app bar.
      height: 40 + AppDimensions.md + AppDimensions.sm + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppDimensions.md,
            AppDimensions.md, AppDimensions.md, AppDimensions.sm + 4),
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
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusRound),
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
    required this.isBusy,
    required this.onToggleTerms,
    required this.onRedeem,
  });

  final CampaignProgress progress;
  final bool expanded;
  final bool isBusy;
  final VoidCallback onToggleTerms;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final c = progress.campaign;
    final unlocked = progress.isUnlocked;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: unlocked ? AppColors.amber : AppColors.latte,
          width: unlocked ? 1.5 : 1,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '🎉  REWARD UNLOCKED — Ready to redeem!',
                style: AppTextStyles.chip.copyWith(color: AppColors.white),
              ),
            ),
          Padding(
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
                      onPressed: isBusy ? null : onRedeem,
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
        ],
      ),
    );
  }
}
