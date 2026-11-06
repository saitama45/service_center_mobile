import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Branded AppBar — sits on the cream page, title in Herb Display capitals.
/// A dark [backgroundColor] flips the title and icons to Creamy White.
class CbtlAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CbtlAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.backgroundColor = AppColors.creamyWhite,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color backgroundColor;
  final PreferredSizeWidget? bottom;

  double get _toolbarHeight => subtitle != null ? 78 : 64;

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final onDark = backgroundColor.computeLuminance() < 0.3;
    final ink = onDark ? AppColors.creamyWhite : AppColors.roastedBlack;
    // One line at the approved size; a long title shrinks rather than clips.
    final titleText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment:
          centerTitle ? Alignment.center : AlignmentDirectional.centerStart,
      child: Text(
        AppTextStyles.caps(title),
        style: AppTextStyles.appBarTitle.copyWith(color: ink),
        maxLines: 1,
      ),
    );

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: _toolbarHeight,
      systemOverlayStyle:
          onDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: leading,
      centerTitle: centerTitle,
      bottom: bottom,
      title: subtitle != null
          ? Column(
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleText,
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTextStyles.appBarSubtitle.copyWith(
                      color: onDark
                          ? AppColors.californiaCream
                          : AppColors.ink2),
                ),
              ],
            )
          : titleText,
      actions: actions,
    );
  }
}
