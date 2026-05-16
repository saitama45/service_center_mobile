import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import 'permissions_seed.dart';
import 'modules_seed.dart' as mod_seed;
import 'roles_seed.dart';
import 'role_permissions_seed.dart';
import '../../core/utils/bcrypt_util.dart';

class SeedRunner {
  const SeedRunner(this._db);
  final AppDatabase _db;

  // Predictable System UUIDs
  static const adminRoleId = '00000000-0000-0000-0000-000000000001';

  /// Run seeding only if not already initialized.
  Future<void> runIfNeeded() async {
    try {
      final resetVersion = await _db.settingsDao.getSetting('arch_reset_v7');
      debugPrint('SeedRunner: Current reset version is "$resetVersion"');

      if (resetVersion != '10') {
        debugPrint('SeedRunner: Reset version mismatch (v10). Wiping database...');
        await _runReset();
        await _runSeeds();
        await _db.settingsDao.setSetting('arch_reset_v7', '10');
        debugPrint('SeedRunner: Database reset and seeded successfully.');
        return;
      }

      final initialized = await _db.settingsDao.isDbInitialized();
      debugPrint('SeedRunner: db_initialized setting is "$initialized"');
      if (!initialized) {
        debugPrint('SeedRunner: Database not initialized. Running seeds...');
        await _runSeeds();
        debugPrint('SeedRunner: Seeds finished.');
      }
    } catch (e, stack) {
      debugPrint('SeedRunner: CRITICAL ERROR: $e');
      debugPrint('SeedRunner: Stack trace: $stack');
    }
  }

  /// Wipes all core tables before re-seeding.
  Future<void> _runReset() async {
    final tables = [
      'role_module_permissions',
      'audit_logs',
      'sync_log',
      'app_settings',
      'users',
      'roles',
      'modules',
      'permissions'
    ];
    
    for(final table in tables) {
      try {
        await _db.customStatement('DELETE FROM $table');
      } catch (e) {
        debugPrint('SeedRunner: Warning - could not clear table $table: $e');
      }
    }
  }

  Future<void> _runSeeds() async {
    final uuid = const Uuid();

    // ── 1. Permissions ────────────────────────────────────────────────────
    debugPrint('SeedRunner: Seeding permissions...');
    final permissions = permissionsSeedData();
    for (final p in permissions) {
      // Use a predictable UUID based on the permission code
      final id = uuid.v5(Uuid.NAMESPACE_URL, 'perm_${p.code.value}');
      await _db.customStatement(
        'INSERT INTO permissions (id, code, name, category, description, display_order) VALUES (?, ?, ?, ?, ?, ?)',
        [
          id,
          p.code.value,
          p.name.value,
          p.category.value,
          p.description.present ? p.description.value : null,
          p.displayOrder.present ? p.displayOrder.value : 0
        ]
      );
    }

    // ── 2. Modules ────────────────────────────────────────────────────────
    debugPrint('SeedRunner: Seeding modules...');
    final seeds = mod_seed.modulesSeedData();
    final parentSeeds = seeds.where((s) => s.parentCode == null).toList();
    final childSeeds = seeds.where((s) => s.parentCode != null).toList();

    for (final s in parentSeeds) {
      final comp = mod_seed.toCompanion(s, null);
      final id = uuid.v5(Uuid.NAMESPACE_URL, 'mod_${comp.code.value}');
      await _db.customStatement(
        'INSERT INTO modules (id, code, name, parent_module_id, route, icon, display_order, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, comp.code.value, comp.name.value, null, comp.route.value, comp.icon.value, comp.displayOrder.value, 1]
      );
    }
    for (final s in childSeeds) {
      final parent = await _db.moduleDao.getModuleByCode(s.parentCode!);
      final comp = mod_seed.toCompanion(s, parent?.id);
      final id = uuid.v5(Uuid.NAMESPACE_URL, 'mod_${comp.code.value}');
      await _db.customStatement(
        'INSERT INTO modules (id, code, name, parent_module_id, route, icon, display_order, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, comp.code.value, comp.name.value, parent?.id, comp.route.value, comp.icon.value, comp.displayOrder.value, 1]
      );
    }

    // ── 3. Roles ──────────────────────────────────────────────────────────
    debugPrint('SeedRunner: Seeding roles...');
    for (final r in rolesSeedData()) {
      final roleId = r.code.value == 'ADMIN' 
          ? adminRoleId 
          : uuid.v5(Uuid.NAMESPACE_URL, 'role_${r.code.value}');
      await _db.customStatement(
        'INSERT INTO roles (id, code, name, description, is_system, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          roleId,
          r.code.value,
          r.name.value,
          r.description.present ? r.description.value : null,
          r.isSystem.value ? 1 : 0,
          r.isActive.value ? 1 : 0,
          DateTime.now().toUtc().toIso8601String(),
          DateTime.now().toUtc().toIso8601String()
        ]
      );
    }

    // ── 4. Default admin user ──────────────────────────────────────────────
    debugPrint('SeedRunner: Seeding admin user...');
    final passwordHash = BcryptUtil.hash('Admin@2026!');
    // Fixed ID for the admin user to prevent duplicates
    final adminUserId = uuid.v5(Uuid.NAMESPACE_URL, 'user_admin');
    // Explicitly provide failed_login_count and all mandatory columns
    await _db.customStatement(
      'INSERT INTO users (id, role_id, username, password_hash, full_name, is_active, failed_login_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        adminUserId,
        adminRoleId,
        'admin',
        passwordHash,
        'System Administrator',
        1,
        0,
        DateTime.now().toUtc().toIso8601String(),
        DateTime.now().toUtc().toIso8601String()
      ]
    );
    debugPrint('SeedRunner: Admin user created.');

    // ── 5. Permission matrix ──────────────────────────────────────────────
    debugPrint('SeedRunner: Seeding permission matrix...');
    final allModules = await _db.moduleDao.getAllModules(activeOnly: false);
    final allPerms = await _db.permissionDao.getAllPermissions();
    for (final m in allModules) {
      for (final p in allPerms) {
        // Predictable ID for the matrix entries
        final matrixId = uuid.v5(Uuid.NAMESPACE_URL, 'matrix_${adminRoleId}_${m.id}_${p.id}');
        await _db.customStatement(
          'INSERT INTO role_module_permissions (id, role_id, module_id, permission_id, is_granted, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            matrixId, 
            adminRoleId, 
            m.id, 
            p.id, 
            1,
            DateTime.now().toUtc().toIso8601String(),
            DateTime.now().toUtc().toIso8601String()
          ]
        );
      }
    }

    // ── 6. Finalize ───────────────────────────────────────────────────────
    await _db.settingsDao.setSetting('db_initialized', '1');
    await _db.settingsDao.setSetting('admin_password_changed', '0');
    debugPrint('SeedRunner: Initialization complete.');
  }
}
