import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/widgets/bms_text_field.dart';
import '../../../core/widgets/bms_loading_overlay.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_providers.dart';
import '../../../routing/route_names.dart';
import '../../../core/utils/date_format_util.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  String? _errorMessage;
  int? _attemptsRemaining;
  DateTime? _lockedUntil;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _attemptsRemaining = null;
      _lockedUntil = null;
    });

    final result = await ref
        .read(authProvider.notifier)
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result is LoginSuccess) {
      if (result.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Signed in offline. Changes will sync when you reconnect.')),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      context.go(RouteName.dashboard);
      return;
    }

    if (result is LoginFailure) {
      final failure = result.failure;
      if (failure is AccountLockedFailure) {
        setState(() => _lockedUntil = failure.lockedUntil);
      } else if (failure is InvalidCredentialsFailure) {
        setState(() {
          _errorMessage = failure.serverMessage ?? AppStrings.invalidCredentials;
          _attemptsRemaining = failure.attemptsRemaining;
        });
      } else if (failure is AccountDisabledFailure) {
        setState(() => _errorMessage = AppStrings.accountDisabled);
      } else if (failure is OfflineSessionExpiredFailure) {
        setState(() => _errorMessage =
            'Your offline session has expired. Please connect to the internet and sign in once to continue working offline.');
      } else if (failure is NetworkFailure) {
        setState(() => _errorMessage = 'Could not connect to the server. Check your internet connection and try again.');
      } else {
        setState(() => _errorMessage = AppStrings.errorGeneric);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _lockedUntil != null &&
        _lockedUntil!.isAfter(DateTime.now().toUtc());

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ── Branded header (top 35%) ────────────────────────────
                      Expanded(
                        flex: 35,
                        child: _buildHeader(),
                      ),
                      // ── Login card (bottom 65%) ─────────────────────────────
                      Expanded(
                        flex: 65,
                        child: _buildLoginCard(isLocked),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) const BmsLoadingOverlay(message: 'Signing in…'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isOfflineAsync = ref.watch(isOfflineProvider);
    final isOffline = isOfflineAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app_logo_v2.png',
                height: 100,
              ),
              const SizedBox(height: 16),
              const Text(AppStrings.appName, style: AppTextStyles.displayLarge),
              const SizedBox(height: 4),
              Text(
                AppStrings.appFullName,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
        if (isOffline)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Offline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoginCard(bool isLocked) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(AppStrings.loginTitle, style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text(
                'Sign in to continue',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppDimensions.lg),

              // ── Username ──────────────────────────────────────────────
              BmsTextField(
                label: AppStrings.username,
                controller: _usernameCtrl,
                hint: 'Enter your username',
                prefixIcon: Icons.person_outline,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                enabled: !isLocked && !_isLoading,
                autofocus: true,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppDimensions.md),

              // ── Password ──────────────────────────────────────────────
              BmsTextField(
                label: AppStrings.password,
                controller: _passwordCtrl,
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                focusNode: _passwordFocus,
                enabled: !isLocked && !_isLoading,
                onSubmitted: (_) => _onSubmit(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppDimensions.md),

              // ── Error / lockout messages ──────────────────────────────
              if (isLocked) _buildLockoutBanner(),
              if (_errorMessage != null && !isLocked)
                _buildErrorBanner(),

              const SizedBox(height: AppDimensions.md),

              // ── Sign in button ────────────────────────────────────────
              BmsButton(
                label: AppStrings.signIn,
                onPressed: isLocked ? null : _onSubmit,
                isFullWidth: true,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppDimensions.lg),
              Center(
                child: Text(
                  'Contact your administrator if you cannot access your account.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockoutBanner() {
    return _BannerCard(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderColor: AppColors.warning,
      icon: Icons.lock_clock,
      iconColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Temporarily Locked',
            style: AppTextStyles.h3.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: 4),
          _LockdownTimer(lockedUntil: _lockedUntil!),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return _BannerCard(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderColor: AppColors.danger,
      icon: Icons.error_outline,
      iconColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errorMessage!, style: AppTextStyles.errorText),
          if (_attemptsRemaining != null && _attemptsRemaining! > 0)
            Text(
              '${_attemptsRemaining} ${AppStrings.attemptsRemaining}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.danger),
            ),
          if (_attemptsRemaining != null && _attemptsRemaining! <= 0)
            Text(
              'Next attempt will lock your account for 30 minutes.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final Color color;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Shows a live countdown that rebuilds every second during lockout.
class _LockdownTimer extends StatefulWidget {
  const _LockdownTimer({required this.lockedUntil});
  final DateTime lockedUntil;

  @override
  State<_LockdownTimer> createState() => _LockdownTimerState();
}

class _LockdownTimerState extends State<_LockdownTimer> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (ctx, _) {
        final remaining = widget.lockedUntil.difference(DateTime.now().toUtc());
        if (remaining.isNegative) {
          return Text('Please try again.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.warning));
        }
        return Text(
          'Try again in ${DateFormatUtil.countdownTo(widget.lockedUntil)}',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
        );
      },
    );
  }
}

