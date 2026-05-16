import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/permission_cache.dart';
import '../../domain/usecases/permission/resolve_permission_usecase.dart';
import 'app_providers.dart';

// ── Use case provider ─────────────────────────────────────────────────────────

final resolvePermissionUseCaseProvider =
    Provider<ResolvePermissionUseCase>((ref) {
  return ResolvePermissionUseCase(ref.read(appDatabaseProvider));
});

// ── Permission cache provider ─────────────────────────────────────────────────
//
// This is the ONLY place in the app that resolves permissions.
// All screens read from this provider via PermissionGate or ref.watch().
//
// CRITICAL: Invalidate this provider after any permission matrix update
// or user override change:
//   ref.invalidate(userPermissionsProvider)

final userPermissionsProvider =
    FutureProvider<PermissionCache>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final storage = ref.read(secureStorageProvider);

  final rawToken = await storage.read(key: 'session_token');
  if (rawToken == null) return PermissionCache.empty();

  final tokenHash = _hashToken(rawToken);
  final session = await db.sessionDao.findValidSession(tokenHash);
  if (session == null) return PermissionCache.empty();

  return ref
      .read(resolvePermissionUseCaseProvider)
      .call(session.userId);
});

/// SHA-256 hash of the raw session token — mirrors TokenUtil.hashToken.
String _hashToken(String rawToken) {
  final bytes = utf8.encode(rawToken);
  return sha256.convert(bytes).toString();
}
