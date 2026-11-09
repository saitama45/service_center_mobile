import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/brand/brand_widgets.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../../core/widgets/cbtl_button.dart';
import '../../providers/force_update_provider.dart';

/// Shown instead of the whole app while a newer build is waiting on the store.
/// There is deliberately no way past it: the router holds every route here
/// until the store stops reporting an update.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeUrl = ref.watch(forceUpdateProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Arrives from the dark splash, which left the status-bar icons light.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 136),
                  const SizedBox(height: AppDimensions.xl),
                  Text(
                    AppTextStyles.caps('Update required'),
                    style: AppTextStyles.h1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  const Text(
                    'A new version of CBTL is available. Please update to '
                    'continue using the app.',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.xl),
                  CbtlButton(
                    label: 'Update Now',
                    isFullWidth: true,
                    onPressed: storeUrl == null
                        ? null
                        : () => openExternalUrl(
                              context,
                              Uri.parse(storeUrl),
                              preferApp: true,
                            ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  const AppVersionText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
