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
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/user_management_provider.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    final filter = ref.watch(userListFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(),
      appBar: BmsAppBar(
        title: AppStrings.userManagement,
        subtitle: AppStrings.users,
        actions: [
          PermissionGate(
            moduleCode: ModuleCodes.userManagement,
            permissionCode: PermissionCodes.create,
            child: IconButton(
              icon: const Icon(Icons.person_add, color: AppColors.white),
              tooltip: AppStrings.addUser,
              onPressed: () => context.go('/dashboard/users/new'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(filter),
          Expanded(
            child: usersAsync.when(
              data: (users) => users.isEmpty && filter.page == 0
                  ? const BmsEmptyState(
                      message: AppStrings.noData,
                      icon: Icons.people_outline,
                    )
                  : _buildUserList(users),
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryBlue)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          _PaginationBar(filter: filter),
        ],
      ),
    );
  }

  Widget _buildFilterBar(UserListFilter filter) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name or username…',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.primaryBlue),
              suffixIcon: filter.search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref
                            .read(userListFilterProvider.notifier)
                            .state = filter.copyWith(search: '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) {
              ref.read(userListFilterProvider.notifier).state =
                  filter.copyWith(search: v, page: 0);
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          Row(
            children: [
              _FilterChip(
                label: AppStrings.all,
                selected: filter.includeInactive,
                onTap: () => ref
                    .read(userListFilterProvider.notifier)
                    .state = filter.copyWith(includeInactive: true, page: 0),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: AppStrings.active,
                selected: !filter.includeInactive,
                onTap: () => ref
                    .read(userListFilterProvider.notifier)
                    .state = filter.copyWith(includeInactive: false, page: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<UserEntity> users) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _UserListTile(user: users[i]),
    );
  }
}

class _UserListTile extends ConsumerWidget {
  const _UserListTile({required this.user});
  final UserEntity user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(userPermissionsProvider);

    return permissionsAsync.when(
      data: (cache) {
        final canEdit = cache.check(ModuleCodes.userManagement, PermissionCodes.edit);
        final canDelete = cache.check(ModuleCodes.userManagement, PermissionCodes.delete);

        final tile = Card(
          elevation: AppDimensions.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            side: const BorderSide(color: AppColors.latte),
          ),
          child: ListTile(
            isThreeLine: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: AppDimensions.avatarMd / 2,
              backgroundColor: user.isActive
                  ? AppColors.primaryBlue
                  : AppColors.mediumGray,
              child: Text(user.initials,
                  style: AppTextStyles.h3.copyWith(color: AppColors.white)),
            ),
            title: Text(user.fullName, style: AppTextStyles.h3),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${user.username}', style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _RoleChip(roleName: user.roleName),
                    const SizedBox(width: 8),
                    _StatusDot(isActive: user.isActive),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.mediumGray),
              onSelected: (val) {
                if (val == 'edit') context.go('/dashboard/users/${user.id}');
                if (val == 'delete') _confirmDelete(context, ref);
              },
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
              ],
            ),
            onTap: canEdit ? () => context.go('/dashboard/users/${user.id}') : null,
          ),
        );

        if (!canDelete) return tile;

        return Dismissible(
          key: Key('user_${user.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.danger,
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
      title: 'Delete User',
      message: 'Are you sure you want to permanently delete user "${user.fullName}"?',
      confirmLabel: 'Delete',
      confirmVariant: BmsButtonVariant.danger,
    );
    if (!confirmed || !context.mounted) return false;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final success = await ref
        .read(userManagementProvider.notifier)
        .deleteUser(user.id, currentUser.id);
    
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User "${user.fullName}" deleted')),
      );
    }
    return success;
  }

}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.roleName});
  final String roleName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(roleName,
          style: AppTextStyles.chip
              .copyWith(color: AppColors.darkGray)),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.success : AppColors.mediumGray,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? AppStrings.active : AppStrings.inactive,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.success : AppColors.mediumGray,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : AppColors.white,
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusRound),
          border: Border.all(
            color: selected
                ? AppColors.primaryBlue
                : AppColors.borderGray,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
              color:
                  selected ? AppColors.white : AppColors.mediumGray),
        ),
      ),
    );
  }
}

class _PaginationBar extends ConsumerWidget {
  const _PaginationBar({required this.filter});
  final UserListFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(userCountProvider);

    return countAsync.when(
      data: (total) {
        final totalPages =
            (total / UserListFilter.pageSize).ceil().clamp(1, 999999);
        final currentPage = filter.page + 1;
        final hasPrev = filter.page > 0;
        final hasNext = currentPage < totalPages;

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
                top: BorderSide(color: AppColors.borderGray)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $total',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.darkGray),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: hasPrev
                        ? () => ref
                            .read(userListFilterProvider.notifier)
                            .state = filter.copyWith(
                                page: filter.page - 1)
                        : null,
                    color: hasPrev
                        ? AppColors.primaryBlue
                        : AppColors.borderGray,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$currentPage / $totalPages',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: hasNext
                        ? () => ref
                            .read(userListFilterProvider.notifier)
                            .state = filter.copyWith(
                                page: filter.page + 1)
                        : null,
                    color: hasNext
                        ? AppColors.primaryBlue
                        : AppColors.borderGray,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
