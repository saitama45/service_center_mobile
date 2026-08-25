/// All user-visible strings in one place for easy localization later
abstract class AppStrings {
  // App identity
  static const String appName = 'Coffee Bean & Tea Leaf';
  static const String appFullName = 'TAS Service Center';
  static const String organizationShort = 'TAS';

  // Auth
  static const String loginTitle = 'Sign In';
  static const String username = 'Username';
  static const String password = 'Password';
  static const String signIn = 'Sign In';
  static const String signOut = 'Sign Out';
  static const String invalidCredentials = 'Invalid username or password.';
  static const String accountDisabled = 'This account has been deactivated. Contact your administrator.';
  static const String accountLocked = 'Account locked. Try again after';
  static const String attemptsRemaining = 'attempts remaining before lockout.';
  static const String passwordChanged = 'Password changed successfully.';
  static const String changePassword = 'Change Password';
  static const String currentPassword = 'Current Password';
  static const String newPassword = 'New Password';
  static const String confirmPassword = 'Confirm New Password';
  static const String passwordMismatch = 'Passwords do not match.';
  static const String passwordTooWeak =
      'Password must be at least 8 characters with 1 uppercase, 1 number, and 1 special character.';
  static const String forcePasswordChange =
      'You must change the default administrator password before continuing.';

  // Navigation
  static const String dashboard = 'Dashboard';
  static const String userManagement = 'User Management';
  static const String roleManagement = 'Role Management';
  static const String auditLog = 'Audit Log';
  static const String profile = 'My Profile';

  // User management
  static const String users = 'Users';
  static const String addUser = 'Add User';
  static const String editUser = 'Edit User';
  static const String fullName = 'Full Name';
  static const String email = 'Email';
  static const String employeeId = 'ID Number';
  static const String lastLogin = 'Last Login';
  static const String role = 'Role';
  static const String deo = 'District Engineering Office';
  static const String activeStatus = 'Active';
  static const String deactivateUser = 'Deactivate User';
  static const String deactivateConfirm =
      'Are you sure you want to deactivate this user? They will no longer be able to log in.';
  static const String resetPassword = 'Reset Password';

  // Role management
  static const String roles = 'Roles';
  static const String addRole = 'Add Role';
  static const String editRole = 'Edit Role';
  static const String roleCode = 'Role Code';
  static const String roleDescription = 'Description';
  static const String systemRole = 'System Role';
  static const String permissionMatrix = 'Permission Matrix';
  static const String grantAll = 'Grant All';
  static const String denyAll = 'Deny All';
  static const String savePermissions = 'Save Permissions';
  static const String permissionsSaved = 'Permissions updated successfully.';
  static const String cannotDeleteSystemRole =
      'System roles cannot be deleted.';
  static const String cannotDeactivateRoleWithUsers =
      'Cannot deactivate a role that has active users assigned.';

  // Audit log
  static const String noAuditLogs = 'No audit log entries found.';

  // General
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String confirm = 'Confirm';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String loading = 'Loading…';
  static const String noData = 'No data found.';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String all = 'All';
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String comingSoon = 'This module is coming in Phase 2.';
  static const String accessDenied = 'You do not have permission to access this module.';
  static const String errorGeneric = 'An unexpected error occurred. Please try again.';
  static const String granted = 'Granted';
  static const String denied = 'Denied';
  static const String source = 'Source';
  static const String sourceRole = 'Role';
  static const String myPermissions = 'My Effective Permissions';
  static const String module = 'Module';
  static const String permission = 'Permission';
}
