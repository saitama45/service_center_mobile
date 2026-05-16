/// Machine-readable permission codes — must match seeds/permissions_seed.dart
abstract class PermissionCodes {
  // DATA
  static const String view = 'VIEW';
  static const String create = 'CREATE';
  static const String edit = 'EDIT';
  static const String delete = 'DELETE';

  // ACTION
  static const String export = 'EXPORT';
  static const String print = 'PRINT';
  static const String import = 'IMPORT';
  static const String generateReport = 'GENERATE_REPORT';

  // WORKFLOW
  static const String approve = 'APPROVE';
  static const String reject = 'REJECT';
  static const String cancel = 'CANCEL';
  static const String submit = 'SUBMIT';
  static const String restore = 'RESTORE';
  static const String assign = 'ASSIGN';

  // SYSTEM
  static const String sync = 'SYNC';
  static const String backup = 'BACKUP';
  static const String manageUsers = 'MANAGE_USERS';
  static const String manageRoles = 'MANAGE_ROLES';
  static const String viewAuditLog = 'VIEW_AUDIT_LOG';

  static const List<String> all = [
    view, create, edit, delete,
    export, print, import, generateReport,
    approve, reject, cancel, submit, restore, assign,
    sync, backup, manageUsers, manageRoles, viewAuditLog,
  ];
}
