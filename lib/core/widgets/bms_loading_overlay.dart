import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';

class BmsLoadingOverlay extends StatelessWidget {
  const BmsLoadingOverlay({super.key, this.message = AppStrings.loading});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Espresso scrim rather than neutral black — keeps the warmth.
      color: AppColors.espresso.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opaque square mark — clipped to a rounded tile, not padded.
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/app_logo.jpg',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: AppColors.amber,
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
