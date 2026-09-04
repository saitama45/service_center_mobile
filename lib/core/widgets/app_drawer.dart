import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import '../constants/permission_codes.dart';
import '../../database/app_database.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/permission_provider.dart';
import '../../routing/route_names.dart';
import 'confirmation_dialog.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  // Maps the icon string stored in the modules table → a Material IconData.
  // Add an entry here whenever a new module is seeded with a new icon name.
  static const Map<String, IconData> _iconMap = {
    'manage_accounts': Icons.manage_accounts,
    'admin_panel_settings': Icons.admin_panel_settings,
    'history': Icons.history,
    'dashboard': Icons.dashboard,
  };

  static IconData _iconData(String name) =>
      _iconMap[name] ?? Icons.circle_outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(userPermissionsProvider);
    final modulesAsync = ref.watch(activeModulesProvider);

    // Combine both async values — only show module items when both are ready.
    final modules = modulesAsync.valueOrNull ?? const <Module>[];
    final cache = permissionsAsync.valueOrNull;

    // Read from the delegate rather than GoRouterState.of — the drawer is built
    // outside the route's own builder, where GoRouterState is not guaranteed.
    final location = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

    return Drawer(
      backgroundColor: AppColors.cream,
      child: _buildDrawerList(
        context,
        ref,
        modules: modules,
        cache: cache,
        location: location,
      ),
    );
  }

  Widget _buildDrawerList(
    BuildContext context,
    WidgetRef ref, {
    required List<Module> modules,
    required dynamic cache,
    required String location,
  }) {
    return Column(
      children: [
        const _DrawerHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            children: [
              // Mirrors the bottom tab bar exactly — same four destinations,
              // same icons, same labels, same order (see MainShellScreen).
              // Two navigations that disagree about what the app contains is
              // just two things to learn; a member opening the drawer should
              // recognise it instantly.
              _DrawerItem(
                icon: Icons.home_outlined,
                label: 'Home',
                route: RouteName.dashboard,
                location: location,
                exact: true,
              ),
              _DrawerItem(
                icon: Icons.card_giftcard_outlined,
                label: 'Rewards',
                route: RouteName.campaigns,
                location: location,
              ),
              _DrawerItem(
                icon: Icons.receipt_long_outlined,
                label: 'History',
                route: RouteName.ledger,
                location: location,
              ),
              _DrawerItem(
                icon: Icons.person_outline,
                label: 'Profile',
                route: RouteName.profile,
                location: location,
              ),

              // ── Admin module items ─────────────────────────────────────
              // Everything above matches the tabs; anything below is extra
              // ground the tabs don't cover. Each item shows only when the
              // user has VIEW permission on that module, so a member sees
              // nothing here and the drawer reads as exactly the four tabs.
              // To add a new module: seed it + add its icon to _iconMap above.
              if (modules.any((m) =>
                  cache != null && cache.check(m.code, PermissionCodes.view)))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Divider(color: AppColors.latte),
                ),

              for (final module in modules)
                if (cache != null &&
                    cache.check(module.code, PermissionCodes.view))
                  _DrawerItem(
                    icon: _iconData(module.icon ?? ''),
                    label: module.name,
                    route: '/dashboard${module.route}',
                    location: location,
                  ),

            ],
          ),
        ),

        // ── Logout, pinned to the bottom ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Material(
            color: AppColors.dangerSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              onTap: () async {
                final confirmed = await showConfirmationDialog(
                  context,
                  title: 'Logout',
                  message: 'Are you sure you want to logout?',
                  confirmLabel: 'Logout',
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    const Icon(Icons.logout,
                        size: 19, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Text('Logout',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Espresso header block with the logo mark and wordmark.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 24,
        20,
        22,
      ),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Image.asset(
              'assets/images/app_logo.jpg',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.appName,
            style: AppTextStyles.h1.copyWith(color: AppColors.cream),
          ),
        ],
      ),
    );
  }
}

/// A single navigation row. Selected rows get a latte fill + amber icon,
/// mirroring the sidebar treatment in the design.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.location,
    this.exact = false,
  });

  final IconData icon;
  final String label;
  final String route;
  final String location;

  /// `/dashboard` would otherwise match every child route.
  final bool exact;

  @override
  Widget build(BuildContext context) {
    final selected =
        exact ? location == route : location.startsWith(route);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.latteLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          onTap: () {
            Navigator.pop(context);
            context.go(route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? AppColors.amber : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
