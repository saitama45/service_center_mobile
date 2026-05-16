import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/permission_codes.dart';
import '../../database/app_database.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/permission_provider.dart';
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

    return Drawer(
      child: _buildDrawerList(context, ref, modules: modules, cache: cache),
    );
  }

  Widget _buildDrawerList(
    BuildContext context,
    WidgetRef ref, {
    required List<Module> modules,
    required dynamic cache,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: AppColors.primaryBlack),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app_logo_v2.png',
                height: 80,
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // Dashboard is always visible — not a permission-controlled module.
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          onTap: () {
            Navigator.pop(context);
            context.go('/dashboard');
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('DTR'),
          onTap: () {
            Navigator.pop(context);
            context.go('/dashboard/dtr');
          },
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Attendance Logs'),
          onTap: () {
            Navigator.pop(context);
            context.go('/dashboard/attendance');
          },
        ),
        // ── Dynamic module items ─────────────────────────────────────────
        // Iterates every active module from the DB in displayOrder.
        // A module's ListTile is shown only when the user has VIEW permission.
        // To add a new module: seed it + add its icon to _iconMap above.
        for (final module in modules)
          if (cache != null &&
              cache.check(module.code, PermissionCodes.view))
            ListTile(
              leading: Icon(_iconData(module.icon ?? '')),
              title: Text(module.name),
              onTap: () {
                Navigator.pop(context);
                context.go('/dashboard${module.route}');
              },
            ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profile'),
          onTap: () {
            Navigator.pop(context);
            context.go('/dashboard/profile');
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Logout',
              style: TextStyle(color: Colors.redAccent)),
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
        ),
      ],
    );
  }
}
