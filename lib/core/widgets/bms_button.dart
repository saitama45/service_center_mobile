import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

enum BmsButtonVariant { primary, secondary, danger, ghost }

class BmsButton extends StatelessWidget {
  const BmsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BmsButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BmsButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = _variantColors(variant);
    Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: colors.foreground),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: AppTextStyles.button.copyWith(color: colors.foreground)),
            ],
          );

    final button = SizedBox(
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          disabledBackgroundColor: colors.background.withValues(alpha: 0.6),
          elevation: variant == BmsButtonVariant.ghost ? 0 : 2,
          side: variant == BmsButtonVariant.secondary
              ? const BorderSide(color: AppColors.primaryBlue, width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: child,
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  _ButtonColors _variantColors(BmsButtonVariant v) {
    return switch (v) {
      BmsButtonVariant.primary =>
        _ButtonColors(AppColors.primaryBlue, AppColors.white),
      BmsButtonVariant.secondary =>
        _ButtonColors(AppColors.lightBlue, AppColors.primaryBlue),
      BmsButtonVariant.danger =>
        _ButtonColors(AppColors.danger, AppColors.white),
      BmsButtonVariant.ghost =>
        _ButtonColors(Colors.transparent, AppColors.primaryBlue),
    };
  }
}

class _ButtonColors {
  const _ButtonColors(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

