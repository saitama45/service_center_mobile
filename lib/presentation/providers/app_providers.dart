import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../database/app_database.dart';
import '../../database/seeds/seed_runner.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../core/sync/sync_manager.dart';
import '../../data/repositories/dtr_repository.dart';

// ── Singleton providers ───────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager(
    ref.read(appDatabaseProvider),
    ref.read(apiClientProvider),
  );
});

final dtrRepositoryProvider = Provider<DtrRepository>((ref) {
  return DtrRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiClientProvider),
  );
});

final seedRunnerProvider = Provider<SeedRunner>((ref) {
  return SeedRunner(ref.read(appDatabaseProvider));
});

/// All active modules ordered by displayOrder.
/// Used by AppDrawer (sidebar) and PermissionMatrixScreen to stay in sync
/// with whatever is seeded — no hardcoding required.
final activeModulesProvider = FutureProvider<List<Module>>((ref) {
  final db = ref.read(appDatabaseProvider);
  return db.moduleDao.getAllModules(activeOnly: true);
});
