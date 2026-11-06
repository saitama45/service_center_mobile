import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/utils/app_update_checker.dart';
import 'app_theme.dart';
import 'routing/app_router.dart';

class CbtlApp extends ConsumerStatefulWidget {
  const CbtlApp({super.key});

  @override
  ConsumerState<CbtlApp> createState() => _CbtlAppState();
}

class _CbtlAppState extends ConsumerState<CbtlApp> {
  // Checks Play for a newer build on launch and whenever the app returns to
  // the foreground, so members pick up a release without being told to.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: AppUpdateChecker.check);
    AppUpdateChecker.check();
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
