// Signing in has to survive an account being deleted on the server and signed
// up for again: same email, brand-new `users.id`. The local `users` table has
// `UNIQUE (username)`, and drift's `insertOnConflictUpdate` only resolves
// conflicts on the primary key — see `UserDao.upsertUserForLogin`.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bms/database/app_database.dart';
import 'package:bms/database/daos/user_dao.dart';

void main() {
  late AppDatabase db;
  late UserDao dao;

  const email = 'garudaperez45@gmail.com';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.userDao;
  });

  tearDown(() async => db.close());

  User member(String id, {String fullName = 'Gen', String username = email}) {
    final now = DateTime.utc(2026, 8, 28);
    return User(
      id: id,
      username: username,
      fullName: fullName,
      email: username,
      passwordHash: r'$2a$10$abcdefghijklmnopqrstuv',
      roleId: 'user',
      isActive: true,
      syncStatus: 0,
      isDeleted: false,
      failedLoginCount: 0,
      lastLoginAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<User>> allUsers() => db.select(db.users).get();

  test('a member re-registering after deletion replaces their local row',
      () async {
    await dao.upsertUserForLogin(member('101'));

    // Staff deleted the account in ghelpdesk; the member signs up again and the
    // server hands back a different id for the same email.
    final replaced = await dao.upsertUserForLogin(member('137', fullName: 'Gen M'));

    expect(replaced, '101');
    final rows = await allUsers();
    expect(rows, hasLength(1));
    expect(rows.single.id, '137');
    expect(rows.single.fullName, 'Gen M');
    expect(await dao.findByUsername(email), isNotNull);
  });

  test('signing in again with the same identity re-keys nothing', () async {
    await dao.upsertUserForLogin(member('101'));

    final replaced = await dao.upsertUserForLogin(member('101', fullName: 'Gen M'));

    expect(replaced, isNull);
    final rows = await allUsers();
    expect(rows, hasLength(1));
    expect(rows.single.id, '101');
    expect(rows.single.fullName, 'Gen M');
  });

  test('another member on the same device is left alone', () async {
    await dao.upsertUserForLogin(member('101'));

    final replaced =
        await dao.upsertUserForLogin(member('202', username: 'other@example.com'));

    expect(replaced, isNull);
    final rows = await allUsers();
    expect(rows, hasLength(2));
    expect(rows.map((u) => u.id), containsAll(['101', '202']));
  });

  test('a failed re-key leaves the previous row intact', () async {
    // A row already carrying the incoming id under a different login makes the
    // re-key impossible; the transaction must not half-apply.
    await dao.upsertUserForLogin(member('101'));
    await dao.upsertUserForLogin(member('137', username: 'other@example.com'));

    await expectLater(dao.upsertUserForLogin(member('137')), throwsA(anything));

    final rows = await allUsers();
    expect(rows, hasLength(2));
    expect((await dao.findByUsername(email))?.id, '101');
  });
}
