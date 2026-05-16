abstract class RouteName {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  // User management
  static const String users = '/users';
  static const String userNew = '/users/new';
  static const String userDetail = '/users/:id';

  // Role management
  static const String roles = '/roles';
  static const String roleNew = '/roles/new';
  static const String roleEdit = '/roles/:id';
  static const String rolePermissions = '/roles/:id/permissions';

  // Profile
  static const String profile = '/profile';
  static const String changePassword = '/profile/change-password';

  // DTR & Attendance
  static const String dtr = '/dtr';
  static const String attendance = '/attendance';

  // Audit
  static const String auditLog = '/audit-log';

  // Phase 2 placeholder
  static const String comingSoon = '/coming-soon';
}
