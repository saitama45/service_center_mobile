import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// The standard surface of the app: white, softly rounded, hairline latte
/// border, no Material elevation. Everything that is not a hero sits in one.
class BmsCard extends StatelessWidget {
  const BmsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.md),
    this.margin,
    this.radius = AppDimensions.radiusLg,
    this.borderColor = AppColors.latte,
    this.color = AppColors.white,
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

  /// Adds the soft drop shadow. Use sparingly — the border alone is the default.
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
                splashColor: AppColors.latteLight,
                highlightColor: AppColors.latteLight.withValues(alpha: 0.5),
                child: content,
              ),
            ),
    );
  }
}

/// A [BmsCard] with a title row above its body — used for the grouped
/// "section" blocks that make up most detail screens.
class BmsSectionCard extends StatelessWidget {
  const BmsSectionCard({
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
    return BmsCard(
      margin: margin,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.caramel),
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

/// The signature dark gradient card. Reserved for the one hero element on a
/// screen — a stamp card in the mock, the clock/status panel here.
class BmsHeroCard extends StatelessWidget {
  const BmsHeroCard({
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
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: AppColors.heroShadow,
      ),
      child: child,
    );
  }
}

/// Small uppercase caption used above values inside cards.
class BmsFieldLabel extends StatelessWidget {
  const BmsFieldLabel(this.text, {super.key, this.color});

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

/// Rounded status pill — the badge vocabulary used across lists and tables.
class BmsStatusPill extends StatelessWidget {
  const BmsStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.showDot = false,
    this.icon,
  });

  /// Convenience constructors for the three states used most often.
  factory BmsStatusPill.success(String label, {bool showDot = true}) =>
      BmsStatusPill(
        label: label,
        color: AppColors.success,
        background: AppColors.successSurface,
        showDot: showDot,
      );

  factory BmsStatusPill.danger(String label, {bool showDot = true}) =>
      BmsStatusPill(
        label: label,
        color: AppColors.danger,
        background: AppColors.dangerSurface,
        showDot: showDot,
      );

  factory BmsStatusPill.neutral(String label) => BmsStatusPill(
        label: label,
        color: AppColors.caramel,
        background: AppColors.latteLight,
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
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

/// Horizontal progress bar with the amber accent gradient.
class BmsProgressBar extends StatelessWidget {
  const BmsProgressBar({
    super.key,
    required this.value,
    this.height = 7,
    this.trackColor = AppColors.latte,
    this.gradient,
  });

  /// 0.0 – 1.0
  final double value;
  final double height;
  final Color trackColor;
  final Gradient? gradient;

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
                gradient: gradient ?? AppColors.accentGradient,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
