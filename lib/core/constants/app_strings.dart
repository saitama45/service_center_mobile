/// All user-visible strings in one place for easy localization later
abstract class AppStrings {
  // App identity
  /// The brand's proper name always carries the leading article — splash and
  /// sign-in both show it this way.
  static const String appName = 'The Coffee Bean & Tea Leaf';

  /// Same as [appName]; kept for the Home header's existing reference.
  static const String appNameFull = appName;

  // Auth
  static const String loginTitle = 'Sign In';
  static const String password = 'Password';
  static const String signIn = 'Sign In';
  static const String signOut = 'Sign Out';
  static const String invalidCredentials = 'Invalid email or password.';
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

  // Navigation
  static const String dashboard = 'Dashboard';
  static const String profile = 'My Profile';

  // Account
  static const String fullName = 'Full Name';
  static const String email = 'Email';
  static const String lastLogin = 'Last Login';
  static const String resetPassword = 'Reset Password';

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
  static const String errorGeneric = 'An unexpected error occurred. Please try again.';
}
