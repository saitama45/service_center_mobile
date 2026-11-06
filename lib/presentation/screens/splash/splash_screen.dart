import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/brand/brand_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../../routing/route_names.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Roasted Black backdrop needs light status-bar icons.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: const Scaffold(
        backgroundColor: AppColors.roastedBlack,
        body: Stack(
          children: [
            // The book's section pages: one Purple Aura streak at the left
            // edge of a Roasted Black frame (p19, p40).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: PurpleAura(width: 44, side: AxisDirection.left),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The creamy white hero logo, the version the book allows
                  // on dark (p21). It names the brand, so no title beside it.
                  SealIn(
                    delay: Duration(milliseconds: 120),
                    child: BrandLogo(size: 176, onDark: true),
                  ),
                  SizedBox(height: 44),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: AppColors.creamyWhite,
                      backgroundColor: Color(0x40FAEFE6),
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 22),
                  AppVersionText(color: AppColors.californiaCream),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
