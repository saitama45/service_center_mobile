import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bms_manual_code.dart';
import '../../../database/daos/loyalty_dao.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';

/// The sheet "Redeem Now" opens: the member's signed redemption code for one
/// specific full card, for store staff to scan on ghelpdesk's Stamps module
/// ("Scan Redeem QR" → `StampController::resolveRedeemScan`).
///
/// Redeeming is **server-authoritative**, exactly like earning a stamp is.
/// The app no longer marks its own card redeemed — it can't: a real
/// redemption deducts specific coded inventory units in ghelpdesk, which only
/// the person at the counter can pick. So this screen's whole job is to show
/// the code and then wait for the redemption to come back down through
/// `SyncManager`, the same shape as the "My Member Code" screen waiting for a
/// stamp.
///
/// The code itself was issued with the ordinary progress pull and cached on
/// the card row, so it displays with **no connectivity** — the counter is
/// where signal is worst, and a member who filled their card while online
/// shouldn't be stuck. Staff still need ghelpdesk to complete the
/// redemption, but that's their connection, not the member's.
///
/// Nothing here can be spent twice: the code names a card, and ghelpdesk
/// refuses any card whose status has already left `completed`.
Future<void> showRedeemQrSheet(
    BuildContext context, CampaignProgress progress) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RedeemQrSheet(
      cardId: progress.card?.id,
      campaignName: progress.campaign.rewardDescription ?? progress.campaign.name,
      initialToken: progress.redeemToken,
    ),
  );
}

class _RedeemQrSheet extends ConsumerStatefulWidget {
  const _RedeemQrSheet({
    required this.cardId,
    required this.campaignName,
    required this.initialToken,
  });

  /// The local stamp card being claimed. The sheet follows this ONE row —
  /// a member can hold several cards for a campaign, and only the one they
  /// tapped is being redeemed.
  final String? cardId;

  final String campaignName;

  /// The code as it stood when the sheet opened, so the QR paints on the
  /// first frame instead of flashing the "not ready" state while the first
  /// query resolves.
  final String? initialToken;

  @override
  ConsumerState<_RedeemQrSheet> createState() => _RedeemQrSheetState();
}

class _RedeemQrSheetState extends ConsumerState<_RedeemQrSheet> {
  Timer? _poll;
  bool _handled = false;

  /// Last code actually seen for this card. Held so a transient
  /// provider state (a refresh in flight) can't blank out a QR the member is
  /// holding up to a scanner.
  String? _token;

  /// Same cadence as the member-code screen. There's no push channel from
  /// ghelpdesk (no websocket/FCM wiring exists), so the app asks.
  static const _pollInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _token = widget.initialToken;
    _poll = Timer.periodic(_pollInterval, (_) => _syncOnce());
    // Don't make the member wait a full interval for the first check —
    // staff can be quick, and the card may already be redeemed by the time
    // this opens (e.g. reopened after a redemption elsewhere).
    _syncOnce();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _syncOnce() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(syncManagerProvider).sync(userId: user.id);
  }

  void _onRedeemed() {
    if (_handled || !mounted) return;
    _handled = true;
    _poll?.cancel();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reward redeemed. Enjoy!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watches the card's own row — `campaignCardsProvider` keeps redeemed
    // cards, so a redemption shows up here as a POSITIVE fact
    // (`redeemed_at` is set) instead of having to be inferred from the card
    // vanishing.
    //
    // Inferring it from absence is exactly what closed this sheet the instant
    // it opened: `campaignProgressProvider` drops redeemed cards, so "gone"
    // was read as "claimed" — but a provider being *refreshed* also reads as
    // gone through `maybeWhen(data:)`, while still reporting `hasValue`. The
    // sync fired in `initState` triggered precisely that refresh, so the
    // sheet congratulated the member before any cashier had scanned
    // anything. A positive signal has no such failure mode.
    //
    // `valueOrNull` (not `maybeWhen`) is deliberate too: it keeps returning
    // the previous list while a refresh is in flight, so nothing flickers
    // every poll.
    final cards = ref.watch(campaignCardsProvider).valueOrNull;

    CampaignProgress? entry;
    if (cards != null && widget.cardId != null) {
      for (final p in cards) {
        if (p.card?.id == widget.cardId) {
          entry = p;
          break;
        }
      }
    }

    // Only ever from a row we actually found; a missing row leaves the last
    // known code on screen rather than blanking it.
    if (entry != null && entry.redeemToken != null) _token = entry.redeemToken;

    if (entry != null && entry.isRedeemed) {
      // Close on the next frame rather than mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRedeemed());
    }

    final token = _token;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.md,
        bottom: MediaQuery.of(context).padding.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.latte,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              widget.campaignName,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Show this to the cashier to claim it.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            if (token != null && token.isNotEmpty)
              _RedeemCode(token: token)
            else
              const _NoCodeYet(),
            const SizedBox(height: AppDimensions.lg),
          ],
        ),
      ),
    );
  }
}

class _RedeemCode extends StatelessWidget {
  const _RedeemCode({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: AppColors.amber, width: 2),
            boxShadow: AppColors.cardShadow,
          ),
          child: QrImageView(
            data: token,
            version: QrVersions.auto,
            size: 208,
            backgroundColor: AppColors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.espresso,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.espresso,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.amber),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Waiting for the cashier to scan…',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),

        // Same fallback as the member code screen: if the scanner won't read
        // the QR, the cashier keys this into "Scan Redeem QR" instead.
        BmsManualCode(
          code: token,
          label: 'MANUAL ENTRY CODE',
          // Never name the back-office system in member-facing copy — to a
          // member, staff just "enter it at the counter".
          hint: 'If the scanner cannot read the QR, the cashier can enter this '
              'code manually instead — it claims this same reward.',
        ),
        const SizedBox(height: AppDimensions.md),

        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.latte.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.latte),
          ),
          child: Text(
            'Your card stays full until staff scan this code and hand the '
            'reward over — nothing is used up by opening this screen. It '
            'updates here by itself once they do.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// A full card with no cached code: the member has never been online since it
/// filled up, so ghelpdesk has never issued one. Nothing to show and nothing
/// the app can fake — a code the server didn't sign wouldn't scan.
class _NoCodeYet extends StatelessWidget {
  const _NoCodeYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.latte),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 34, color: AppColors.muted),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Your reward code isn\'t ready yet',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Connect to the internet once and it\'ll be saved to your phone — '
            'after that it works offline. Staff can still redeem your card at '
            'the counter in the meantime.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
