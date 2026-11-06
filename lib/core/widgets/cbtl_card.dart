import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// The standard surface of the app: outlined on the cream page with a
/// hairline, never lifted off it. Everything that is not a hero sits in one.
class CbtlCard extends StatelessWidget {
  const CbtlCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.md),
    this.margin,
    this.radius = AppDimensions.radiusLg,
    this.borderColor = AppColors.line,
    this.color = AppColors.creamyWhite,
    this.onTap,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color borderColor;
  final Color color;
  final VoidCallback? onTap;

  /// Kept for older call sites. The brand is flat, so it no longer lifts.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: raised ? AppColors.cardShadow : null,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                splashColor: AppColors.californiaCream,
                highlightColor:
                    AppColors.californiaCream.withValues(alpha: 0.5),
                child: content,
              ),
            ),
    );
  }
}

/// A [CbtlCard] with a title row above its body — used for the grouped
/// "section" blocks that make up most detail screens.
class CbtlSectionCard extends StatelessWidget {
  const CbtlSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.margin,
    this.padding = const EdgeInsets.all(AppDimensions.md),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CbtlCard(
      margin: margin,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.roastedBlack),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(title, style: AppTextStyles.h3)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppDimensions.md - 2),
          child,
        ],
      ),
    );
  }
}

/// The Roasted Black card. Reserved for the one hero element on a screen,
/// such as the stamp card or the member's identity on Profile.
class CbtlHeroCard extends StatelessWidget {
  const CbtlHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.md + 2),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.roastedBlack,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: child,
    );
  }
}

/// Small uppercase caption used above values inside cards.
class CbtlFieldLabel extends StatelessWidget {
  const CbtlFieldLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: color == null
            ? AppTextStyles.label
            : AppTextStyles.label.copyWith(color: color),
      );
}

/// Status tag — squared like the crate stamps in the brand book (p37).
class CbtlStatusPill extends StatelessWidget {
  const CbtlStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.showDot = false,
    this.icon,
  });

  /// Convenience constructors for the three states used most often.
  factory CbtlStatusPill.success(String label, {bool showDot = true}) =>
      CbtlStatusPill(
        label: label,
        color: AppColors.success,
        background: AppColors.successSurface,
        showDot: showDot,
      );

  factory CbtlStatusPill.danger(String label, {bool showDot = true}) =>
      CbtlStatusPill(
        label: label,
        color: AppColors.danger,
        background: AppColors.dangerSurface,
        showDot: showDot,
      );

  factory CbtlStatusPill.neutral(String label) => CbtlStatusPill(
        label: label,
        color: AppColors.roastedBlack,
        background: AppColors.californiaCream,
      );

  final String label;
  final Color color;
  final Color? background;
  final bool showDot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(label, style: AppTextStyles.chip.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Horizontal progress bar: Roasted Black on California Cream, or Golden
/// Caramel ([color]) when a reward is ready.
class CbtlProgressBar extends StatelessWidget {
  const CbtlProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.trackColor = AppColors.californiaCream,
    this.gradient,
    this.color = AppColors.roastedBlack,
  });

  /// 0.0 – 1.0
  final double value;
  final double height;
  final Color trackColor;
  final Gradient? gradient;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: trackColor),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: gradient == null ? color : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
