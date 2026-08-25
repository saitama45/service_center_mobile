import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

class BmsEmptyState extends StatelessWidget {
  const BmsEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tinted round chip instead of a bare grey glyph.
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.latteLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.caramel),
            ),
            const SizedBox(height: AppDimensions.md),
            if (title != null) ...[
              Text(title!, style: AppTextStyles.h2, textAlign: TextAlign.center),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppDimensions.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
