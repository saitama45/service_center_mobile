/// Default permission matrix matching BMS_Database_Schema.md §role_module_permissions
///
/// Structure: role_code → module_code → [permission_codes granted]
///
/// ADMIN gets all permissions on all modules (handled by SeedRunner via loop).
/// Other roles were removed in this refactoring phase.
const Map<String, Map<String, List<String>>> defaultPermissionMatrix = {};
