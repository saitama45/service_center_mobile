import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../database/seeds/seed_runner.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
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
        ref.read(syncManagerProvider).sync(userId: ref.read(currentUserProvider)?.id);
        // Keep the cached member QR fresh whenever we resume with a network
        // — cheap, and it's what makes the code still work on a later
        // fully-offline open (see prefetchMemberQr's doc comment).
        prefetchMemberQr(ref);
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Espresso backdrop needs light status-bar icons.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: AppColors.espresso,
      body: Container(
        // Warm radial glow behind the mark so the flat espresso has depth.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 0.95,
            colors: [AppColors.darkBrown, AppColors.espresso],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The brand mark is an opaque square, so it fills the tile
                // edge-to-edge rather than floating inside a cream frame.
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.espresso.withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/app_logo.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    AppStrings.appName,
                    style: AppTextStyles.displayLarge
                        .copyWith(color: AppColors.cream),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: AppColors.amber,
                    backgroundColor: Color(0x33EDD9B7),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
