import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/providers/auth_flow_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/authenticator_setup_screen.dart';
import '../presentation/screens/auth/biometric_screen.dart';
import '../presentation/screens/auth/otp_screen.dart';
import '../presentation/screens/campaigns/campaigns_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/ledger/ledger_screen.dart';
import '../presentation/screens/login/forgot_password_screen.dart';
import '../presentation/screens/login/login_screen.dart';
import '../presentation/screens/login/register_screen.dart';
import '../presentation/screens/main_shell.dart';
import '../presentation/screens/profile/change_password_screen.dart';
import '../presentation/screens/profile/privacy_policy_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/scan/scan_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import 'route_names.dart';

/// Screens reachable while the post-login steps are still outstanding.
const _verificationRoutes = {RouteName.otp, RouteName.biometric};

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteName.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final location = state.matchedLocation;
      final step = ref.read(postLoginStepProvider);

      // Splash, login, sign-up and password reset need no session.
      if (location == RouteName.splash ||
          location == RouteName.login ||
          location == RouteName.register ||
          location == RouteName.forgotPassword) {
        if (isAuthenticated && location != RouteName.splash) {
          return RouteName.dashboard;
        }
        return null;
      }

      if (!isAuthenticated) return RouteName.login;

      // A password-only session may not wander past the verification steps.
      if (step != PostLoginStep.done) {
        final target =
            step == PostLoginStep.otp ? RouteName.otp : RouteName.biometric;
        return location == target ? null : target;
      }

      // Verification finished — those screens are no longer revisitable.
      if (_verificationRoutes.contains(location)) return RouteName.dashboard;

      return null;
    },
    routes: [
      GoRoute(
        path: RouteName.splash,
        builder: (ctx, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteName.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteName.register,
        builder: (ctx, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteName.forgotPassword,
        builder: (ctx, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteName.otp,
        builder: (ctx, state) => const OtpScreen(),
      ),
      GoRoute(
        path: RouteName.biometric,
        builder: (ctx, state) => const BiometricScreen(),
      ),

      // ── Scan flow — above the shell so the nav bar stays hidden ──────────
      // Note: earning a stamp is now server-authoritative (ghelpdesk staff
      // scan the member's QR on the Stamps module's "Scan Customer" flow),
      // not an on-device action, so there's no local "claim succeeded"
      // screen to route to anymore — this member-facing screen just displays
      // the code (see scan_screen.dart's doc comment).
      GoRoute(
        path: RouteName.scan,
        builder: (ctx, state) => const ScanScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScreen(navigationShell: navigationShell),
        branches: [
          // ── Branch 0: Home ──────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.dashboard,
                builder: (ctx, state) => const HomeScreen(),
              ),
            ],
          ),

          // ── Branch 1: Rewards ───────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.campaigns,
                builder: (ctx, state) => const CampaignsScreen(),
              ),
            ],
          ),

          // ── Branch 2: History ───────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.ledger,
                builder: (ctx, state) => const LedgerScreen(),
              ),
            ],
          ),

          // ── Branch 3: Profile ───────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.profile,
                builder: (ctx, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'change-password',
                    builder: (ctx, state) => const ChangePasswordScreen(),
                  ),
                  GoRoute(
                    path: 'authenticator',
                    builder: (ctx, state) => const AuthenticatorSetupScreen(),
                  ),
                  GoRoute(
                    path: 'privacy-policy',
                    builder: (ctx, state) => const PrivacyPolicyScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

/// Notifies GoRouter when auth or verification state changes.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<PostLoginStep>(
        postLoginStepProvider, (_, __) => notifyListeners());
  }
}
