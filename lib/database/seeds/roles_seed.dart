import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

List<RolesCompanion> rolesSeedData() => [
  const RolesCompanion(
    code: Value('ADMIN'),
    name: Value('System Administrator'),
    description: Value(
        'Full system access. Manages users, roles, and system configuration.'),
    isSystem: Value(true),
    isActive: Value(true),
  ),
];
