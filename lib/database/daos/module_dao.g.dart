// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'module_dao.dart';

// ignore_for_file: type=lint
mixin _$ModuleDaoMixin on DatabaseAccessor<AppDatabase> {
  $ModulesTable get modules => attachedDatabase.modules;
  ModuleDaoManager get managers => ModuleDaoManager(this);
}

class ModuleDaoManager {
  final _$ModuleDaoMixin _db;
  ModuleDaoManager(this._db);
  $$ModulesTableTableManager get modules =>
      $$ModulesTableTableManager(_db.attachedDatabase, _db.modules);
}
