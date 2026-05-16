import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/permission_provider.dart';

/// Conditionally renders [child] if the user has [permissionCode] on [moduleCode].
/// Renders [fallback] (default: empty box) when denied or loading.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.moduleCode,
    required this.permissionCode,
    required this.child,
    this.fallback,
  });

  final String moduleCode;
  final String permissionCode;
  final Widget child;

  /// Widget to show when permission is denied. Defaults to [SizedBox.shrink].
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(userPermissionsProvider);
    return permissionsAsync.when(
      data: (cache) {
        final granted = cache.check(moduleCode, permissionCode);
        return granted ? child : (fallback ?? const SizedBox.shrink());
      },
      loading: () => fallback ?? const SizedBox.shrink(),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
    );
  }
}
