import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../brand/brand_widgets.dart';

class CbtlEmptyState extends StatelessWidget {
  const CbtlEmptyState({
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
            // The brand's own bean and leaf (p37), drawn large, in place of
            // a generic glyph.
            const BrandMark.motif(width: 132, color: AppColors.roastedBlack),
            const SizedBox(height: AppDimensions.md),
            if (title != null) ...[
              Text(AppTextStyles.caps(title!),
                  style: AppTextStyles.h2, textAlign: TextAlign.center),
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
