import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

/// Returns modules in order: parents first, then children.
/// parent_module_id is resolved by code in SeedRunner after parent insert.
List<_ModuleSeed> modulesSeedData() => [
  // ── Top-level ─────────────────────────────────────────────────────────────
  _ModuleSeed('USER_MANAGEMENT', 'User Management', null, '/users', 'manage_accounts', 11),
  _ModuleSeed('ROLE_MANAGEMENT', 'Role Management', null, '/roles', 'admin_panel_settings', 12),
  _ModuleSeed('AUDIT_LOG', 'Audit Log', null, '/audit-log', 'history', 14),
];

class _ModuleSeed {
  const _ModuleSeed(
    this.code,
    this.name,
    this.parentCode,
    this.route,
    this.icon,
    this.order,
  );
  final String code;
  final String name;
  final String? parentCode;
  final String route;
  final String icon;
  final int order;
}

ModulesCompanion toCompanion(_ModuleSeed s, String? parentId) {
  return ModulesCompanion(
    code: Value(s.code),
    name: Value(s.name),
    parentModuleId: Value(parentId),
    route: Value(s.route),
    icon: Value(s.icon),
    displayOrder: Value(s.order),
    isActive: const Value(true),
  );
}
