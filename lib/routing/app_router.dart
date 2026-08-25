import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/module_codes.dart';
import '../core/constants/permission_codes.dart';
import '../presentation/providers/auth_flow_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/permission_provider.dart';
import '../presentation/screens/audit_log/audit_log_screen.dart';
import '../presentation/screens/auth/authenticator_setup_screen.dart';
import '../presentation/screens/auth/biometric_screen.dart';
import '../presentation/screens/auth/otp_screen.dart';
import '../presentation/screens/campaigns/campaigns_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/ledger/ledger_screen.dart';
import '../presentation/screens/login/login_screen.dart';
import '../presentation/screens/login/register_screen.dart';
import '../presentation/screens/main_shell.dart';
import '../presentation/screens/profile/change_password_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/role_management/permission_matrix_screen.dart';
import '../presentation/screens/role_management/role_form_screen.dart';
import '../presentation/screens/role_management/role_list_screen.dart';
import '../presentation/screens/scan/scan_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/user_management/user_form_screen.dart';
import '../presentation/screens/user_management/user_list_screen.dart';
import 'route_names.dart';

// ── Route → module/permission guard mapping ──────────────────────────────────

const _routeGuards = <String, ({String module, String permission})>{
  '/dashboard/users': (module: ModuleCodes.userManagement, permission: PermissionCodes.view),
  '/dashboard/users/new': (module: ModuleCodes.userManagement, permission: PermissionCodes.create),
  '/dashboard/roles': (module: ModuleCodes.roleManagement, permission: PermissionCodes.view),
  '/dashboard/roles/new': (module: ModuleCodes.roleManagement, permission: PermissionCodes.create),
  '/dashboard/audit-log': (module: ModuleCodes.auditLog, permission: PermissionCodes.viewAuditLog),
};

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

      // Splash, login and sign-up need no session.
      if (location == RouteName.splash ||
          location == RouteName.login ||
          location == RouteName.register) {
        if (isAuthenticated &&
            (location == RouteName.login || location == RouteName.register)) {
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

      // Module-level permission guard (static routes)
      final guard = _routeGuards[location];
      if (guard != null) {
        final cache = ref.read(userPermissionsProvider).valueOrNull;
        if (cache != null && !cache.check(guard.module, guard.permission)) {
          return RouteName.dashboard;
        }
      }

      // Guard edit-user route: /dashboard/users/<id>  (not /users/new)
      if (RegExp(r'^/dashboard/users/[a-zA-Z0-9-]+$').hasMatch(location) &&
          !location.endsWith('/new')) {
        final cache = ref.read(userPermissionsProvider).valueOrNull;
        if (cache != null &&
            !cache.check(ModuleCodes.userManagement, PermissionCodes.edit)) {
          return RouteName.dashboard;
        }
      }

      // Guard edit-role route: /dashboard/roles/<id>  (not /roles/new)
      if (RegExp(r'^/dashboard/roles/[a-zA-Z0-9-]+$').hasMatch(location) &&
          !location.endsWith('/new')) {
        final cache = ref.read(userPermissionsProvider).valueOrNull;
        if (cache != null &&
            !cache.check(ModuleCodes.roleManagement, PermissionCodes.edit)) {
          return RouteName.dashboard;
        }
      }

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
          // ── Branch 0: Home (+ admin sub-routes) ─────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.dashboard,
                builder: (ctx, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'users',
                    builder: (ctx, state) => const UserListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (ctx, state) => const UserFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (ctx, state) => UserFormScreen(
                          userId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'roles',
                    builder: (ctx, state) => const RoleListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (ctx, state) => const RoleFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (ctx, state) => RoleFormScreen(
                          roleId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'permissions',
                            builder: (ctx, state) => PermissionMatrixScreen(
                              roleId: state.pathParameters['id']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'audit-log',
                    builder: (ctx, state) => const AuditLogScreen(),
                  ),
                ],
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
