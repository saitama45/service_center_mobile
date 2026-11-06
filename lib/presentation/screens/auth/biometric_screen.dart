import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/brand/brand_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_button.dart';
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
        backgroundColor: AppColors.creamyWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppDimensions.lg,
                AppDimensions.xxl, AppDimensions.lg, AppDimensions.lg),
            child: Column(
              children: [
                Text(AppTextStyles.caps('Enable Biometric Login'),
                    style: AppTextStyles.h1,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'Use Face ID or your fingerprint for faster, more secure '
                  'access to your rewards',
                  style:
                      AppTextStyles.bodyLarge.copyWith(color: AppColors.ink2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.xxl),

                // ── Scan target ────────────────────────────────────────────
                // A large ink-ruled circle on cream. While scanning it fills
                // with caramel as a non-text accent; the words on it stay ink.
                GestureDetector(
                  onTap: isAvailable ? _enable : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: BrandCurves.press,
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      color: _scanning
                          ? AppColors.goldenCaramel
                          : AppColors.creamyWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAvailable || _scanning
                            ? AppColors.roastedBlack
                            : AppColors.fieldLine,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fingerprint,
                          size: 62,
                          color: isAvailable || _scanning
                              ? AppColors.roastedBlack
                              : AppColors.ink3,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _scanning
                              ? 'Scanning…'
                              : (isAvailable
                                  ? 'Touch to Scan'
                                  : 'Unavailable'),
                          style: AppTextStyles.chip.copyWith(
                            color: AppColors.roastedBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.xl),

                // A warning: Roasted Black words on California Cream, edged
                // in caramel.
                if (!isAvailable && available.hasValue)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.californiaCream,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.goldenCaramel),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline,
                              size: 16, color: AppColors.roastedBlack),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No fingerprint or face is enrolled on this device, '
                            'so biometric login can\'t be set up yet.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.roastedBlack),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.sm),
                    child: Text(_error!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.danger),
                        textAlign: TextAlign.center),
                  ),

                const SizedBox(height: AppDimensions.lg),

                CbtlButton(
                  label: 'Enable Biometric Login',
                  isFullWidth: true,
                  isLoading: _scanning,
                  onPressed: isAvailable ? _enable : null,
                ),
                const SizedBox(height: AppDimensions.sm),
                CbtlButton(
                  label: 'Skip for now',
                  variant: CbtlButtonVariant.ghost,
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
