import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/brand/brand_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_card.dart';
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
    // The card on show: whichever campaign the member picked, else the
    // automatic choice. See homeCampaignProvider.
    final featured = ref.watch(homeCampaignProvider);
    final choices =
        ref.watch(homeCampaignChoicesProvider).valueOrNull ?? const [];
    final totals = ref.watch(ledgerTotalsProvider);
    final all = ref.watch(campaignProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.creamyWhite,
      // Members see no hamburger: the drawer's only unique content is the
      // admin module links.
      appBar: AppBar(
        backgroundColor: AppColors.creamyWhite,
        foregroundColor: AppColors.roastedBlack,
        elevation: 0,
        toolbarHeight: 44,
        title: const SizedBox.shrink(),
        actions: const [_SyncChip(), SizedBox(width: AppDimensions.gutter)],
      ),
      // Golden Caramel: the one accent object on the page. It grows into the
      // member-code page (revealFromButtonPage).
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteName.scan),
        tooltip: 'My member code',
        child: const Icon(Icons.qr_code_2, size: 28),
      ),
      body: RefreshIndicator(
        color: AppColors.roastedBlack,
        backgroundColor: AppColors.creamyWhite,
        // Real server sync — see the same comment in campaigns_screen.dart.
        // The featured campaign shown here comes from the same catalogue,
        // and pulling with a userId is what picks up a stamp ghelpdesk staff
        // just added on the Scan Customer flow.
        onRefresh: () => ref
            .read(syncManagerProvider)
            .sync(userId: ref.read(currentUserProvider)?.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.gutter, 0, AppDimensions.gutter, 104),
          children: [
            _Greeting(
              name: user?.fullName ?? '',
              tier: _tierFor(totals.valueOrNull?.earned ?? 0),
            ),
            const SizedBox(height: AppDimensions.md + 2),

            // ── Campaign picker ────────────────────────────────────────────
            // Only earns its space when there's an actual choice to make —
            // one campaign needs no switch, and the hero already names it.
            if (choices.length > 1) ...[
              _CampaignPicker(
                choices: choices,
                selectedId: featured.valueOrNull?.campaign.id,
                onSelect: (id) => ref
                    .read(selectedHomeCampaignIdProvider.notifier)
                    .state = id,
              ),
              const SizedBox(height: AppDimensions.md - 2),
            ],

            // ── Stamp card hero(es) ────────────────────────────────────────
            featured.when(
              loading: () => const _HeroSkeleton(),
              error: (e, _) => CbtlCard(
                child: Text('Could not load your stamp card.\n$e',
                    style: AppTextStyles.bodySmall),
              ),
              data: (p) => p == null
                  ? const _NoCampaignsCard()
                  : _StampCardStack(featured: p),
            ),
            const SizedBox(height: AppDimensions.md),

            // ── Stats ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active Campaigns',
                    value:
                        '${all.valueOrNull?.where((p) => !p.isExpired).length ?? 0}',
                    sub: 'in progress',
                  ),
                ),
                const SizedBox(width: AppDimensions.sm + 4),
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
                Expanded(
                    child: Text(AppTextStyles.caps('Active Campaign'),
                        style: AppTextStyles.h2)),
                TextButton(
                  onPressed: () => context.go(RouteName.campaigns),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('View all',
                      style: AppTextStyles.button.copyWith(
                          color: AppColors.roastedBlack,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm + 2),
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
    required this.tier,
  });

  final String name;
  final String tier;

  /// Set to true to bring the loyalty tier badge back.
  static const bool _showTierBadge = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(AppStrings.appNameFull,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                AppTextStyles.caps(
                    name.isEmpty ? 'Welcome' : name.split(' ').first),
                style: AppTextStyles.displayLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Tier badge (Bronze/Silver/Gold/Platinum) is hidden for now — the
        // tiers still compute, so flipping this back to true restores it.
        if (_showTierBadge) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.goldenCaramel,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 11, color: AppColors.roastedBlack),
                const SizedBox(width: 4),
                Text(tier,
                    style:
                        AppTextStyles.chip.copyWith(color: AppColors.roastedBlack)),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        // The hero logo (brand book p20) on the cream page, pressed on like a
        // seal. It stands in for the user's initials, as the old mark did.
        const SealIn(
          delay: Duration(milliseconds: 120),
          child: BrandLogo(size: 60),
        ),
      ],
    );
  }
}

// ── Stamp card hero ───────────────────────────────────────────────────────────

/// Horizontal chips for switching the stamp card between the campaigns a
/// member is collecting on.
///
/// Chips rather than a dropdown: the count is small (one per live card), and
/// a member glancing at Home can see *that* they have several campaigns
/// without opening anything. Each chip shows the campaign's own progress, so
/// the choice is informed before it's made.
class _CampaignPicker extends StatelessWidget {
  const _CampaignPicker({
    required this.choices,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CampaignProgress> choices;

  /// The campaign actually on show — which may be the automatic pick rather
  /// than an explicit one, so the highlight always matches the hero below.
  final String? selectedId;

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: choices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = choices[i];
          final selected = p.campaign.id == selectedId;

          return GestureDetector(
            onTap: () => onSelect(p.campaign.id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.roastedBlack
                    : AppColors.creamyWhite,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(
                  color: selected ? AppColors.roastedBlack : AppColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.isUnlocked) ...[
                    Icon(Icons.celebration,
                        size: 13,
                        color: selected
                            ? AppColors.goldenCaramel
                            : AppColors.roastedBlack),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    p.campaign.name,
                    style: AppTextStyles.chip.copyWith(
                      color: selected
                          ? AppColors.creamyWhite
                          : AppColors.roastedBlack,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${p.stamps}/${p.required}',
                    style: AppTextStyles.chip.copyWith(
                      fontWeight: FontWeight.w400,
                      color: selected
                          ? AppColors.californiaCream
                          : AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Every unredeemed card of the campaign on show, one hero each, stacked.
///
/// A member holds more than one only with Holiday overflow (a card's Holiday
/// slots are full, so the next Holiday stamp starts the next card) or while a
/// full card waits to be redeemed. Each card is labelled "Card N of M" —
/// except a lone card on a program with no cap and no Holiday slots, which
/// looks exactly as Home always did.
class _StampCardStack extends ConsumerWidget {
  const _StampCardStack({required this.featured});

  /// The campaign's entry from [homeCampaignProvider].
  final CampaignProgress featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Until the list has loaded for THIS campaign — first build, or a reload
    // still holding the previously picked campaign's cards — show the one
    // card [featured] already names rather than a skeleton or the wrong cards.
    final loaded = ref.watch(homeCampaignCardsProvider).valueOrNull;
    final cards = loaded != null &&
            loaded.isNotEmpty &&
            loaded.every((c) => c.campaign.id == featured.campaign.id)
        ? loaded
        : [featured];

    final labelled = cards.length > 1 ||
        featured.campaign.maxCardsPerCustomer != null ||
        featured.holidaySlots > 0;

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimensions.md - 2),
          _StampCardHero(
            progress: cards[i],
            cardLabel: labelled ? cards[i].cardLabel : null,
          ),
        ],
      ],
    );
  }
}

class _StampCardHero extends StatelessWidget {
  const _StampCardHero({required this.progress, this.cardLabel});
  final CampaignProgress progress;

  /// "Card 2 of 3" — null hides it.
  final String? cardLabel;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.progress * 100).round();
    final unlocked = progress.isUnlocked;

    // Own the headline with type (brand book p44): the campaign and the count
    // lead in Herb Display. A full card is a key moment, so it alone gets the
    // one Purple Aura the book allows per layout (p40).
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.roastedBlack,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Stack(
        children: [
          if (unlocked)
            const Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: PurpleAura(
                width: 20,
                delay: Duration(milliseconds: 260),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The campaign this card belongs to, named above its own
                // count — with several cards in play, "8 of 12" means
                // nothing until you know which campaign it's counting.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        AppTextStyles.caps(progress.campaign.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(
                            color: AppColors.creamyWhite,
                            fontSize: 30,
                            height: 0.93),
                      ),
                    ),
                    if (cardLabel != null) ...[
                      const SizedBox(width: 10),
                      _CardNumberPill(label: cardLabel!),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CountUp(
                      value: progress.stamps,
                      style: AppTextStyles.displayLarge.copyWith(
                          color: AppColors.creamyWhite,
                          fontSize: 76,
                          height: 0.86),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'of ${progress.required} collected',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.californiaCream),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Progress',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.californiaCream)),
                        Text('$pct%',
                            style: AppTextStyles.statValue.copyWith(
                                color: AppColors.goldenCaramel,
                                fontSize: 32)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                StampGrid(
                  collected: progress.stamps,
                  total: progress.required,
                  holidaySlots: progress.holidaySlots,
                  holidayCount: progress.holidayCollected,
                  regularCount: progress.regularCollected,
                ),
                if (progress.holidaySlots > 0) ...[
                  const SizedBox(height: 14),
                  StampSlotLegend(
                    holidaySlots: progress.holidaySlots,
                    regularSlots: progress.regularSlots,
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(color: Color(0x2EFAEFE6), height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        unlocked ? Icons.celebration : Icons.lock_outline,
                        size: 15,
                        color: unlocked
                            ? AppColors.goldenCaramel
                            : AppColors.californiaCream,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        unlocked
                            ? 'Reward unlocked — ${progress.campaign.name} is ready to redeem'
                            : '${progress.remaining} more to unlock ${progress.campaign.name}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: unlocked
                              ? AppColors.goldenCaramel
                              : AppColors.californiaCream,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Counts up to [value] once, on the curve the rest of the card arrives on.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: BrandCurves.slowOut,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

class _CardNumberPill extends StatelessWidget {
  const _CardNumberPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.goldenCaramel,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: AppTextStyles.chip
              .copyWith(color: AppColors.roastedBlack, fontSize: 12),
        ),
      );
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const CbtlHeroCard(
        child: SizedBox(
          height: 168,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: AppColors.goldenCaramel),
            ),
          ),
        ),
      );
}

class _NoCampaignsCard extends StatelessWidget {
  const _NoCampaignsCard();

  @override
  Widget build(BuildContext context) => CbtlHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTextStyles.caps("You haven't started a card yet"),
                style: AppTextStyles.h2.copyWith(
                    color: AppColors.creamyWhite, fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              'Show your member code at checkout to get your first stamp.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.californiaCream),
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
    return CbtlCard(
      color: AppColors.californiaCream,
      borderColor: AppColors.californiaCream,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink2)),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.statValue),
          const SizedBox(height: 6),
          Text(sub,
              style: AppTextStyles.caption.copyWith(color: AppColors.ink2)),
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
    return CbtlCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.californiaCream,
              shape: BoxShape.circle,
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
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 10),
                CbtlProgressBar(
                  value: progress.progress,
                  color: progress.isUnlocked
                      ? AppColors.goldenCaramel
                      : AppColors.roastedBlack,
                ),
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
        color: AppColors.californiaCream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.goldenCaramel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 13, color: AppColors.roastedBlack),
          const SizedBox(width: 6),
          Text('Offline',
              style:
                  AppTextStyles.chip.copyWith(color: AppColors.roastedBlack)),
        ],
      ),
    );
  }
}
