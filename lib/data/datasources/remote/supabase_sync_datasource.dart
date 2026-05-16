import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 1 stub — wires Supabase client and checks connectivity.
/// Phase 2 will activate actual upload/download flows here.
class SupabaseSyncDatasource {
  const SupabaseSyncDatasource();

  SupabaseClient get _client => Supabase.instance.client;

  /// Returns true if device has network connectivity.
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Phase 1: no-op stub. Logs intent, returns immediately.
  /// Phase 2: Will upload pending local rows to Supabase.
  Future<void> uploadPendingRecords() async {
    final online = await isOnline();
    if (!online) return;
    // TODO(Phase 2): Query sync_status='PENDING' rows and upsert to Supabase.
  }

  /// Phase 1: no-op stub.
  /// Phase 2: Will pull updated reference data (permissions, modules, roles) from Supabase.
  Future<void> downloadReferenceData() async {
    final online = await isOnline();
    if (!online) return;
    // TODO(Phase 2): Pull rows newer than local updated_at and merge.
  }

  /// Check if the user's Supabase session is valid.
  bool get isAuthenticated => _client.auth.currentSession != null;
}
