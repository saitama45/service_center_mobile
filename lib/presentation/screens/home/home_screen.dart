import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_card.dart';
import '../../../database/daos/loyalty_dao.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../../routing/route_names.dart';
import 'widgets/coffee_stamp.dart';

/// Member home — greeting, the featured stamp card, lifetime stats, and a
/// teaser for the campaign they're closest to finishing.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final featured = ref.watch(featuredCampaignProvider);
    final totals = ref.watch(ledgerTotalsProvider);
    final all = ref.watch(campaignProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.espresso,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.espresso),
        title: const SizedBox.shrink(),
        actions: const [_SyncChip(), SizedBox(width: AppDimensions.md)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteName.scan),
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_2, size: 26),
      ),
      body: RefreshIndicator(
        color: AppColors.amber,
        backgroundColor: AppColors.white,
        // Real server sync — see the same comment in campaigns_screen.dart.
        // The featured campaign shown here comes from the same catalogue,
        // and pulling with a userId is what picks up a stamp ghelpdesk staff
        // just added on the Scan Customer flow.
        onRefresh: () =>
            ref.read(syncManagerProvider).sync(userId: ref.read(currentUserProvider)?.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.md, AppDimensions.sm, AppDimensions.md, 96),
          children: [
            _Greeting(
              name: user?.fullName ?? '',
              initials: user?.initials ?? '',
              tier: _tierFor(totals.valueOrNull?.earned ?? 0),
            ),
            const SizedBox(height: AppDimensions.md),

            // ── Stamp card hero ────────────────────────────────────────────
            featured.when(
              loading: () => const _HeroSkeleton(),
              error: (e, _) => BmsCard(
                child: Text('Could not load your stamp card.\n$e',
                    style: AppTextStyles.bodySmall),
              ),
              data: (p) => p == null
                  ? const _NoCampaignsCard()
                  : _StampCardHero(progress: p),
            ),
            const SizedBox(height: AppDimensions.md),

            // ── Stats ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active Campaigns',
                    value: '${all.valueOrNull?.where((p) => !p.isExpired).length ?? 0}',
                    sub: 'in progress',
                  ),
                ),
                const SizedBox(width: AppDimensions.sm + 2),
                Expanded(
                  child: _StatCard(
                    label: 'Lifetime Stamps',
                    value: '${totals.valueOrNull?.earned ?? 0}',
                    sub: 'total earned',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Campaign teaser ────────────────────────────────────────────
            Row(
              children: [
                const Expanded(
                    child: Text('Active Campaign', style: AppTextStyles.h3)),
                TextButton(
                  onPressed: () => context.go(RouteName.campaigns),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('View all',
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.amber)),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            featured.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (p) => p == null
                  ? const SizedBox.shrink()
                  : _CampaignTeaser(
                      progress: p,
                      onTap: () => context.go(RouteName.campaigns),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tier is derived from lifetime stamps — no separate field to keep in sync.
  static String _tierFor(int lifetimeStamps) {
    if (lifetimeStamps >= 30) return 'Platinum';
    if (lifetimeStamps >= 15) return 'Gold';
    if (lifetimeStamps >= 5) return 'Silver';
    return 'Bronze';
  }
}

// ── Greeting row ──────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.initials,
    required this.tier,
  });

  final String name;
  final String initials;
  final String tier;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(
                name.isEmpty ? 'Welcome' : name.split(' ').first,
                style: AppTextStyles.h1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 11, color: AppColors.espresso),
              const SizedBox(width: 4),
              Text(tier,
                  style:
                      AppTextStyles.chip.copyWith(color: AppColors.espresso)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: AppColors.brown, shape: BoxShape.circle),
          child: Text(initials,
              style: AppTextStyles.h3.copyWith(color: AppColors.cream)),
        ),
      ],
    );
  }
}

// ── Stamp card hero ───────────────────────────────────────────────────────────

class _StampCardHero extends StatelessWidget {
  const _StampCardHero({required this.progress});
  final CampaignProgress progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.progress * 100).round();

    return BmsHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STAMP CARD',
                        style: AppTextStyles.label.copyWith(
                            color: AppColors.latte.withValues(alpha: 0.7))),
                    const SizedBox(height: 3),
                    Text(
                      '${progress.stamps} of ${progress.required} collected',
                      style:
                          AppTextStyles.h2.copyWith(color: AppColors.cream),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Progress',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.latte)),
                  Text('$pct%',
                      style: AppTextStyles.monoLarge
                          .copyWith(color: AppColors.gold, fontSize: 22)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          StampGrid(
            collected: progress.stamps,
            total: progress.required,
          ),
          const SizedBox(height: AppDimensions.sm + 4),
          const Divider(color: Color(0x1AFFFFFF), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                progress.isUnlocked ? Icons.celebration : Icons.lock_outline,
                size: 13,
                color: progress.isUnlocked
                    ? AppColors.gold
                    : AppColors.latte.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  progress.isUnlocked
                      ? 'Reward unlocked — ${progress.campaign.name} is ready to redeem'
                      : '${progress.remaining} more to unlock ${progress.campaign.name}',
                  style: AppTextStyles.caption.copyWith(
                    color: progress.isUnlocked
                        ? AppColors.gold
                        : AppColors.latte.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => BmsHeroCard(
        child: SizedBox(
          height: 168,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: AppColors.gold),
            ),
          ),
        ),
      );
}

class _NoCampaignsCard extends StatelessWidget {
  const _NoCampaignsCard();

  @override
  Widget build(BuildContext context) => BmsHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("You haven't started a card yet",
                style: AppTextStyles.h2.copyWith(color: AppColors.cream)),
            const SizedBox(height: 6),
            Text(
              'Show your member code at checkout to get your first stamp.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.latte),
            ),
          ],
        ),
      );
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return BmsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.statValue),
          const SizedBox(height: 2),
          Text(sub, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ── Campaign teaser ───────────────────────────────────────────────────────────

class _CampaignTeaser extends StatelessWidget {
  const _CampaignTeaser({required this.progress, required this.onTap});

  final CampaignProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BmsCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.latteLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Text(progress.campaign.emoji ?? '☕',
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progress.campaign.name, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(
                  progress.isUnlocked
                      ? 'Ready to redeem'
                      : 'Collect ${progress.remaining} more stamps',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 9),
                BmsProgressBar(value: progress.progress, height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connectivity chip ─────────────────────────────────────────────────────────

class _SyncChip extends ConsumerWidget {
  const _SyncChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref
        .watch(isOfflineProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 13, color: AppColors.warning),
          const SizedBox(width: 6),
          Text('Offline',
              style: AppTextStyles.chip.copyWith(color: AppColors.warning)),
        ],
      ),
    );
  }
}
