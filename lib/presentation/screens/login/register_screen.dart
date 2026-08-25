import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/bcrypt_util.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/widgets/bms_text_field.dart';
import '../../../core/widgets/bms_loading_overlay.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../providers/auth_flow_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../routing/route_names.dart';

/// Self-service sign-up for a new member.
///
/// Deliberately online-only — there's no offline path for an account that
/// doesn't exist on the device yet (unlike [LoginScreen], which falls back
/// to a cached bcrypt hash). On success this behaves exactly like a fresh
/// login: same OTP → biometric steps, same session set up for next time.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result is RegisterSuccess) {
      ref
          .read(postLoginStepProvider.notifier)
          .beginVerification(offline: false);
      context.go(RouteName.otp);
      return;
    }

    if (result is RegisterFailure) {
      final failure = result.failure;
      if (failure is ValidationFailure) {
        setState(() => _errorMessage = failure.message);
      } else if (failure is NetworkFailure) {
        setState(() => _errorMessage =
            'Could not connect to the server. Check your internet connection and try again.');
      } else {
        setState(() => _errorMessage = AppStrings.errorGeneric);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.espresso,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to sign in',
            onPressed: () => context.go(RouteName.login),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimensions.sm),
                      Text('Create Your Account', style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text(
                        'Join to start collecting stamps and rewards',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // ── Name ──────────────────────────────────────────
                      BmsTextField(
                        label: 'Full Name',
                        controller: _nameCtrl,
                        hint: 'Enter your full name',
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        autofocus: true,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: AppDimensions.md),

                      // ── Email ─────────────────────────────────────────
                      BmsTextField(
                        label: 'Email',
                        controller: _emailCtrl,
                        hint: 'Enter your email',
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        focusNode: _emailFocus,
                        onSubmitted: (_) => _phoneFocus.requestFocus(),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Required';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),

                      // ── Phone (optional) ─────────────────────────────
                      BmsTextField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        hint: 'Optional',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        focusNode: _phoneFocus,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: AppDimensions.md),

                      // ── Password ──────────────────────────────────────
                      BmsTextField(
                        label: AppStrings.newPassword,
                        controller: _passwordCtrl,
                        hint: 'Create a password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        focusNode: _passwordFocus,
                        enabled: !_isLoading,
                        onSubmitted: (_) => _onSubmit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!BcryptUtil.isStrong(v)) {
                            return AppStrings.passwordTooWeak;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.4),
                                width: 1.5),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 19),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style: AppTextStyles.errorText),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppDimensions.md),

                      BmsButton(
                        label: 'Create Account',
                        onPressed: _onSubmit,
                        isFullWidth: true,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: AppDimensions.lg),
                      Center(
                        child: TextButton(
                          onPressed:
                              _isLoading ? null : () => context.go(RouteName.login),
                          child: Text.rich(
                            TextSpan(
                              style: AppTextStyles.bodySmall,
                              children: [
                                const TextSpan(
                                    text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Sign In',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const BmsLoadingOverlay(message: 'Creating your account…'),
          ],
        ),
      ),
    );
  }
}
