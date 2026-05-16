import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../database/seeds/seed_runner.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../../routing/route_names.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      debugPrint('Splash: Starting initialization...');
      // 1. Run database seeds if needed
      debugPrint('Splash: Running SeedRunner...');
      await ref.read(seedRunnerProvider).runIfNeeded();
      debugPrint('Splash: SeedRunner complete.');

      // 2. Check for an existing valid session
      debugPrint('Splash: Checking session...');
      await ref.read(authProvider.notifier).checkSession();
      debugPrint('Splash: Session check complete.');

      if (!mounted) return;

      // 3. Navigate based on auth state
      final authState = ref.read(authProvider);
      debugPrint('Splash: Auth state is ${authState.runtimeType}. Navigating...');
      if (authState is AuthAuthenticated) {
        // Trigger initial sync in background
        ref.read(syncManagerProvider).sync();
        context.go(RouteName.dashboard);
      } else {
        context.go(RouteName.login);
      }
    } catch (e, stack) {
      debugPrint('Splash: Initialization error: $e');
      debugPrint('Splash: Stack trace: $stack');
      if (mounted) {
        context.go(RouteName.login);
      }
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app_logo_v2.png',
                height: 120,
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.appName,
                style: AppTextStyles.displayLarge.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appFullName,
                style: AppTextStyles.displayMedium.copyWith(
                    fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.organization,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.white.withValues(alpha: 0.9)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
