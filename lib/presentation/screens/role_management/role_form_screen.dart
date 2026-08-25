import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/widgets/bms_loading_overlay.dart';
import '../../../core/widgets/bms_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_management_provider.dart';

class RoleFormScreen extends ConsumerStatefulWidget {
  const RoleFormScreen({super.key, this.roleId});
  final String? roleId;

  @override
  ConsumerState<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends ConsumerState<RoleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isActive = true;
  bool _isSystem = false;
  bool _isLoading = false;
  String? _error;

  bool get isEditing => widget.roleId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadRole();
  }

  Future<void> _loadRole() async {
    final roles = await ref.read(roleListProvider.future);
    final role = roles.where((r) => r.id == widget.roleId).firstOrNull;
    if (role != null && mounted) {
      setState(() {
        _codeCtrl.text = role.code;
        _nameCtrl.text = role.name;
        _descCtrl.text = role.description ?? '';
        _isActive = role.isActive;
        _isSystem = role.isSystem;
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    bool success;
    if (isEditing) {
      success = await ref.read(roleManagementProvider.notifier).updateRole(
            roleId: widget.roleId!,
            name: _nameCtrl.text,
            description:
                _descCtrl.text.isEmpty ? null : _descCtrl.text,
            isActive: _isActive,
            updatedBy: currentUser.id,
          );
    } else {
      success = await ref.read(roleManagementProvider.notifier).createRole(
            code: _codeCtrl.text,
            name: _nameCtrl.text,
            description:
                _descCtrl.text.isEmpty ? null : _descCtrl.text,
            createdBy: currentUser.id,
          );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      context.go('/dashboard/roles');
    } else {
      final err = ref.read(roleManagementProvider).error;
      setState(() => _error = err?.toString() ?? AppStrings.errorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: BmsAppBar(
        title: isEditing ? AppStrings.editRole : AppStrings.addRole,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/dashboard/roles'),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildCard(children: [
                    BmsTextField(
                      label: AppStrings.roleCode,
                      controller: _codeCtrl,
                      readOnly: isEditing, // code is immutable after creation
                      prefixIcon: Icons.code,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!RegExp(r'^[A-Z_]+$').hasMatch(v.toUpperCase())) {
                          return 'Only uppercase letters and underscores';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.md),
                    BmsTextField(
                      label: AppStrings.role,
                      controller: _nameCtrl,
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    BmsTextField(
                      label: AppStrings.roleDescription,
                      controller: _descCtrl,
                      maxLines: 3,
                      prefixIcon: Icons.info_outline,
                    ),
                  ]),
                  if (isEditing && !_isSystem) ...[
                    const SizedBox(height: AppDimensions.md),
                    _buildCard(children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(AppStrings.activeStatus,
                                  style: AppTextStyles.h3),
                              Text(
                                _isActive
                                    ? 'Role can be assigned to users'
                                    : 'Role cannot be assigned',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                          Switch(
                            value: _isActive,
                            onChanged: (v) =>
                                setState(() => _isActive = v),
                            activeColor: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ]),
                  ],
                  if (_isSystem && isEditing) ...[
                    const SizedBox(height: AppDimensions.md),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryBlue.withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.primaryBlue),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.systemRole +
                                  ' — Code and active status cannot be changed.',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppDimensions.md),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: SelectableText(_error!, style: AppTextStyles.errorText),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.lg),
                  BmsButton(
                    label: AppStrings.save,
                    onPressed: _onSave,
                    isFullWidth: true,
                    icon: Icons.save_outlined,
                  ),
                  const SizedBox(height: AppDimensions.lg),
                ],
              ),
            ),
          ),
          if (_isLoading) const BmsLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.latte),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

