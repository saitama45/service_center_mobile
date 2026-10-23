// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_matrix_dao.dart';

// ignore_for_file: type=lint
mixin _$PermissionMatrixDaoMixin on DatabaseAccessor<AppDatabase> {
  $RolesTable get roles => attachedDatabase.roles;
  $ModulesTable get modules => attachedDatabase.modules;
  $PermissionsTable get permissions => attachedDatabase.permissions;
  $UsersTable get users => attachedDatabase.users;
  $RoleModulePermissionsTable get roleModulePermissions =>
      attachedDatabase.roleModulePermissions;
  PermissionMatrixDaoManager get managers => PermissionMatrixDaoManager(this);
}

class PermissionMatrixDaoManager {
  final _$PermissionMatrixDaoMixin _db;
  PermissionMatrixDaoManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$ModulesTableTableManager get modules =>
      $$ModulesTableTableManager(_db.attachedDatabase, _db.modules);
  $$PermissionsTableTableManager get permissions =>
      $$PermissionsTableTableManager(_db.attachedDatabase, _db.permissions);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$RoleModulePermissionsTableTableManager get roleModulePermissions =>
      $$RoleModulePermissionsTableTableManager(
          _db.attachedDatabase, _db.roleModulePermissions);
}
