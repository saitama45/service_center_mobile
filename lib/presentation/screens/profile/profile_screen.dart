import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_format_util.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/widgets/bms_card.dart';
import '../../providers/auth_flow_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../routing/route_names.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(
        title: AppStrings.profile,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppDimensions.md, AppDimensions.md, AppDimensions.md, AppDimensions.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Identity hero ────────────────────────────────────────────
            BmsHeroCard(
              padding: const EdgeInsets.all(AppDimensions.md + 2),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: Text(
                      user.initials,
                      style: AppTextStyles.h2
                          .copyWith(color: AppColors.white, fontSize: 19),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style:
                              AppTextStyles.h2.copyWith(color: AppColors.cream),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user.username}',
                          style: AppTextStyles.monoSmall
                              .copyWith(color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // ── Account details ──────────────────────────────────────────
            BmsSectionCard(
              title: 'Account Details',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  if (user.email != null && user.email!.isNotEmpty)
                    _InfoRow(label: AppStrings.email, value: user.email!),
                  if (user.employeeId != null && user.employeeId!.isNotEmpty)
                    _InfoRow(
                      label: AppStrings.employeeId,
                      value: user.employeeId!,
                      mono: true,
                    ),
                  _InfoRow(
                    label: AppStrings.lastLogin,
                    value: DateFormatUtil.formatDateTime(user.lastLoginAt),
                    mono: true,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.md),

            // ── Preferences ──────────────────────────────────────────────
            const _BiometricToggleCard(),

            const SizedBox(height: AppDimensions.md),

            // ── Security actions ─────────────────────────────────────────
            BmsCard(
              padding: EdgeInsets.zero,
              child: _NavRow(
                icon: Icons.lock_outline,
                label: AppStrings.changePassword,
                sub: 'Update your account password',
                onTap: () =>
                    context.go('/dashboard/profile/change-password'),
              ),
            ),

            const SizedBox(height: AppDimensions.md),
            _AuthenticatorCard(userId: user.id),

            const SizedBox(height: AppDimensions.lg),

            BmsButton(
              label: AppStrings.signOut,
              variant: BmsButtonVariant.danger,
              isFullWidth: true,
              icon: Icons.logout,
              onPressed: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out', style: AppTextStyles.h2),
        content: const Text('Are you sure you want to sign out?',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go(RouteName.login);
    }
  }
}

/// Biometric opt-in. Hidden entirely when the device has nothing enrolled,
/// rather than showing a switch that can't be turned on.
class _BiometricToggleCard extends ConsumerWidget {
  const _BiometricToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    if (!available) return const SizedBox.shrink();

    final enabled = ref.watch(biometricEnabledProvider).valueOrNull ?? false;

    return BmsCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.latteLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.fingerprint,
                size: 20, color: AppColors.caramel),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Biometric Login', style: AppTextStyles.h3),
                SizedBox(height: 2),
                Text('Face ID / fingerprint access',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) async {
              final actions = ref.read(biometricActionsProvider);
              if (v) {
                final error = await actions.authenticate();
                if (error != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(error),
                          backgroundColor: AppColors.danger),
                    );
                  }
                  return;
                }
              }
              await actions.setEnabled(v);
            },
          ),
        ],
      ),
    );
  }
}

/// Entry point to the authenticator-app setup/removal screen. Reflects
/// enrolment state so members can tell at a glance whether offline sign-in
/// has a second factor available.
class _AuthenticatorCard extends ConsumerWidget {
  const _AuthenticatorCard({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolled =
        ref.watch(authenticatorEnrolledProvider(userId)).valueOrNull ?? false;

    return BmsCard(
      padding: EdgeInsets.zero,
      child: _NavRow(
        icon: enrolled ? Icons.verified_user_outlined : Icons.qr_code_2,
        label: 'Authenticator App',
        sub: enrolled
            ? 'Set up — used to verify offline sign-ins'
            : 'Set up Google Authenticator for offline sign-in',
        onTap: () => context.go('/dashboard/profile/authenticator'),
      ),
    );
  }
}

/// Label above value, hairline separated — the detail-row pattern from the
/// design's profile and campaign cards.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.isLast = false,
  });

  final String label;
  final String value;

  /// Use the mono face for IDs and timestamps so columns line up.
  final bool mono;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(height: 3),
        Text(
          value,
          style: mono ? AppTextStyles.monoMedium : AppTextStyles.bodyMedium,
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.latteLight),
          ),
      ],
    );
  }
}

/// Tappable row with a leading icon chip and a chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.latteLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(icon, size: 18, color: AppColors.caramel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.h3),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

