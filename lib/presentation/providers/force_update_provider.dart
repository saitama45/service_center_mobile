import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_update_checker.dart';

/// Where the update answer comes from; tests replace this because the stores
/// only answer for a real store install.
final storeUpdateLookupProvider = Provider<Future<String?> Function()>(
  (ref) => AppUpdateChecker.findUpdate,
);

/// The store page this install must update from, or null when it may be used.
/// The router sends every route to the update screen while this is set.
final forceUpdateProvider =
    StateNotifierProvider<ForceUpdateNotifier, String?>((ref) {
  return ForceUpdateNotifier(ref.read(storeUpdateLookupProvider));
});

class ForceUpdateNotifier extends StateNotifier<String?> {
  ForceUpdateNotifier(this._lookup) : super(null);

  final Future<String?> Function() _lookup;
  Future<void>? _running;

  /// Never throws. A check that fails leaves the state as it was, so a member
  /// with no signal still opens the app (the member QR must work offline, and
  /// they could not download an update anyway), while one already blocked is
  /// not let through by a dropped connection.
  Future<void> check() =>
      _running ??= _ask().whenComplete(() => _running = null);

  Future<void> _ask() async {
    try {
      final storeUrl = await _lookup();
      if (mounted) state = storeUrl;
    } catch (e) {
      debugPrint('Update check skipped: $e');
    }
  }
}
