import 'package:connectivity_plus/connectivity_plus.dart';
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

final dtrRepositoryProvider = Provider<DtrRepository>((ref) {
  return DtrRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiClientProvider),
  );
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager(
    ref.read(appDatabaseProvider),
    ref.read(apiClientProvider),
    ref.read(dtrRepositoryProvider),
  );
});

final seedRunnerProvider = Provider<SeedRunner>((ref) {
  return SeedRunner(ref.read(appDatabaseProvider));
});

/// Live connectivity stream. Emits `true` when offline (no network),
/// `false` when at least one transport is available.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  final initial = await conn.checkConnectivity();
  var wasOffline = _isOffline(initial);
  yield wasOffline;

  await for (final result in conn.onConnectivityChanged) {
    final isOffline = _isOffline(result);
    if (wasOffline && !isOffline) {
      ref.read(dtrRepositoryProvider).refreshOfflineBootstrap();
      ref.read(syncManagerProvider).sync();
    }
    wasOffline = isOffline;
    yield isOffline;
  }
});

bool _isOffline(List<ConnectivityResult> results) {
  if (results.isEmpty) return true;
  return results.every((r) => r == ConnectivityResult.none);
}

/// All active modules ordered by displayOrder.
/// Used by AppDrawer (sidebar) and PermissionMatrixScreen to stay in sync
/// with whatever is seeded — no hardcoding required.
final activeModulesProvider = FutureProvider<List<Module>>((ref) {
  final db = ref.read(appDatabaseProvider);
  return db.moduleDao.getAllModules(activeOnly: true);
});
