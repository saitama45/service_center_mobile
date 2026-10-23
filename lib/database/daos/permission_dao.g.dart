// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_dao.dart';

// ignore_for_file: type=lint
mixin _$PermissionDaoMixin on DatabaseAccessor<AppDatabase> {
  $PermissionsTable get permissions => attachedDatabase.permissions;
  PermissionDaoManager get managers => PermissionDaoManager(this);
}

class PermissionDaoManager {
  final _$PermissionDaoMixin _db;
  PermissionDaoManager(this._db);
  $$PermissionsTableTableManager get permissions =>
      $$PermissionsTableTableManager(_db.attachedDatabase, _db.permissions);
}
