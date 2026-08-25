import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

enum BmsButtonVariant {
  /// Espresso fill — the single primary action on a screen.
  primary,

  /// White fill with a latte hairline — everything alongside the primary.
  secondary,

  /// Amber fill — reserved for reward / accent moments.
  accent,

  /// Tinted red — destructive actions.
  danger,

  /// No fill, amber label — inline / tertiary actions.
  ghost,
}

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
    final c = _variantColors(variant);

    final Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: c.foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: c.foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(color: c.foreground),
                ),
              ),
            ],
          );

    final button = SizedBox(
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.background,
          foregroundColor: c.foreground,
          disabledBackgroundColor: c.background == Colors.transparent
              ? Colors.transparent
              : AppColors.latte,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: c.border == null
              ? BorderSide.none
              : BorderSide(color: c.border!, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
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

  _ButtonColors _variantColors(BmsButtonVariant v) => switch (v) {
        BmsButtonVariant.primary =>
          const _ButtonColors(AppColors.espresso, AppColors.cream),
        BmsButtonVariant.secondary => const _ButtonColors(
            AppColors.white,
            AppColors.espresso,
            border: AppColors.latte,
          ),
        BmsButtonVariant.accent =>
          const _ButtonColors(AppColors.amber, AppColors.white),
        BmsButtonVariant.danger => const _ButtonColors(
            AppColors.dangerSurface,
            AppColors.danger,
            border: AppColors.dangerBorder,
          ),
        BmsButtonVariant.ghost =>
          const _ButtonColors(Colors.transparent, AppColors.amber),
      };
}

class _ButtonColors {
  const _ButtonColors(this.background, this.foreground, {this.border});
  final Color background;
  final Color foreground;
  final Color? border;
}
