import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'presentation/providers/force_update_provider.dart';
import 'routing/app_router.dart';

class CbtlApp extends ConsumerStatefulWidget {
  const CbtlApp({super.key});

  @override
  ConsumerState<CbtlApp> createState() => _CbtlAppState();
}

class _CbtlAppState extends ConsumerState<CbtlApp> {
  // Splash checks the store for a newer build on launch. This repeats the check
  // whenever the app returns to the foreground, for a member who left it open
  // while a release went out.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(forceUpdateProvider.notifier).check(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CBTL',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildAppTheme(),
    );
  }
}
