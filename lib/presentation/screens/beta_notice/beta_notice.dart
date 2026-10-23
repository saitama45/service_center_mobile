import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../database/daos/settings_dao.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';

/// The closed-beta confidentiality notice every member must accept once,
/// the first time they reach the app after signing in.
///
/// **Android only, on purpose.** The Play build is in closed testing, where
/// this is true. The iOS build goes through App Store review, and Guideline
/// 2.2 rejects an app that presents itself as a beta ("use TestFlight
/// instead") — so the same notice there would cost a rejection.
/// Turn it off for the public Play release by setting the default below to
/// false (or building with `--dart-define=BETA_NOTICE=false`).
class BetaNotice {
  const BetaNotice._();

  static bool get enabled =>
      const bool.fromEnvironment('BETA_NOTICE', defaultValue: true) &&
      defaultTargetPlatform == TargetPlatform.android;

  /// Bump to ask everyone again after the wording materially changes.
  static const int version = 1;

  static const String title = 'Closed Beta — Confidential';

  static const String intro =
      'Thank you for helping us test this app before its public launch.';

  static const List<String> points = [
    'This is a closed beta, available only to invited testers.',
    'Please keep it confidential. Do not share the app, its download link, '
        'screenshots, or any details about it with anyone outside the test.',
    'Features, campaigns and rewards may still change, and some things may '
        'not work as expected yet.',
    'Tell us what you think through Profile → Suggestion Box.',
  ];

  static const String acceptLabel =
      'I accept, and I will keep this beta confidential.';

  static const String continueLabel = 'Continue';
  static const String declineLabel = 'Sign out';
}

/// Remembers, per member and per device, that the notice was accepted.
///
/// Stored as an ordinary `app_settings` row keyed by the user id rather than
/// through the table's `user_id` column: that column is a foreign key to the
/// local `users` row, which account deletion removes — a setting hanging off
/// it would then block the deletion.
class BetaNoticeStore {
  BetaNoticeStore(this._settings);

  final SettingsDao _settings;

  static String keyFor(String userId) =>
      'beta_notice_v${BetaNotice.version}:$userId';

  Future<bool> isAccepted(String userId) async =>
      (await _settings.getSetting(keyFor(userId))) != null;

  Future<void> accept(String userId) async {
    // `user_id` is NULL on these rows, and SQLite lets NULL repeat inside a
    // unique key — so write only once, or the read would find two rows.
    if (await isAccepted(userId)) return;
    await _settings.setSetting(
        keyFor(userId), DateTime.now().toUtc().toIso8601String());
  }
}

final betaNoticeStoreProvider = Provider<BetaNoticeStore>(
  (ref) => BetaNoticeStore(ref.read(appDatabaseProvider).settingsDao),
);

/// Wraps the signed-in app (the tab shell) and, on the first frame, shows the
/// notice to a member who has not accepted it yet. Sits behind the router's
/// post-login gate, so OTP and biometrics are always done first.
///
/// Declining signs the member out — the app is not usable without the
/// acceptance, and they are asked again at their next sign-in.
class BetaNoticeGate extends ConsumerStatefulWidget {
  const BetaNoticeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BetaNoticeGate> createState() => _BetaNoticeGateState();
}

class _BetaNoticeGateState extends ConsumerState<BetaNoticeGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!BetaNotice.enabled || _showing || !mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _showing = true;
    try {
      final store = ref.read(betaNoticeStoreProvider);
      if (await store.isAccepted(user.id) || !mounted) return;

      if (await showBetaNoticeDialog(context)) {
        await store.accept(user.id);
      } else {
        await ref.read(authProvider.notifier).logout();
      }
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A different member signing in on this device without the shell being
    // rebuilt still gets asked.
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null && next.id != previous?.id) _maybeShow();
    });
    return widget.child;
  }
}

/// Shows the notice and resolves true once the member has ticked
/// "I accept" and pressed Continue, false if they chose to sign out.
/// It cannot be dismissed any other way — not by the barrier, not by Back.
Future<bool> showBetaNoticeDialog(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const BetaNoticeDialog(),
  );
  return accepted ?? false;
}

class BetaNoticeDialog extends StatefulWidget {
  const BetaNoticeDialog({super.key});

  @override
  State<BetaNoticeDialog> createState() => _BetaNoticeDialogState();
}

class _BetaNoticeDialogState extends State<BetaNoticeDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.white,
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.amber, size: 22),
            SizedBox(width: 10),
            Expanded(child: Text(BetaNotice.title, style: AppTextStyles.h2)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(BetaNotice.intro, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              for (final point in BetaNotice.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7, right: 10),
                        child: Icon(Icons.circle, size: 6, color: AppColors.amber),
                      ),
                      Expanded(
                        child: Text(point, style: AppTextStyles.bodySmall),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              CheckboxListTile(
                key: const Key('beta-notice-accept'),
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.amber,
                title: Text(BetaNotice.acceptLabel,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(BetaNotice.declineLabel,
                style:
                    AppTextStyles.button.copyWith(color: AppColors.mediumGray)),
          ),
          CbtlButton(
            label: BetaNotice.continueLabel,
            // Disabled until the box is ticked: the tick IS the acceptance.
            onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
          ),
        ],
      ),
    );
  }
}
