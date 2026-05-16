import 'package:flutter_test/flutter_test.dart';
import 'package:bms/domain/entities/permission_cache.dart';
import 'package:bms/database/daos/permission_matrix_dao.dart';

void main() {
  group('PermissionCache', () {
    test('check returns true when permission is granted', () {
      final cache = PermissionCache.fromResolved([
        const ResolvedPermission(
          moduleCode: 'INVENTORY',
          permissionCode: 'VIEW',
          isGranted: true,
          source: 'role',
        ),
      ]);
      expect(cache.check('INVENTORY', 'VIEW'), isTrue);
    });

    test('check returns false when permission is explicitly denied', () {
      final cache = PermissionCache.fromResolved([
        const ResolvedPermission(
          moduleCode: 'INVENTORY',
          permissionCode: 'DELETE',
          isGranted: false,
          source: 'role',
        ),
      ]);
      expect(cache.check('INVENTORY', 'DELETE'), isFalse);
    });

    test('check returns false by default (no row = denied)', () {
      final cache = PermissionCache.fromResolved([]);
      expect(cache.check('CONDITION', 'CREATE'), isFalse);
    });

    test('override takes precedence over role when both present', () {
      // Override grants; role denies — override wins
      final cache = PermissionCache.fromResolved([
        const ResolvedPermission(
          moduleCode: 'EXPORT_BIC',
          permissionCode: 'EXPORT',
          isGranted: true,
          source: 'override', // override → first in list
        ),
        const ResolvedPermission(
          moduleCode: 'EXPORT_BIC',
          permissionCode: 'EXPORT',
          isGranted: false,
          source: 'role', // this should be ignored since override exists
        ),
      ]);
      // fromResolved uses the FIRST entry for a given key (override comes first)
      expect(cache.check('EXPORT_BIC', 'EXPORT'), isTrue);
    });

    test('source is correctly recorded', () {
      final cache = PermissionCache.fromResolved([
        const ResolvedPermission(
          moduleCode: 'AUDIT_LOG',
          permissionCode: 'VIEW_AUDIT_LOG',
          isGranted: true,
          source: 'override',
        ),
      ]);
      expect(cache.source('AUDIT_LOG', 'VIEW_AUDIT_LOG'), equals('override'));
    });

    test('empty cache returns empty for all checks', () {
      final cache = PermissionCache.empty();
      expect(cache.isEmpty, isTrue);
      expect(cache.check('ANY_MODULE', 'VIEW'), isFalse);
    });
  });
}
