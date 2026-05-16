import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  static const Duration sessionDuration = Duration(hours: 12);

  Future<int> createSession({
    required String userId,
    required String tokenHash,
    String? deviceInfo,
  }) {
    return into(sessions).insert(
      SessionsCompanion.insert(
        userId: userId,
        tokenHash: tokenHash,
        deviceInfo: Value(deviceInfo),
        expiresAt: DateTime.now().toUtc().add(sessionDuration),
      ),
    );
  }

  /// Returns session if valid (not expired, not invalidated).
  Future<Session?> findValidSession(String tokenHash) {
    return (select(sessions)
          ..where((s) =>
              s.tokenHash.equals(tokenHash) &
              s.expiresAt.isBiggerThanValue(DateTime.now().toUtc()) &
              s.invalidatedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> invalidateSession(String tokenHash) async {
    await (update(sessions)..where((s) => s.tokenHash.equals(tokenHash)))
        .write(SessionsCompanion(
      invalidatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  Future<void> invalidateAllUserSessions(String userId) async {
    await (update(sessions)..where((s) => s.userId.equals(userId))).write(
      SessionsCompanion(
        invalidatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
