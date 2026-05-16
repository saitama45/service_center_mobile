import '../../database/daos/permission_matrix_dao.dart';

/// In-memory cache of all resolved permissions for the active user.
/// Key: 'MODULE_CODE:PERMISSION_CODE' → bool (isGranted)
class PermissionCache {
  const PermissionCache._(this._cache, this._sources);
  factory PermissionCache.empty() =>
      const PermissionCache._({}, {});

  factory PermissionCache.fromResolved(List<ResolvedPermission> resolved) {
    final cache = <String, bool>{};
    final sources = <String, String>{};
    for (final r in resolved) {
      final key = '${r.moduleCode}:${r.permissionCode}';
      if (!cache.containsKey(key)) {
        cache[key] = r.isGranted;
        sources[key] = r.source;
      }
    }
    return PermissionCache._(cache, sources);
  }

  final Map<String, bool> _cache;
  final Map<String, String> _sources;

  /// Returns true if the user has [permissionCode] on [moduleCode].
  bool check(String moduleCode, String permissionCode) {
    return _cache['$moduleCode:$permissionCode'] ?? false;
  }

  /// Returns the source for a permission: 'override', 'role', or 'default'.
  String source(String moduleCode, String permissionCode) {
    return _sources['$moduleCode:$permissionCode'] ?? 'default';
  }

  /// Returns all moduleCode:permissionCode entries for display.
  Map<String, bool> get all => Map.unmodifiable(_cache);

  bool get isEmpty => _cache.isEmpty;
}
