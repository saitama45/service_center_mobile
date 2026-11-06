import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bcrypt_util.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../../core/widgets/cbtl_text_field.dart';
import '../../../data/datasources/remote/password_reset_remote_datasource.dart';
import '../../../routing/route_names.dart';
import '../../providers/app_providers.dart';

enum _Step { email, code, password }

/// Signed-out password reset, done entirely in the app.
///
/// The server emails a one-time code to the account's address; the code is
/// checked before the new-password step is shown, and checked again (and
/// spent) by the reset itself, so nothing changes until the member proves
/// they own the inbox. Online-only by nature — there's no offline way to
/// prove that. See [PasswordResetRemoteDatasource] for the contract.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _confirmFocus = FocusNode();

  _Step _step = _Step.email;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  Timer? _resendTimer;
  int _resendIn = 0;

  PasswordResetRemoteDatasource get _remote =>
      ref.read(passwordResetRemoteDatasourceProvider);

  String get _email => _emailCtrl.text.trim().toLowerCase();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _startResendCountdown(Duration wait) {
    _resendTimer?.cancel();
    setState(() => _resendIn = wait.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 1: request a code ────────────────────────────────────────────────

  Future<void> _sendCode({bool isResend = false}) async {
    if (!isResend && !(_emailFormKey.currentState?.validate() ?? false)) return;

    await _run(() async {
      final result = await _remote.requestCode(_email);
      if (!mounted) return;

      switch (result) {
        case PasswordResetCodeSent(:final resendAfter):
          _codeCtrl.clear();
          setState(() {
            _step = _Step.code;
            _infoMessage = isResend
                ? 'A new code is on its way. Only the newest code works.'
                : null;
          });
          _startResendCountdown(resendAfter);
        case PasswordResetThrottled(:final retryAfter, :final message):
          setState(() => _errorMessage = message);
          if (_step == _Step.code) _startResendCountdown(retryAfter);
        case PasswordResetFailed(:final message):
          setState(() => _errorMessage = message);
        default:
          setState(() => _errorMessage = AppStrings.errorGeneric);
      }
    });
  }

  // ── Step 2: check the code ────────────────────────────────────────────────

  Future<void> _verifyCode() async {
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;

    await _run(() async {
      final result = await _remote.verifyCode(_email, _codeCtrl.text.trim());
      if (!mounted) return;

      switch (result) {
        case PasswordResetOk():
          setState(() {
            _step = _Step.password;
            _infoMessage = null;
          });
        case PasswordResetWrongCode(:final message, :final attemptsRemaining):
          setState(() => _errorMessage = attemptsRemaining == null
              ? message
              : '$message $attemptsRemaining '
                  '${attemptsRemaining == 1 ? 'attempt' : 'attempts'} left.');
        case PasswordResetCodeExpired(:final message):
        case PasswordResetFailed(:final message):
          setState(() => _errorMessage = message);
        default:
          setState(() => _errorMessage = AppStrings.errorGeneric);
      }
    });
  }

  // ── Step 3: set the new password ──────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    await _run(() async {
      final result = await _remote.resetPassword(
        email: _email,
        code: _codeCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;

      switch (result) {
        case PasswordResetOk():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Password reset. Sign in with your new password.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(RouteName.login);
        case PasswordResetCodeExpired(:final message):
        case PasswordResetWrongCode(:final message):
          // The code died between steps (it expired while the member was
          // choosing a password). Send them back for a fresh one.
          _codeCtrl.clear();
          setState(() {
            _step = _Step.code;
            _errorMessage = message;
          });
        case PasswordResetFailed(:final message):
          setState(() => _errorMessage = message);
        default:
          setState(() => _errorMessage = AppStrings.errorGeneric);
      }
    });
  }

  void _back() {
    if (_isLoading) return;
    if (_step == _Step.email) {
      context.go(RouteName.login);
      return;
    }
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      _step = _step == _Step.password ? _Step.code : _Step.email;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AppColors.creamyWhite,
          appBar: AppBar(
            // The bar is the page itself: creamy white, an ink back arrow.
            backgroundColor: AppColors.creamyWhite,
            foregroundColor: AppColors.roastedBlack,
            iconTheme: const IconThemeData(color: AppColors.roastedBlack),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: _back,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimensions.sm),
                  _StepIndicator(current: _step.index),
                  const SizedBox(height: AppDimensions.lg),
                  switch (_step) {
                    _Step.email => _buildEmailStep(),
                    _Step.code => _buildCodeStep(),
                    _Step.password => _buildPasswordStep(),
                  },
                  const SizedBox(height: AppDimensions.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppTextStyles.caps('Forgot Password'), style: AppTextStyles.h1),
          const SizedBox(height: AppDimensions.sm),
          Text(
            "Enter the email you signed up with and we'll send you a "
            'code to reset your password.',
            style: _lead,
          ),
          const SizedBox(height: AppDimensions.lg),
          CbtlTextField(
            label: 'Email',
            controller: _emailCtrl,
            hint: 'Enter your email',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            autofocus: true,
            onSubmitted: (_) => _sendCode(),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Required';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),
          ..._messages(),
          CbtlButton(
            label: 'Send Code',
            onPressed: _sendCode,
            isFullWidth: true,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppTextStyles.caps('Check Your Email'), style: AppTextStyles.h1),
          const SizedBox(height: AppDimensions.sm),
          Text.rich(
            TextSpan(
              style: _lead,
              children: [
                const TextSpan(
                    text: 'If an account uses '),
                TextSpan(
                  text: _email,
                  style: _lead.copyWith(
                    color: AppColors.roastedBlack,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                    text: ', we sent it a 6-digit code. It expires in '
                        '10 minutes — check your spam folder too.'),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          CbtlTextField(
            label: 'Reset Code',
            controller: _codeCtrl,
            hint: '6-digit code',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            autofocus: true,
            onSubmitted: (_) => _verifyCode(),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Required';
              if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                return 'Enter the 6-digit code from the email';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),
          ..._messages(),
          CbtlButton(
            label: 'Verify Code',
            onPressed: _verifyCode,
            isFullWidth: true,
            isLoading: _isLoading,
          ),
          const SizedBox(height: AppDimensions.md),
          Center(
            child: TextButton(
              onPressed: (_isLoading || _resendIn > 0)
                  ? null
                  : () => _sendCode(isResend: true),
              // Counting down: a quiet ink3 caption. Ready: an ink link.
              child: Text(
                _resendIn > 0
                    ? 'Resend code in ${_resendIn}s'
                    : 'Resend code',
                style: _resendIn > 0
                    ? AppTextStyles.chip.copyWith(color: AppColors.ink3)
                    : AppTextStyles.button.copyWith(
                        color: AppColors.roastedBlack,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.roastedBlack,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppTextStyles.caps('Set a New Password'),
              style: AppTextStyles.h1),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Choose a password you haven\'t used here before. You\'ll be '
            'signed out on every device once it\'s changed.',
            style: _lead,
          ),
          const SizedBox(height: AppDimensions.lg),
          CbtlTextField(
            label: AppStrings.newPassword,
            controller: _passwordCtrl,
            hint: 'Create a new password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            autofocus: true,
            onSubmitted: (_) => _confirmFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!BcryptUtil.isStrong(v)) return AppStrings.passwordTooWeak;
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),
          CbtlTextField(
            label: AppStrings.confirmPassword,
            controller: _confirmCtrl,
            hint: 'Type it again',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            textInputAction: TextInputAction.done,
            focusNode: _confirmFocus,
            enabled: !_isLoading,
            onSubmitted: (_) => _resetPassword(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v != _passwordCtrl.text) return AppStrings.passwordMismatch;
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.md),
          ..._messages(),
          CbtlButton(
            label: AppStrings.resetPassword,
            onPressed: _resetPassword,
            isFullWidth: true,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  List<Widget> _messages() => [
        if (_errorMessage != null) ...[
          _Banner(
            message: _errorMessage!,
            background: AppColors.dangerSurface,
            border: AppColors.dangerBorder,
            foreground: AppColors.danger,
            icon: Icons.error_outline,
          ),
          const SizedBox(height: AppDimensions.md),
        ] else if (_infoMessage != null) ...[
          // Confirmations stay in the base colours: no green.
          _Banner(
            message: _infoMessage!,
            background: AppColors.successSurface,
            border: AppColors.line,
            foreground: AppColors.success,
            icon: Icons.mark_email_read_outlined,
          ),
          const SizedBox(height: AppDimensions.md),
        ],
      ];
}

/// The lead paragraph under each step's headline.
final TextStyle _lead = AppTextStyles.bodyLarge.copyWith(color: AppColors.ink2);

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final String message;
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: foreground, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three short bars — email, code, new password. Done and current steps are
/// Roasted Black; the steps still ahead are a hairline.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.roastedBlack : AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
