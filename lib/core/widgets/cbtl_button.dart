import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

enum CbtlButtonVariant {
  /// Roasted Black block — the single primary action on a screen.
  primary,

  /// Cream with an ink outline — everything alongside the primary.
  secondary,

  /// Golden Caramel — reserved for reward / accent moments.
  accent,

  /// Tinted red — destructive actions.
  danger,

  /// No fill, underlined ink — inline / tertiary actions.
  ghost,
}

class CbtlButton extends StatelessWidget {
  const CbtlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CbtlButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final CbtlButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final c = _variantColors(variant);
    final ghost = variant == CbtlButtonVariant.ghost;
    // The label sets its own colour, so a disabled button must say so here or
    // it keeps the enabled colour (cream on cream for primary). A loading
    // button is disabled too, so its spinner needs the same.
    final disabled = onPressed == null || isLoading;
    final fg = disabled ? AppColors.ink3 : c.foreground;

    final Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: fg,
                    decoration: ghost ? TextDecoration.underline : null,
                    decorationColor: fg,
                  ),
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
              : AppColors.californiaCream,
          disabledForegroundColor: AppColors.ink3,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: c.border == null
              ? BorderSide.none
              : BorderSide(color: c.border!),
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

  _ButtonColors _variantColors(CbtlButtonVariant v) => switch (v) {
        CbtlButtonVariant.primary =>
          const _ButtonColors(AppColors.roastedBlack, AppColors.creamyWhite),
        CbtlButtonVariant.secondary => const _ButtonColors(
            AppColors.creamyWhite,
            AppColors.roastedBlack,
            border: AppColors.fieldLine,
          ),
        // Caramel carries ink, not white: white on caramel reads at 1.8:1.
        CbtlButtonVariant.accent =>
          const _ButtonColors(AppColors.goldenCaramel, AppColors.roastedBlack),
        CbtlButtonVariant.danger => const _ButtonColors(
            AppColors.dangerSurface,
            AppColors.danger,
            border: AppColors.dangerBorder,
          ),
        CbtlButtonVariant.ghost =>
          const _ButtonColors(Colors.transparent, AppColors.roastedBlack),
      };
}

class _ButtonColors {
  const _ButtonColors(this.background, this.foreground, {this.border});
  final Color background;
  final Color foreground;
  final Color? border;
}
