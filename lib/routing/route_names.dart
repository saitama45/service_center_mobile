abstract class RouteName {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String biometric = '/biometric';

  /// Member home — branch 0 of the shell.
  static const String dashboard = '/dashboard';

  // ── Loyalty ────────────────────────────────────────────────────────────────
  static const String campaigns = '/dashboard/campaigns';
  static const String ledger = '/dashboard/ledger';

  /// Pushed above the shell so the bottom nav is hidden while scanning.
  static const String scan = '/scan';

  // ── Admin ──────────────────────────────────────────────────────────────────
  static const String users = '/users';
  static const String userNew = '/users/new';
  static const String userDetail = '/users/:id';

  static const String roles = '/roles';
  static const String roleNew = '/roles/new';
  static const String roleEdit = '/roles/:id';
  static const String rolePermissions = '/roles/:id/permissions';

  static const String auditLog = '/audit-log';

  // ── Profile ────────────────────────────────────────────────────────────────
  static const String profile = '/dashboard/profile';
  static const String changePassword = '/profile/change-password';

  // Phase 2 placeholder
  static const String comingSoon = '/coming-soon';
}
