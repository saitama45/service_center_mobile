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
import '../../../domain/usecases/auth/change_password_usecase.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final result = await ref.read(changePasswordUseCaseProvider).call(
          userId: user.id,
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
          confirmPassword: _confirmCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result is ChangePasswordSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.passwordChanged),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/dashboard/profile');
    } else if (result is ChangePasswordFailure) {
      setState(() => _error = result.failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: BmsAppBar(
        title: AppStrings.changePassword,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/dashboard/profile'),
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
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4)
                      ],
                    ),
                    child: Column(
                      children: [
                        BmsTextField(
                          label: AppStrings.currentPassword,
                          controller: _currentCtrl,
                          obscureText: true,
                          prefixIcon: Icons.lock_outline,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        BmsTextField(
                          label: AppStrings.newPassword,
                          controller: _newCtrl,
                          obscureText: true,
                          prefixIcon: Icons.lock_reset,
                          hint: 'Min 8 chars, 1 upper, 1 digit, 1 special',
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v == _currentCtrl.text) {
                              return 'New password must differ from current';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.md),
                        BmsTextField(
                          label: AppStrings.confirmPassword,
                          controller: _confirmCtrl,
                          obscureText: true,
                          prefixIcon: Icons.check_circle_outline,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v != _newCtrl.text) {
                              return AppStrings.passwordMismatch;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
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
                    label: AppStrings.changePassword,
                    onPressed: _onSave,
                    isFullWidth: true,
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const BmsLoadingOverlay(),
        ],
      ),
    );
  }
}

