import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bms_button.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_flow_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../../routing/route_names.dart';

/// Optional biometric enrolment, offered once after verification.
///
/// Unlike the OTP step this is genuinely functional — it calls the platform
/// biometric prompt through `local_auth`.
class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  bool _scanning = false;
  String? _error;

  void _finish() {
    ref.read(postLoginStepProvider.notifier).complete();
    // Splash only triggers a sync on a RESUMED session (see
    // splash_screen.dart) — a fresh interactive sign-in reaches the
    // dashboard through here instead, and needs the same kickoff so the
    // real campaign catalogue replaces the on-device demo seed straight
    // away rather than waiting for the next cold start or reconnect.
    ref.read(syncManagerProvider).sync(userId: ref.read(currentUserProvider)?.id);
    // Cache the member QR now, while we know the device is online — this is
    // what lets "My Member Code" still work later even with zero connectivity.
    prefetchMemberQr(ref);
    context.go(RouteName.dashboard);
  }

  Future<void> _enable() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });

    final actions = ref.read(biometricActionsProvider);
    final error = await actions.authenticate(
      reason: 'Enable biometric sign-in for your rewards account',
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _scanning = false;
        _error = error;
      });
      return;
    }

    await actions.setEnabled(true);
    if (!mounted) return;
    setState(() => _scanning = false);
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(biometricAvailableProvider);
    final isAvailable = available.valueOrNull ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg, vertical: AppDimensions.lg),
            child: Column(
              children: [
                Text('Enable Biometric Login',
                    style: AppTextStyles.displayMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Use Face ID or your fingerprint for faster, more secure '
                  'access to your rewards',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.xl),

                // ── Scan target ────────────────────────────────────────────
                GestureDetector(
                  onTap: isAvailable ? _enable : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      color: _scanning ? AppColors.amber : AppColors.white,
                      borderRadius: BorderRadius.circular(42),
                      border: Border.all(
                        color:
                            _scanning ? AppColors.amber : AppColors.latte,
                        width: 2,
                      ),
                      boxShadow: _scanning
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.amber.withValues(alpha: 0.4),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : AppColors.cardShadow,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fingerprint,
                          size: 62,
                          color: _scanning
                              ? AppColors.white
                              : (isAvailable
                                  ? AppColors.amber
                                  : AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _scanning
                              ? 'Scanning…'
                              : (isAvailable
                                  ? 'Touch to Scan'
                                  : 'Unavailable'),
                          style: AppTextStyles.chip.copyWith(
                            color: _scanning
                                ? AppColors.white
                                : AppColors.espresso,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.lg),

                if (!isAvailable && available.hasValue)
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.latteLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 15, color: AppColors.caramel),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'No fingerprint or face is enrolled on this device, '
                            'so biometric login can\'t be set up yet.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.sm),
                    child: Text(_error!,
                        style: AppTextStyles.errorText,
                        textAlign: TextAlign.center),
                  ),

                const SizedBox(height: AppDimensions.lg),

                BmsButton(
                  label: 'Enable Biometric Login',
                  isFullWidth: true,
                  isLoading: _scanning,
                  onPressed: isAvailable ? _enable : null,
                ),
                const SizedBox(height: AppDimensions.sm),
                BmsButton(
                  label: 'Skip for now',
                  variant: BmsButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: _finish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
