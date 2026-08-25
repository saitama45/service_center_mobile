import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../database/app_database.dart';
import '../../database/seeds/seed_runner.dart';
import '../../data/datasources/local/member_qr_cache.dart';
import '../../data/datasources/local/totp_secret_store.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../data/datasources/remote/loyalty_member_remote_datasource.dart';
import '../../data/datasources/remote/otp_remote_datasource.dart';
import '../../core/sync/sync_manager.dart';

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

final otpRemoteDatasourceProvider = Provider<OtpRemoteDatasource>((ref) {
  return OtpRemoteDatasource(ref.read(apiClientProvider));
});

final totpSecretStoreProvider = Provider<TotpSecretStore>((ref) {
  return TotpSecretStore(ref.read(secureStorageProvider));
});

final loyaltyMemberRemoteDatasourceProvider =
    Provider<LoyaltyMemberRemoteDatasource>((ref) {
  return LoyaltyMemberRemoteDatasource(ref.read(apiClientProvider));
});

final memberQrCacheProvider = Provider<MemberQrCache>((ref) {
  return MemberQrCache(ref.read(secureStorageProvider));
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager(
    ref.read(appDatabaseProvider),
    ref.read(apiClientProvider),
    onCatalogUpdated: () => ref.read(loyaltyRevisionProvider.notifier).state++,
  );
});

/// Bumped after every loyalty write (`LoyaltyActions`) or successful catalog
/// pull (`SyncManager`) so the derived providers in loyalty_provider.dart
/// refetch. Lives here rather than in loyalty_provider.dart so both that
/// file and this one can reach it without a circular import — SyncManager
/// itself stays Riverpod-free; app_providers.dart is what's actually wired
/// to it.
final loyaltyRevisionProvider = StateProvider<int>((ref) => 0);

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
