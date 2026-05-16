import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'audit_log_dao.g.dart';

@DriftAccessor(tables: [AuditLogs])
class AuditLogDao extends DatabaseAccessor<AppDatabase>
    with _$AuditLogDaoMixin {
  AuditLogDao(super.db);

  Future<int> insertLog(AuditLogsCompanion companion) =>
      into(auditLogs).insert(companion);

  /// Convenience: inserts a log entry and resolves [moduleCode] to a moduleId.
  Future<int> logAction({
    String? userId,
    required String moduleCode,
    String? actionDetail,
    String? targetTable,
    String? targetId,
  }) async {
    final module =
        await attachedDatabase.moduleDao.getModuleByCode(moduleCode);
    return insertLog(AuditLogsCompanion.insert(
      userId: Value(userId),
      moduleId: Value(module?.id),
      actionDetail: Value(actionDetail),
      targetTable: Value(targetTable),
      targetId: Value(targetId),
    ));
  }

  Future<int> countLogs({
    String? userId,
    String? moduleId,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
  }) async {
    final query = select(auditLogs);
    if (userId != null) query.where((l) => l.userId.equals(userId));
    if (moduleId != null) query.where((l) => l.moduleId.equals(moduleId));
    if (fromDate != null) {
      query.where((l) => l.createdAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query.where((l) => l.createdAt.isSmallerOrEqualValue(toDate));
    }
    if (search != null && search.isNotEmpty) {
      query.where((l) => l.actionDetail.like('%$search%'));
    }
    final rows = await query.get();
    return rows.length;
  }

  Future<List<AuditLog>> getLogs({
    String? userId,
    String? moduleId,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(auditLogs);
    if (userId != null) query.where((l) => l.userId.equals(userId));
    if (moduleId != null) query.where((l) => l.moduleId.equals(moduleId));
    if (fromDate != null) {
      query.where((l) => l.createdAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query.where((l) => l.createdAt.isSmallerOrEqualValue(toDate));
    }
    if (search != null && search.isNotEmpty) {
      query.where((l) => l.actionDetail.like('%$search%'));
    }
    query
      ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
      ..limit(limit, offset: offset);
    return query.get();
  }
}
