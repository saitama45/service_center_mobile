import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/brand/brand_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../core/widgets/cbtl_card.dart';
import '../../../core/widgets/cbtl_manual_code.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../../routing/route_names.dart';
import '../home/widgets/coffee_stamp.dart';

/// "My Member Code" — shows the member's signed, static QR code for staff to
/// scan at checkout, and watches for the stamp that scan awards so the
/// member never has to manually pull-to-refresh to see it.
///
/// The code itself is issued by ghelpdesk (`GET /api/loyalty/qr-card`,
/// `LoyaltyMemberRemoteDatasource`) and verified server-side when staff scan
/// it on the Stamps module's "Scan Customer" flow
/// (`StampController::resolveScan` / `scanAddStamp`) — earning a stamp is a
/// real, server-authoritative action now, not the on-device simulation this
/// screen used to run through a "Simulate POS scan" button.
///
/// Deliberately static, not rotating: see `LoyaltyMemberRemoteDatasource`'s
/// doc comment for why, and `memberQrProvider` for how it still works with
/// **zero connectivity** — the code is cached on-device the moment it's first
/// fetched (right after login, not only when this screen happens to be
/// opened online) and that cached copy is shown whenever the network isn't.
///
/// **Watching for the scan**: there's no push channel from ghelpdesk (no
/// websocket/FCM wiring exists), so this polls `SyncManager.sync()` every
/// few seconds while the screen is open and compares the member's total
/// stamp count against what it was when the screen opened. The first
/// increase is treated as "just got scanned" — it stops polling, celebrates,
/// and returns to Home so the member sees their updated card immediately
/// instead of having to back out and pull-to-refresh themselves.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  Timer? _poll;
  int? _baselineStamps;
  bool _handledStamp = false;

  static const _pollInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _armWatch();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Counts every card the member holds, not one card per campaign — see
  /// `LoyaltyDao.getTotalStampsOnCards`. A scan can open a *second* card for a
  /// campaign the member already has one for (staff can keep stamping while a
  /// full card waits to be redeemed), and a per-campaign total misses that
  /// stamp entirely: the celebration never fired even though the stamp landed.
  Future<int> _totalStamps(String userId) async {
    return ref.read(loyaltyDaoProvider).getTotalStampsOnCards(userId);
  }

  Future<void> _armWatch() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    _baselineStamps = await _totalStamps(user.id);
    _poll = Timer.periodic(_pollInterval, (_) => _checkForNewStamp(user.id));
  }

  Future<void> _checkForNewStamp(String userId) async {
    if (_handledStamp || _baselineStamps == null) return;
    // sync(userId: ...) pulls BOTH the catalogue and this member's real
    // progress (SyncManager._pullCatalog then _pullProgress) and writes any
    // change straight into the local stamp_cards row — see that class's doc
    // comment. Silently no-ops if offline; the next tick just tries again.
    await ref.read(syncManagerProvider).sync(userId: userId);
    if (!mounted || _handledStamp) return;

    final now = await _totalStamps(userId);
    if (now > _baselineStamps!) {
      _handledStamp = true;
      _poll?.cancel();
      await _celebrateAndGoHome();
    }
  }

  Future<void> _celebrateAndGoHome() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    // Deliberately not awaited — showDialog's future only completes once the
    // dialog is popped, and nothing pops it until the delay below, so
    // awaiting it here would just hang forever.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      // No barrierColor: the theme's Roasted Black scrim applies.
      builder: (_) => const _StampCollectedDialog(),
    ));
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the dialog
    context.go(RouteName.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final qr = ref.watch(memberQrProvider);

    return Scaffold(
      backgroundColor: AppColors.creamyWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamyWhite,
        foregroundColor: AppColors.roastedBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Set explicitly so the back arrow stays ink on this cream bar
        // whatever the app-wide `appBarTheme.iconTheme` says — it once was
        // cream, which left the arrow all but invisible here.
        iconTheme: const IconThemeData(color: AppColors.roastedBlack, size: 24),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.roastedBlack,
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, AppDimensions.xs,
            AppDimensions.gutter, AppDimensions.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The page title sits under the back arrow, as large as a tab's:
            // Herb Display, capitals only. Still announced as the header.
            Semantics(
              header: true,
              child: Text(AppTextStyles.caps('My Member Code'),
                  style: AppTextStyles.h1),
            ),
            const SizedBox(height: 6),
            Text('Show this to staff at checkout',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink2)),
            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              child: qr.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _RetryState(
                  message: 'Could not load your member code.',
                  onRetry: () => ref.invalidate(memberQrProvider),
                ),
                data: (result) {
                  if (result.token == null) {
                    return _RetryState(
                      message: result.error ??
                          'Your member code isn\'t available yet.',
                      onRetry: () => ref.invalidate(memberQrProvider),
                    );
                  }
                  return _MemberCode(
                      token: result.token!, fromCache: result.fromCache);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampCollectedDialog extends StatelessWidget {
  const _StampCollectedDialog();

  @override
  Widget build(BuildContext context) {
    // A key moment: the stamp lands on a Roasted Black sunburst, and the
    // headline gets the purple squiggle underneath (brand book p37).
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 30),
        decoration: BoxDecoration(
          color: AppColors.creamyWhite,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  BrandMark.burst(width: 128, color: AppColors.roastedBlack),
                  CoffeeStamp(
                      filled: true, holiday: true, highlight: true, size: 70),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(AppTextStyles.caps('Stamp Collected!'),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 30, height: 0.93)),
            const SizedBox(height: 10),
            const BrandMark.squiggle(width: 122, color: AppColors.purplePop),
            const SizedBox(height: 10),
            const Text('Your card has been updated.',
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.ink3),
          const SizedBox(height: AppDimensions.md),
          Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.md),
          CbtlButton(label: 'Try Again', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _MemberCode extends StatelessWidget {
  const _MemberCode({required this.token, required this.fromCache});
  final String token;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── QR ────────────────────────────────────────────────────
        // Pure white plate, Roasted Black modules: the one place the app
        // leaves Creamy White, because scanners want the most contrast.
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.roastedBlack, width: 1.5),
          ),
          child: QrImageView(
            data: token,
            version: QrVersions.auto,
            size: 208,
            backgroundColor: AppColors.pureWhite,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.roastedBlack,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.roastedBlack,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.md),

        // Online or offline, the same California Cream note — an offline
        // code is still a valid one, so it is not styled as a warning.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.californiaCream,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fromCache ? Icons.wifi_off_rounded : Icons.verified_outlined,
                size: 15,
                color: AppColors.ink2,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fromCache
                      ? 'Offline — showing your saved code. Still valid.'
                      : 'Your code is up to date.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),

        // The same code in plain text — the fallback when a scanner won't
        // read the screen. Staff type it into the very same field the
        // scanner would have typed into.
        CbtlManualCode(code: token),
        const SizedBox(height: AppDimensions.lg),

        const CbtlSectionCard(
          title: 'How to earn a stamp',
          icon: Icons.storefront_outlined,
          child: Text(
            'Show this code to the barista at checkout — they\'ll scan it and '
            'add your stamp right away. This code doesn\'t change, so it works '
            'even without a signal; just make sure the screen is bright enough '
            'to scan.',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }
}
