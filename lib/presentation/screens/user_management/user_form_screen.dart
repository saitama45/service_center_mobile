import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bcrypt_util.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/widgets/bms_loading_overlay.dart';
import '../../../core/widgets/bms_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_management_provider.dart';
import '../../providers/user_management_provider.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.userId});
  final String? userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _employeeIdCtrl = TextEditingController();

  String? _selectedRoleId;
  bool _isActive = true;
  bool _isLoading = false;
  String? _error;

  bool get isEditing => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadUser();
  }

  Future<void> _loadUser() async {
    final db = ref.read(
        // We'll read directly from DB for simplicity on edit load
        userListProvider.future);
    final users = await db;
    final user = users.where((u) => u.id == widget.userId).firstOrNull;
    if (user != null && mounted) {
      setState(() {
        _fullNameCtrl.text = user.fullName;
        _usernameCtrl.text = user.username;
        _emailCtrl.text = user.email ?? '';
        _employeeIdCtrl.text = user.employeeId ?? '';
        _selectedRoleId = user.roleId;
        _isActive = user.isActive;
      });
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _employeeIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedRoleId == null) {
      setState(() => _error = 'Please select a role.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    bool success;
    if (isEditing) {
      success = await ref.read(userManagementProvider.notifier).updateUser(
            userId: widget.userId!,
            roleId: _selectedRoleId!,
            fullName: _fullNameCtrl.text,
            email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
            employeeId: _employeeIdCtrl.text.isEmpty
                ? null
                : _employeeIdCtrl.text,
            isActive: _isActive,
            updatedBy: currentUser.id,
          );
    } else {
      success = await ref.read(userManagementProvider.notifier).createUser(
            roleId: _selectedRoleId!,
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text,
            fullName: _fullNameCtrl.text,
            email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
            employeeId: _employeeIdCtrl.text.isEmpty
                ? null
                : _employeeIdCtrl.text,
            createdBy: currentUser.id,
          );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      context.go('/dashboard/users');
    } else {
      final err = ref.read(userManagementProvider).error;
      setState(() => _error = err?.toString() ?? AppStrings.errorGeneric);
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final newPassCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.resetPassword, style: AppTextStyles.h2),
      content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      BmsTextField(
        label: AppStrings.newPassword,
        controller: newPassCtrl,
        obscureText: true,
      ),
      ],
      ),
      actions: [          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.save,
                style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && newPassCtrl.text.isNotEmpty && mounted) {
      if (!BcryptUtil.isStrong(newPassCtrl.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(AppStrings.passwordTooWeak),
              backgroundColor: AppColors.danger),
        );
        return;
      }
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;
      await ref.read(userManagementProvider.notifier).resetUserPassword(
            widget.userId!,
            newPassCtrl.text,
            currentUser.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password reset successfully.'),
              backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(roleListProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: BmsAppBar(
        title: isEditing ? AppStrings.editUser : AppStrings.addUser,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/dashboard/users'),
        ),
        actions: isEditing
            ? [
                TextButton(
                  onPressed: _showResetPasswordDialog,
                  child: Text(AppStrings.resetPassword,
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.lightBlue)),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(children: [
                    BmsTextField(
                      label: AppStrings.fullName,
                      controller: _fullNameCtrl,
                      prefixIcon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    BmsTextField(
                      label: AppStrings.username,
                      controller: _usernameCtrl,
                      prefixIcon: Icons.alternate_email,
                      readOnly: isEditing,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v)) {
                          return 'Only letters, numbers, dots, dashes, underscores';
                        }
                        return null;
                      },
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: AppDimensions.md),
                      BmsTextField(
                        label: AppStrings.password,
                        controller: _passwordCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!BcryptUtil.isStrong(v)) {
                            return AppStrings.passwordTooWeak;
                          }
                          return null;
                        },
                      ),
                    ],
                  ]),
                  const SizedBox(height: AppDimensions.md),
                  _buildCard(children: [
                    Text('Role & Assignment', style: AppTextStyles.h3),
                    const SizedBox(height: AppDimensions.md),
                    rolesAsync.when(
                      data: (roles) => DropdownButtonFormField<String>(
                        value: _selectedRoleId,
                        decoration: _dropdownDecoration(AppStrings.role),
                        items: roles
                            .where((r) => r.isActive)
                            .map((r) => DropdownMenuItem<String>(
                                  value: r.id,
                                  child: Text(r.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedRoleId = v),
                        validator: (v) =>
                            v == null ? 'Please select a role' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    BmsTextField(
                      label: AppStrings.employeeId,
                      controller: _employeeIdCtrl,
                      hint: 'ID # (optional)',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    BmsTextField(
                      label: AppStrings.email,
                      controller: _emailCtrl,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ]),
                  if (isEditing) ...[
                    const SizedBox(height: AppDimensions.md),
                    _buildCard(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppStrings.activeStatus,
                                  style: AppTextStyles.h3),
                              Text(
                                _isActive
                                    ? 'User can log in'
                                    : 'User cannot log in',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeColor: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ]),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppDimensions.md),
                    SelectionArea(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: Text(_error!, style: AppTextStyles.errorText),
                      ),
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.label,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide:
            const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      filled: true,
      fillColor: AppColors.white,
    );
  }
}

