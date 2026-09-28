import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cbtl/database/app_database.dart';
import 'package:cbtl/database/seeds/seed_runner.dart';

/// The bootstrap `admin` login is gone.
///
/// Before v8, SeedRunner created `admin` with a fixed password on every
/// install. With the phone offline it signed in through LoginUseCase's local
/// fallback and opened the RBAC admin console — a hidden feature in a member
/// app (App Store Guideline 2.3.1). New installs no longer seed it, and the v8
/// migration removes it from devices that already have it.
///
/// Runs against NativeDatabase.memory(), never a developer database.
void main() {
  Future<void> insertUser(AppDatabase db, String id, String username) {
    final now = DateTime.now().toUtc().toIso8601String();
    return db.customStatement(
      'INSERT INTO users (id, role_id, username, password_hash, full_name, '
      'is_active, failed_login_count, last_login_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, 1, 0, ?, ?, ?)',
      [id, 'user', username, 'hash', username, now, now, now],
    );
  }

  test('v8 removes the seeded admin and its sessions, and no one else',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final adminId = AppDatabase.legacySeededAdminId;
    await insertUser(db, adminId, 'admin');
    await insertUser(db, '42', 'member@example.test');
    await db.sessionDao.createSession(userId: adminId, tokenHash: 'admin-token');
    await db.sessionDao.createSession(userId: '42', tokenHash: 'member-token');

    // Run just the upgrade step the released build will run on a v7 device.
    await db.migration.onUpgrade(Migrator(db), 7, 8);

    final users = await db.select(db.users).get();
    expect(users.map((u) => u.username), ['member@example.test'],
        reason: 'only the seeded admin may be removed');

    // A device signed in as admin must not be able to resume that session.
    expect(await db.sessionDao.findValidSession('admin-token'), isNull);
    expect(await db.sessionDao.findValidSession('member-token'), isNotNull,
        reason: "a member's own session must survive the upgrade");
  });

  test('a fresh install seeds no login at all', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await SeedRunner(db).runIfNeeded();

    // SeedRunner swallows its own errors, so prove it actually ran before
    // reading anything into an empty users table.
    expect(await db.settingsDao.isDbInitialized(), isTrue);
    expect(await db.select(db.roles).get(), isNotEmpty);

    expect(await db.select(db.users).get(), isEmpty);
  });
}
