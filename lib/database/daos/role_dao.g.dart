// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_dao.dart';

// ignore_for_file: type=lint
mixin _$RoleDaoMixin on DatabaseAccessor<AppDatabase> {
  $RolesTable get roles => attachedDatabase.roles;
  RoleDaoManager get managers => RoleDaoManager(this);
}

class RoleDaoManager {
  final _$RoleDaoMixin _db;
  RoleDaoManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
}
