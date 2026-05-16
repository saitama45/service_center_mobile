import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'bms_button.dart';

/// Shows a confirmation dialog. Returns true if user confirmed, false otherwise.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = AppStrings.yes,
  String cancelLabel = AppStrings.cancel,
  BmsButtonVariant confirmVariant = BmsButtonVariant.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppTextStyles.h2),
      content: Text(message, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel,
              style: AppTextStyles.button
                  .copyWith(color: AppColors.mediumGray)),
        ),
        BmsButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
          variant: confirmVariant,
        ),
      ],
    ),
  );
  return result ?? false;
}
