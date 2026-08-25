import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_dimensions.dart';
import 'core/constants/app_text_styles.dart';
import 'routing/app_router.dart';

class BmsApp extends ConsumerWidget {
  const BmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TAS Service Center (SC)',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _buildTheme(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.amber,
      brightness: Brightness.light,
      primary: AppColors.espresso,
      onPrimary: AppColors.cream,
      secondary: AppColors.amber,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.espresso,
      error: AppColors.danger,
      onError: AppColors.white,
      outline: AppColors.latte,
    );

    // The border every card, input and grouped container shares.
    OutlineInputBorder outline(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: AppTextStyles.body,
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      splashFactory: InkSparkle.splashFactory,

      // AppBar — espresso surface, serif title.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.espresso,
        foregroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBarTitle,
        iconTheme: IconThemeData(color: AppColors.cream, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.cream, size: 22),
      ),

      // Elevated buttons — flat espresso pills.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.espresso,
          foregroundColor: AppColors.cream,
          disabledBackgroundColor: AppColors.latte,
          disabledForegroundColor: AppColors.muted,
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
          foregroundColor: AppColors.espresso,
          backgroundColor: AppColors.white,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          textStyle: AppTextStyles.button,
          side: const BorderSide(color: AppColors.latte, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),

      // Text buttons carry the amber accent.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.amber,
          minimumSize: const Size(0, AppDimensions.minTouchTarget),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Input fields — cream fill, latte border, amber focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: outline(AppColors.latte),
        enabledBorder: outline(AppColors.latte),
        focusedBorder: outline(AppColors.amber, 2),
        errorBorder: outline(AppColors.danger),
        focusedErrorBorder: outline(AppColors.danger, 2),
        disabledBorder: outline(AppColors.latteLight),
        labelStyle: AppTextStyles.label,
        floatingLabelStyle:
            AppTextStyles.label.copyWith(color: AppColors.amber),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
        errorStyle: AppTextStyles.errorText,
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),

      // Cards — white on cream, hairline border instead of a shadow.
      cardTheme: CardThemeData(
        elevation: AppDimensions.cardElevation,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: const BorderSide(color: AppColors.latte),
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        labelStyle: AppTextStyles.chip.copyWith(color: AppColors.caramel),
        backgroundColor: AppColors.latteLight,
        selectedColor: AppColors.espresso,
        secondarySelectedColor: AppColors.espresso,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.white
                : AppColors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.amber
                : AppColors.latte),
        trackOutlineColor:
            WidgetStateProperty.all(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.amber
                : Colors.transparent),
        checkColor: WidgetStateProperty.all(AppColors.white),
        side: const BorderSide(color: AppColors.latte, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm / 1.5),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.amber
                : AppColors.muted),
      ),

      // FAB — amber, the one loud element on the page.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        highlightElevation: 4,
      ),

      // Bottom navigation.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.latteLight,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppColors.amber
                : AppColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? AppColors.amber
                : AppColors.muted,
          ),
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        width: 292,
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        iconColor: AppColors.caramel,
        textColor: AppColors.espresso,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.h2,
        contentTextStyle: AppTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.espresso,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.cream),
        actionTextColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.espresso,
        unselectedLabelColor: AppColors.muted,
        labelStyle: AppTextStyles.button,
        unselectedLabelStyle:
            AppTextStyles.button.copyWith(fontWeight: FontWeight.w500),
        indicatorColor: AppColors.amber,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.latte,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
        linearTrackColor: AppColors.latte,
        circularTrackColor: AppColors.latteLight,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.latteLight,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: AppColors.caramel, size: 22),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.amber,
        selectionColor: Color(0x33C4781A),
        selectionHandleColor: AppColors.amber,
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
}
