import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bms_button.dart';
import '../../providers/auth_flow_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../routing/route_names.dart';

/// Six-digit verification step between the password and the app.
///
/// The code being checked comes from wherever [OtpController.issue] decided
/// it should: an emailed server-issued code when the sign-in reached the
/// server, or a code from the member's authenticator app when it did not.
/// If neither applies, the step never renders — [_bootstrap] routes straight
/// past it.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  Duration _resendRemaining = Duration.zero;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final offline = ref.read(postLoginStepProvider.notifier).wasOfflineLogin;
    final outcome = await ref
        .read(otpControllerProvider.notifier)
        .issue(userId: user.id, offlineLogin: offline);

    if (!mounted) return;

    if (outcome == OtpIssueOutcome.skipped) {
      ref.read(postLoginStepProvider.notifier).otpVerified();
      context.go(RouteName.biometric);
      return;
    }

    setState(() => _bootstrapping = false);
    if (outcome == OtpIssueOutcome.ready) {
      _focusNodes.first.requestFocus();
      _startResendCountdown(ref.read(otpControllerProvider).resendAfter);
    }
  }

  void _startResendCountdown(Duration length) {
    _resendTimer?.cancel();
    setState(() => _resendRemaining = length);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        final left = _resendRemaining - const Duration(seconds: 1);
        _resendRemaining = left.isNegative ? Duration.zero : left;
      });
      if (_resendRemaining == Duration.zero) t.cancel();
    });
  }

  String get _entered => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    ref.read(otpControllerProvider.notifier).clearError();

    // Paste of a full code — spread it across the boxes.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      _focusNodes[(digits.length - 1).clamp(0, 5)].requestFocus();
      if (_entered.length == 6) _verify();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_entered.length == 6) _verify();
  }

  void _onKey(int index, KeyEvent event) {
    // Backspace on an empty box steps back, the behaviour people expect.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verify() async {
    final error =
        await ref.read(otpControllerProvider.notifier).verify(_entered);
    if (!mounted) return;

    if (error != null) {
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
      return;
    }

    ref.read(postLoginStepProvider.notifier).otpVerified();
    context.go(RouteName.biometric);
  }

  Future<void> _resend() async {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    final error = await ref.read(otpControllerProvider.notifier).resend();
    if (!mounted || error != null) return;
    _startResendCountdown(ref.read(otpControllerProvider).resendAfter);
  }

  Future<void> _switchToEmail() async {
    for (final c in _controllers) {
      c.clear();
    }
    await ref.read(otpControllerProvider.notifier).switchToEmail();
    if (!mounted) return;
    final otp = ref.read(otpControllerProvider);
    if (otp.channel == OtpChannel.email) {
      _focusNodes.first.requestFocus();
      _startResendCountdown(otp.resendAfter);
    }
  }

  void _switchToAuthenticator() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.clear();
    }
    ref.read(otpControllerProvider.notifier).switchToAuthenticator();
    _focusNodes.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final otp = ref.watch(otpControllerProvider);

    if (_bootstrapping || otp.isIssuing) {
      return const _OtpScaffold(
        child: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    if (otp.blocker != null) {
      return _OtpScaffold(child: _BlockedPanel(message: otp.blocker!));
    }

    final isEmail = otp.channel == OtpChannel.email;
    final destination = otp.destination ?? user?.email ?? user?.username ?? 'your account';

    return _OtpScaffold(
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.md),
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.latte,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmail ? Icons.mark_email_read_outlined : Icons.smartphone,
              size: 27,
              color: AppColors.caramel,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Text('Verify Your Identity',
              style: AppTextStyles.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodySmall,
              children: isEmail
                  ? [
                      const TextSpan(text: 'We sent a 6-digit code to\n'),
                      TextSpan(
                        text: destination,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]
                  : const [
                      TextSpan(
                          text: 'Enter the 6-digit code from your '
                              'authenticator app'),
                    ],
            ),
            textAlign: TextAlign.center,
          ),

          if (otp.degraded != null) ...[
            const SizedBox(height: AppDimensions.md),
            _InfoBanner(message: otp.degraded!),
          ],

          const SizedBox(height: AppDimensions.lg),

          // ── Digit boxes ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) => _DigitBox(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  hasError: otp.error != null,
                  enabled: !otp.isVerifying,
                  onChanged: (v) => _onDigitChanged(i, v),
                  onKey: (e) => _onKey(i, e),
                )),
          ),

          if (otp.isVerifying) ...[
            const SizedBox(height: AppDimensions.md),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
            ),
          ],

          if (otp.error != null) ...[
            const SizedBox(height: AppDimensions.md),
            Text(otp.error!, style: AppTextStyles.errorText, textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppDimensions.lg),

          BmsButton(
            label: 'Verify Code',
            isFullWidth: true,
            isLoading: otp.isVerifying,
            onPressed: _entered.length == 6 && !otp.isVerifying ? _verify : null,
          ),
          const SizedBox(height: AppDimensions.md),

          if (isEmail)
            _resendRemaining > Duration.zero
                ? Text("Didn't receive it? Resend in ${_resendRemaining.inSeconds}s",
                    style: AppTextStyles.caption)
                : TextButton(
                    onPressed: _resend,
                    child: Text('Resend code',
                        style: AppTextStyles.button.copyWith(color: AppColors.amber)),
                  ),

          if (otp.canSwitchToEmail)
            TextButton(
              onPressed: _switchToEmail,
              child: Text("Don't have your authenticator app? Send code by email",
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.muted,
                    decoration: TextDecoration.underline,
                  )),
            )
          else if (otp.canSwitchToAuthenticator)
            TextButton(
              onPressed: _switchToAuthenticator,
              child: Text('Use authenticator app instead',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.muted,
                    decoration: TextDecoration.underline,
                  )),
            ),

          const SizedBox(height: AppDimensions.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 12, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                isEmail ? 'Expires in a few minutes' : 'Code refreshes every 30 seconds',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }
}

class _OtpScaffold extends ConsumerWidget {
  const _OtpScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onPressed: () async {
              ref.read(otpControllerProvider.notifier).reset();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(RouteName.login);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BlockedPanel extends StatelessWidget {
  const _BlockedPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: AppDimensions.md),
          Text('Verification unavailable',
              style: AppTextStyles.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKey;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(
        width: 46,
        height: 56,
        child: KeyboardListener(
          focusNode: FocusNode(skipTraversal: true),
          onKeyEvent: onKey,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            showCursor: false,
            style: AppTextStyles.monoLarge.copyWith(
              fontSize: 22,
              color: filled ? AppColors.cream : AppColors.espresso,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: filled ? AppColors.espresso : AppColors.white,
              contentPadding: EdgeInsets.zero,
              enabledBorder: _border(
                  hasError ? AppColors.danger : (filled ? AppColors.espresso : AppColors.latte)),
              focusedBorder: _border(AppColors.amber, 2),
              border: _border(AppColors.latte),
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color c, [double w = 2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(color: c, width: w),
      );
}
