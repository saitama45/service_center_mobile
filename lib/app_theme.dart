import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_dimensions.dart';
import 'core/constants/app_text_styles.dart';

/// The April 2026 brand book as a Material theme ("Option D: Craft"):
/// Creamy White pages, Roasted Black type and actions, Golden Caramel as
/// the single accent, Herb Display headlines and Booster Sans text.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.goldenCaramel,
    brightness: Brightness.light,
    primary: AppColors.roastedBlack,
    onPrimary: AppColors.creamyWhite,
    secondary: AppColors.goldenCaramel,
    onSecondary: AppColors.roastedBlack,
    tertiary: AppColors.purpleStraw,
    onTertiary: AppColors.creamyWhite,
    surface: AppColors.creamyWhite,
    onSurface: AppColors.roastedBlack,
    onSurfaceVariant: AppColors.ink2,
    surfaceContainerHighest: AppColors.californiaCream,
    error: AppColors.danger,
    onError: AppColors.creamyWhite,
    outline: AppColors.fieldLine,
    outlineVariant: AppColors.line,
  );

  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: AppTextStyles.body,
    scaffoldBackgroundColor: AppColors.creamyWhite,
    canvasColor: AppColors.creamyWhite,
    splashFactory: InkRipple.splashFactory,

    // App bars sit on the page itself: cream, Herb Display capitals.
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.creamyWhite,
      foregroundColor: AppColors.roastedBlack,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.appBarTitle,
      iconTheme: IconThemeData(color: AppColors.roastedBlack, size: 22),
      actionsIconTheme:
          IconThemeData(color: AppColors.roastedBlack, size: 22),
    ),

    // The primary action: a Roasted Black block.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.roastedBlack,
        foregroundColor: AppColors.creamyWhite,
        disabledBackgroundColor: AppColors.californiaCream,
        disabledForegroundColor: AppColors.ink3,
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.roastedBlack,
        backgroundColor: AppColors.creamyWhite,
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        textStyle: AppTextStyles.button,
        side: const BorderSide(color: AppColors.fieldLine),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
    ),

    // Text actions are ink, never caramel: caramel on cream is unreadable.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.roastedBlack,
        minimumSize: const Size(0, AppDimensions.minTouchTarget),
        textStyle: AppTextStyles.button,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.creamyWhite,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: outline(AppColors.fieldLine),
      enabledBorder: outline(AppColors.fieldLine),
      focusedBorder: outline(AppColors.roastedBlack, 2),
      errorBorder: outline(AppColors.danger),
      focusedErrorBorder: outline(AppColors.danger, 2),
      disabledBorder: outline(AppColors.line),
      labelStyle: AppTextStyles.label,
      floatingLabelStyle:
          AppTextStyles.label.copyWith(color: AppColors.roastedBlack),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink3),
      errorStyle: AppTextStyles.errorText,
      prefixIconColor: AppColors.ink3,
      suffixIconColor: AppColors.ink3,
    ),

    // Cards are outlined on the page, not lifted off it.
    cardTheme: CardThemeData(
      elevation: AppDimensions.cardElevation,
      color: AppColors.creamyWhite,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),

    chipTheme: ChipThemeData(
      labelStyle:
          AppTextStyles.chip.copyWith(color: AppColors.roastedBlack),
      backgroundColor: AppColors.creamyWhite,
      selectedColor: AppColors.roastedBlack,
      secondarySelectedColor: AppColors.roastedBlack,
      side: const BorderSide(color: AppColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.creamyWhite),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.roastedBlack
              : AppColors.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.roastedBlack
              : Colors.transparent),
      checkColor: WidgetStateProperty.all(AppColors.creamyWhite),
      side: const BorderSide(color: AppColors.fieldLine, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.roastedBlack
              : AppColors.ink3),
    ),

    // The member-code button: the one caramel object on the page.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.goldenCaramel,
      foregroundColor: AppColors.roastedBlack,
      shape: CircleBorder(),
      elevation: 6,
      focusElevation: 6,
      hoverElevation: 8,
      highlightElevation: 4,
    ),

    // Bottom navigation: a cream bar under a Roasted Black rule; the active
    // tab is a black pill with a cream icon.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.creamyWhite,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.roastedBlack,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.creamyWhite
              : AppColors.ink2,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppTextStyles.chip.copyWith(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.roastedBlack
              : AppColors.ink2,
        ),
      ),
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.creamyWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      width: 292,
    ),

    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 10,
      iconColor: AppColors.roastedBlack,
      textColor: AppColors.roastedBlack,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.creamyWhite,
      surfaceTintColor: Colors.transparent,
      barrierColor: AppColors.roastedBlack.withValues(alpha: 0.7),
      elevation: 0,
      titleTextStyle: AppTextStyles.h2,
      contentTextStyle: AppTextStyles.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.creamyWhite,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0xB3272323),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.roastedBlack,
      contentTextStyle:
          AppTextStyles.bodyMedium.copyWith(color: AppColors.creamyWhite),
      actionTextColor: AppColors.goldenCaramel,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.roastedBlack,
      unselectedLabelColor: AppColors.ink3,
      labelStyle: AppTextStyles.button,
      unselectedLabelStyle:
          AppTextStyles.button.copyWith(fontWeight: FontWeight.w400),
      indicatorColor: AppColors.roastedBlack,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.line,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.roastedBlack,
      linearTrackColor: AppColors.californiaCream,
      circularTrackColor: AppColors.californiaCream,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),

    iconTheme:
        const IconThemeData(color: AppColors.roastedBlack, size: 22),

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.roastedBlack,
      selectionColor: Color(0x55E5A944),
      selectionHandleColor: AppColors.roastedBlack,
    ),

    textTheme: const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      headlineSmall: AppTextStyles.h1,
      titleLarge: AppTextStyles.h1,
      titleMedium: AppTextStyles.h2,
      titleSmall: AppTextStyles.h3,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.caption,
    ),
  );
}
