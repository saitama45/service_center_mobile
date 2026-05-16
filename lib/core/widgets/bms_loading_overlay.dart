import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';

class BmsLoadingOverlay extends StatelessWidget {
  const BmsLoadingOverlay({super.key, this.message = AppStrings.loading});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/app_logo_v2.png',
                  height: 60,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: AppColors.primaryBlue),
                const SizedBox(height: 16),
                Text(message, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

