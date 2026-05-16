import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/widgets/bms_loading_overlay.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_management_provider.dart';

/// The full permission matrix for a single role.
/// Rows = modules (grouped by parent module).
/// Columns = each permission code.
class PermissionMatrixScreen extends ConsumerStatefulWidget {
  const PermissionMatrixScreen({super.key, required this.roleId});
  final String roleId;

  @override
  ConsumerState<PermissionMatrixScreen> createState() =>
      _PermissionMatrixScreenState();
}

class _PermissionMatrixScreenState
    extends ConsumerState<PermissionMatrixScreen> {
  // Local copy of the matrix for editing: moduleCode → permCode → isGranted
  Map<String, Map<String, bool>>? _localMatrix;
  bool _isSaving = false;
  bool _isDirty = false;
  String? _roleName;

  @override
  void initState() {
    super.initState();
    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    final matrix = await ref.read(
        rolePermissionMatrixProvider(widget.roleId).future);
    final roles = await ref.read(roleListProvider.future);
    if (mounted) {
      setState(() {
        _localMatrix = Map.fromEntries(matrix.entries.map(
            (e) => MapEntry(e.key, Map<String, bool>.from(e.value))));
        _roleName = roles
            .where((r) => r.id == widget.roleId)
            .firstOrNull
            ?.name;
      });
    }
  }

  void _toggle(String moduleCode, String permCode, bool value) {
    setState(() {
      _localMatrix!.putIfAbsent(moduleCode, () => <String, bool>{})[permCode] = value;
      _isDirty = true;
    });
  }

  void _grantAll(String permCode) {
    setState(() {
      for (final m in _localMatrix!.keys) {
        _localMatrix![m]![permCode] = true;
      }
      _isDirty = true;
    });
  }

  void _denyAll(String permCode) {
    setState(() {
      for (final m in _localMatrix!.keys) {
        _localMatrix![m]![permCode] = false;
      }
      _isDirty = true;
    });
  }

  Future<void> _onSave() async {
    setState(() => _isSaving = true);
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    await ref.read(roleManagementProvider.notifier).savePermissionMatrix(
          roleId: widget.roleId,
          matrix: _localMatrix!,
          savedBy: currentUser.id,
        );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isDirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.permissionsSaved),
        backgroundColor: AppColors.success,
      ),
    );
  }

  static const double _moduleColWidth = 120.0;
  static const double _switchColWidth = 64.0;

  // Permission column headers
  static const List<String> _cols = [
    'VIEW', 'CREATE', 'EDIT', 'DELETE',
    'EXPORT', 'PRINT', 'APPROVE', 'SUBMIT', 'SYNC',
  ];

  @override
  Widget build(BuildContext context) {
    if (_localMatrix == null) {
      return Scaffold(
        appBar: BmsAppBar(title: AppStrings.permissionMatrix),
        body: const Center(
            child: CircularProgressIndicator(
                color: AppColors.primaryBlue)),
      );
    }

    // Sort module rows by DB displayOrder so they match the sidebar order.
    final orderedModules = ref.watch(activeModulesProvider).valueOrNull ?? [];
    final moduleOrder = {
      for (var i = 0; i < orderedModules.length; i++) orderedModules[i].code: i
    };
    final modules = _localMatrix!.keys.toList()
      ..sort((a, b) =>
          (moduleOrder[a] ?? 99).compareTo(moduleOrder[b] ?? 99));

    // Fixed total width so header and rows always align regardless of orientation
    final totalWidth = _moduleColWidth + 12.0 + _switchColWidth * _cols.length;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: BmsAppBar(
        title: AppStrings.permissionMatrix,
        subtitle: _roleName,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/dashboard/roles'),
        ),
        actions: [
          if (_isDirty)
            BmsButton(
              label: AppStrings.savePermissions,
              onPressed: _onSave,
              variant: BmsButtonVariant.ghost,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Single horizontal scroll wraps header + rows together ──
              // This keeps columns aligned in both portrait and landscape.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth,
                    child: Column(
                      children: [
                        _buildHeaderRow(),
                        Expanded(
                          child: ListView.separated(
                            itemCount: modules.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final moduleCode = modules[i];
                              final perms =
                                  _localMatrix![moduleCode] ?? {};
                              return _buildModuleRow(moduleCode, perms);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Save button ─────────────────────────────────────────
              if (_isDirty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    child: BmsButton(
                      label: AppStrings.savePermissions,
                      onPressed: _onSave,
                      isFullWidth: true,
                      icon: Icons.save,
                    ),
                  ),
                ),
            ],
          ),
          if (_isSaving)
            const BmsLoadingOverlay(message: 'Saving permissions…'),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: _moduleColWidth + 12),
          ..._cols.map((c) => SizedBox(
                width: _switchColWidth,
                child: GestureDetector(
                  onTap: () => _showBulkMenu(c),
                  child: Column(
                    children: [
                      Text(
                        c.length > 6 ? c.substring(0, 6) : c,
                        style: AppTextStyles.tableHeader.copyWith(fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: AppColors.accentBlue, size: 14),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildModuleRow(String moduleCode, Map<String, bool> perms) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: _moduleColWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                moduleCode
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((w) => w.isEmpty
                        ? ''
                        : w[0].toUpperCase() + w.substring(1).toLowerCase())
                    .join(' '),
                style: AppTextStyles.tableCell.copyWith(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ..._cols.map((c) {
            final granted = perms[c] ?? false;
            return SizedBox(
              width: _switchColWidth,
              child: Switch(
                value: granted,
                onChanged: (v) => _toggle(moduleCode, c, v),
                activeColor: AppColors.primaryBlue,
                inactiveTrackColor: AppColors.borderGray,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showBulkMenu(String permCode) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle,
                  color: AppColors.success),
              title: Text(
                  '${AppStrings.grantAll} — $permCode'),
              onTap: () {
                _grantAll(permCode);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel,
                  color: AppColors.danger),
              title: Text(
                  '${AppStrings.denyAll} — $permCode'),
              onTap: () {
                _denyAll(permCode);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

