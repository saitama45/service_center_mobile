import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_tables.dart';

part 'module_dao.g.dart';

@DriftAccessor(tables: [Modules])
class ModuleDao extends DatabaseAccessor<AppDatabase> with _$ModuleDaoMixin {
  ModuleDao(super.db);

  Future<List<Module>> getAllModules({bool activeOnly = true}) {
    final query = select(modules);
    if (activeOnly) query.where((m) => m.isActive.equals(true));
    query.orderBy([(m) => OrderingTerm.asc(m.displayOrder)]);
    return query.get();
  }

  Future<Module?> getModuleByCode(String code) =>
      (select(modules)..where((m) => m.code.equals(code))).getSingleOrNull();

  Future<int> insertModule(ModulesCompanion companion) =>
      into(modules).insert(companion);
}
