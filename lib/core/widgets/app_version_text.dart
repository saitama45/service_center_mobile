import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/app_providers.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// The installed app version, e.g. "Version 1.0.1 (5)". Renders nothing until
/// the platform answers, and nothing if it can't.
class AppVersionText extends ConsumerWidget {
  const AppVersionText({super.key, this.color = AppColors.muted});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    if (version == null) return const SizedBox.shrink();
    return Text(
      version,
      style: AppTextStyles.caption.copyWith(color: color),
      textAlign: TextAlign.center,
    );
  }
}
