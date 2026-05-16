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
import '../../providers/app_providers.dart';
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
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(
        title: AppStrings.profile,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + Name ───────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: AppDimensions.avatarLg / 2,
                    backgroundColor: AppColors.primaryBlue,
                    child: Text(user.initials,
                        style: AppTextStyles.h1
                            .copyWith(color: AppColors.white, fontSize: 28)),
                  ),
                  const SizedBox(height: 12),
                  Text(user.fullName, style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Info card ───────────────────────────────────────────────
            _InfoCard(items: [
              _InfoRow(label: AppStrings.username, value: '@${user.username}'),
              if (user.email != null && user.email!.isNotEmpty)
                _InfoRow(label: AppStrings.email, value: user.email!),
              if (user.employeeId != null && user.employeeId!.isNotEmpty)
                _InfoRow(
                    label: AppStrings.employeeId, value: user.employeeId!),
              _InfoRow(
                  label: AppStrings.lastLogin,
                  value: DateFormatUtil.formatDateTime(user.lastLoginAt)),
            ]),

            const SizedBox(height: AppDimensions.md),

            // ── Change Password ──────────────────────────────────────────
            BmsButton(
              label: AppStrings.changePassword,
              variant: BmsButtonVariant.secondary,
              isFullWidth: true,
              icon: Icons.lock_outline,
              onPressed: () => context.go('/dashboard/profile/change-password'),
            ),

            const SizedBox(height: AppDimensions.lg),

            // ── Logout Button ───────────────────────────────────────────
            BmsButton(
              label: AppStrings.signOut,
              variant: BmsButtonVariant.danger,
              isFullWidth: true,
              icon: Icons.logout,
              onPressed: () => _confirmLogout(context, ref),
            ),
            const SizedBox(height: AppDimensions.xl),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        children: items
            .expand((w) => [w, const Divider(height: 16)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: AppTextStyles.label),
        ),
        Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
      ],
    );
  }
}

