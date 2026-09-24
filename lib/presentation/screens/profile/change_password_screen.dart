import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cbtl_app_bar.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../core/widgets/cbtl_loading_overlay.dart';
import '../../../core/widgets/cbtl_text_field.dart';
import '../../../core/utils/bcrypt_util.dart';
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
      backgroundColor: AppColors.cream,
      appBar: CbtlAppBar(
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
                        CbtlTextField(
                          label: AppStrings.currentPassword,
                          controller: _currentCtrl,
                          obscureText: true,
                          prefixIcon: Icons.lock_outline,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        CbtlTextField(
                          label: AppStrings.newPassword,
                          controller: _newCtrl,
                          obscureText: true,
                          prefixIcon: Icons.lock_reset,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v == _currentCtrl.text) {
                              return 'New password must differ from current';
                            }
                            // Mirrors the rule the use case enforces, so a
                            // weak password is caught inline instead of after
                            // a round trip.
                            if (!BcryptUtil.isStrong(v)) {
                              return 'Password does not meet the requirements below';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        _PasswordRequirements(password: _newCtrl.text),
                        const SizedBox(height: AppDimensions.md),
                        CbtlTextField(
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
                  CbtlButton(
                    label: AppStrings.changePassword,
                    onPressed: _onSave,
                    isFullWidth: true,
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const CbtlLoadingOverlay(),
        ],
      ),
    );
  }
}

/// Live guide for the password rules enforced by [BcryptUtil.isStrong].
/// Each line ticks as the typed password satisfies it, so the user can see
/// what is still missing rather than guessing after a rejected submit.
class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      'At least 8 characters': password.length >= 8,
      'One uppercase letter (A-Z)': password.contains(RegExp(r'[A-Z]')),
      'One number (0-9)': password.contains(RegExp(r'[0-9]')),
      r'One special character (!@#$%^&* etc.)':
          password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]')),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your new password must have:',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final entry in rules.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    entry.value
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 15,
                    color: entry.value ? AppColors.success : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: AppTextStyles.bodySmall.copyWith(
                        color:
                            entry.value ? AppColors.success : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
