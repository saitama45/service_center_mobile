import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import '../brand/brand_widgets.dart';

class CbtlLoadingOverlay extends StatelessWidget {
  const CbtlLoadingOverlay({super.key, this.message = AppStrings.loading});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.roastedBlack.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.creamyWhite,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 56),
              const SizedBox(height: 22),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: AppColors.roastedBlack,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(message, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
