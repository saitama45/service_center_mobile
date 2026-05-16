import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/module_codes.dart';
import '../core/constants/permission_codes.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/permission_provider.dart';
import '../presentation/screens/audit_log/audit_log_screen.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';
import '../presentation/screens/login/login_screen.dart';
import '../presentation/screens/main_shell.dart';
import '../presentation/screens/profile/change_password_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/role_management/permission_matrix_screen.dart';
import '../presentation/screens/role_management/role_form_screen.dart';
import '../presentation/screens/role_management/role_list_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/user_management/user_form_screen.dart';
import '../presentation/screens/user_management/user_list_screen.dart';
import '../presentation/screens/dtr/dtr_screen.dart';
import '../presentation/screens/attendance/attendance_screen.dart';
import 'route_names.dart';


// ── Route → module/permission guard mapping ──────────────────────────────────

const _routeGuards = <String, ({String module, String permission})>{
  '/dashboard/users': (module: ModuleCodes.userManagement, permission: PermissionCodes.view),
  '/dashboard/users/new': (module: ModuleCodes.userManagement, permission: PermissionCodes.create),
  '/dashboard/roles': (module: ModuleCodes.roleManagement, permission: PermissionCodes.view),
  '/dashboard/roles/new': (module: ModuleCodes.roleManagement, permission: PermissionCodes.create),
  '/dashboard/audit-log': (module: ModuleCodes.auditLog, permission: PermissionCodes.viewAuditLog),
};

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteName.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final location = state.matchedLocation;

      // Allow splash and login without auth
      if (location == RouteName.splash || location == RouteName.login) {
        if (isAuthenticated && location == RouteName.login) {
          return RouteName.dashboard;
        }
        return null;
      }

      // All other routes require authentication
      if (!isAuthenticated) {
        return RouteName.login;
      }

      // Module-level permission guard (static routes)
      final guard = _routeGuards[location];
      if (guard != null) {
        final cache = ref.read(userPermissionsProvider).valueOrNull;
        if (cache != null && !cache.check(guard.module, guard.permission)) {
          return RouteName.dashboard;
        }
      }

      // Guard edit-user route: /dashboard/users/<id>  (not /users/new)
      if (RegExp(r'^/dashboard/users/[a-zA-Z0-9-]+$').hasMatch(location) && !location.endsWith('/new')) {
        final cache = ref.read(userPermissionsProvider).valueOrNull;
        if (cache != null && !cache.check(ModuleCodes.userManagement, PermissionCodes.edit)) {
          return RouteName.dashboard;
        }
      }

      // Guard edit-role route: /dashboard/roles/<id>  (not /roles/new)
      if (RegExp(r'^/dashboard/roles/[a-zA-Z0-9-]+$').hasMatch(location) && !location.endsWith('/new')) {
        final cache = ref.read(userPermissionsProvider).valueOrNull;
        if (cache != null && !cache.check(ModuleCodes.roleManagement, PermissionCodes.edit)) {
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // ── Branch 0: Dashboard (Home) ─────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.dashboard,
                builder: (ctx, state) => const DashboardScreen(),
                routes: [
                  // ── User management ────────────────────────────────────────────
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
                        builder: (ctx, state) {
                          final id = state.pathParameters['id']!;
                          return UserFormScreen(userId: id);
                        },
                      ),
                    ],
                  ),
                  // ── Role management ────────────────────────────────────────────
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
                        builder: (ctx, state) {
                          final id = state.pathParameters['id']!;
                          return RoleFormScreen(roleId: id);
                        },
                        routes: [
                          GoRoute(
                            path: 'permissions',
                            builder: (ctx, state) {
                              final id = state.pathParameters['id']!;
                              return PermissionMatrixScreen(roleId: id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  // ── Audit log ──────────────────────────────────────────────────
                  GoRoute(
                    path: 'audit-log',
                    builder: (ctx, state) => const AuditLogScreen(),
                  ),
                  // ── DTR & Attendance ───────────────────────────────────────────
                  GoRoute(
                    path: 'dtr',
                    builder: (ctx, state) => const DtrScreen(),
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (ctx, state) => const AttendanceScreen(),
                  ),
                ],
              ),
            ],
          ),
          // ── Branch 1: Profile ──────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard/profile',
                builder: (ctx, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'change-password',
                    builder: (ctx, state) => const ChangePasswordScreen(),
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

/// Notifies GoRouter when auth state changes so it re-evaluates redirects.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}
