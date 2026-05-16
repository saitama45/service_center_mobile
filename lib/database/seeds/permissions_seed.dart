import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

List<PermissionsCompanion> permissionsSeedData() => [
  // ── DATA permissions ──────────────────────────────────────────────────────
  const PermissionsCompanion(
    code: Value('VIEW'), name: Value('View'),
    category: Value('DATA'),
    description: Value('See/read records and data'),
    displayOrder: Value(1),
  ),
  const PermissionsCompanion(
    code: Value('CREATE'), name: Value('Create'),
    category: Value('DATA'),
    description: Value('Add new records'),
    displayOrder: Value(2),
  ),
  const PermissionsCompanion(
    code: Value('EDIT'), name: Value('Edit'),
    category: Value('DATA'),
    description: Value('Modify existing records'),
    displayOrder: Value(3),
  ),
  const PermissionsCompanion(
    code: Value('DELETE'), name: Value('Delete'),
    category: Value('DATA'),
    description: Value('Delete or soft-delete records'),
    displayOrder: Value(4),
  ),

  // ── ACTION permissions ────────────────────────────────────────────────────
  const PermissionsCompanion(
    code: Value('EXPORT'), name: Value('Export'),
    category: Value('ACTION'),
    description: Value('Export data as BIC files or file packages'),
    displayOrder: Value(10),
  ),
  const PermissionsCompanion(
    code: Value('PRINT'), name: Value('Print'),
    category: Value('ACTION'),
    description: Value('Generate and print inspection forms'),
    displayOrder: Value(11),
  ),
  const PermissionsCompanion(
    code: Value('IMPORT'), name: Value('Import'),
    category: Value('ACTION'),
    description: Value('Import reference data or BIC files'),
    displayOrder: Value(12),
  ),
  const PermissionsCompanion(
    code: Value('GENERATE_REPORT'), name: Value('Generate Report'),
    category: Value('ACTION'),
    description: Value('Generate summary or analytical reports'),
    displayOrder: Value(13),
  ),

  // ── WORKFLOW permissions ──────────────────────────────────────────────────
  const PermissionsCompanion(
    code: Value('APPROVE'), name: Value('Approve'),
    category: Value('WORKFLOW'),
    description: Value('Approve submitted inspection records'),
    displayOrder: Value(20),
  ),
  const PermissionsCompanion(
    code: Value('REJECT'), name: Value('Reject'),
    category: Value('WORKFLOW'),
    description: Value('Reject and return records for revision'),
    displayOrder: Value(21),
  ),
  const PermissionsCompanion(
    code: Value('CANCEL'), name: Value('Cancel'),
    category: Value('WORKFLOW'),
    description: Value('Cancel an active inspection or survey'),
    displayOrder: Value(22),
  ),
  const PermissionsCompanion(
    code: Value('SUBMIT'), name: Value('Submit'),
    category: Value('WORKFLOW'),
    description: Value('Submit a completed record for review'),
    displayOrder: Value(23),
  ),
  const PermissionsCompanion(
    code: Value('RESTORE'), name: Value('Restore'),
    category: Value('WORKFLOW'),
    description: Value('Restore a soft-deleted record'),
    displayOrder: Value(24),
  ),
  const PermissionsCompanion(
    code: Value('ASSIGN'), name: Value('Assign'),
    category: Value('WORKFLOW'),
    description: Value('Assign bridges or tasks to inspectors'),
    displayOrder: Value(25),
  ),

  // ── SYSTEM permissions ────────────────────────────────────────────────────
  const PermissionsCompanion(
    code: Value('SYNC'), name: Value('Sync'),
    category: Value('SYSTEM'),
    description: Value('Trigger data sync with central BMS server'),
    displayOrder: Value(30),
  ),
  const PermissionsCompanion(
    code: Value('BACKUP'), name: Value('Backup'),
    category: Value('SYSTEM'),
    description: Value('Create or restore local database backups'),
    displayOrder: Value(31),
  ),
  const PermissionsCompanion(
    code: Value('MANAGE_USERS'), name: Value('Manage Users'),
    category: Value('SYSTEM'),
    description: Value('Create, edit, and deactivate user accounts'),
    displayOrder: Value(32),
  ),
  const PermissionsCompanion(
    code: Value('MANAGE_ROLES'), name: Value('Manage Roles'),
    category: Value('SYSTEM'),
    description: Value('Create and configure roles and permissions'),
    displayOrder: Value(33),
  ),
  const PermissionsCompanion(
    code: Value('VIEW_AUDIT_LOG'), name: Value('View Audit Log'),
    category: Value('SYSTEM'),
    description: Value('Access the audit/activity log'),
    displayOrder: Value(35),
  ),
];
