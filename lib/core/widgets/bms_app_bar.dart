import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Branded AppBar consistent with TAS Service Center design system.
class BmsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BmsAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.backgroundColor = AppColors.primaryBlue,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color backgroundColor;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: AppColors.white,
      elevation: 2,
      leading: leading,
      centerTitle: centerTitle,
      bottom: bottom,
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.appBarTitle),
                Text(subtitle!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.white)),
              ],
            )
          : Text(title, style: AppTextStyles.appBarTitle),
      actions: actions,
    );
  }
}

