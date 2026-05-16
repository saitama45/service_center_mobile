import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/module_codes.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_empty_state.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../domain/entities/role_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/role_management_provider.dart';

class RoleListScreen extends ConsumerWidget {
  const RoleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(roleListProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(
        title: AppStrings.roleManagement,
        subtitle: AppStrings.roles,
      ),
      floatingActionButton: PermissionGate(
        moduleCode: ModuleCodes.roleManagement,
        permissionCode: PermissionCodes.create,
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.addRole),
          onPressed: () => context.go('/dashboard/roles/new'),
        ),
      ),
      body: rolesAsync.when(
        data: (roles) => roles.isEmpty
            ? const BmsEmptyState(
                message: AppStrings.noData,
                icon: Icons.admin_panel_settings_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppDimensions.md),
                itemCount: roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _RoleTile(role: roles[i]),
              ),
        loading: () => const Center(
            child:
                CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _RoleTile extends ConsumerWidget {
  const _RoleTile({required this.role});
  final RoleEntity role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(userPermissionsProvider);

    return permissionsAsync.when(
      data: (cache) {
        final canEdit = cache.check(ModuleCodes.roleManagement, PermissionCodes.edit);
        final canDelete = cache.check(ModuleCodes.roleManagement, PermissionCodes.delete);

        final tile = Card(
          elevation: AppDimensions.cardElevation,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: role.isActive
                    ? AppColors.primaryBlue.withValues(alpha: 0.1)
                    : AppColors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                role.isSystem
                    ? Icons.shield_outlined
                    : Icons.admin_panel_settings_outlined,
                color: role.isActive
                    ? AppColors.primaryBlue
                    : AppColors.mediumGray,
                size: 22,
              ),
            ),
            title: Row(
              children: [
                Text(role.name, style: AppTextStyles.h3),
                const SizedBox(width: 8),
                if (role.isSystem)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('SYSTEM',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.white)),
                  ),
                if (!role.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mediumGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('INACTIVE',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.white)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${role.code}',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.darkGray)),
                if (role.description != null && role.description!.isNotEmpty)
                  Text(role.description!,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.mediumGray),
              onSelected: (val) {
                if (val == 'permissions') {
                  context.go('/dashboard/roles/${role.id}/permissions');
                } else if (val == 'edit') {
                  context.go('/dashboard/roles/${role.id}');
                } else if (val == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(value: 'permissions', child: Text('Permission Matrix')),
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit Role')),
                if (canDelete && !role.isSystem)
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
            onTap: canEdit ? () => context.go('/dashboard/roles/${role.id}') : null,
          ),
        );

        if (!canDelete || role.isSystem) return tile;

        return Dismissible(
          key: Key('role_${role.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) => _confirmDelete(context, ref),
          child: tile,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete Role',
      message: 'Are you sure you want to permanently delete role "${role.name}"?',
      confirmLabel: 'Delete',
      confirmVariant: BmsButtonVariant.danger,
    );
    if (!confirmed || !context.mounted) return false;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final success = await ref
        .read(roleManagementProvider.notifier)
        .deleteRole(role.id, currentUser.id);

    if (!context.mounted) return false;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role "${role.name}" deleted')),
      );
    } else {
      final err = ref.read(roleManagementProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err?.toString() ?? 'Could not delete role.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return success;
  }
}
