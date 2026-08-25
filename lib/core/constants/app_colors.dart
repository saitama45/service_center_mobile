import 'package:flutter/material.dart';

/// Application colour palette — "BrewPass" warm espresso/cream design language.
///
/// The palette is organised in three tiers:
///   1. Brand ramp    — espresso → cream, the spine of the whole UI.
///   2. Semantic      — success / warning / danger / info.
///   3. Legacy aliases— the old blue/gray names, remapped onto the ramp so
///                      existing screens pick up the new look automatically.
class AppColors {
  AppColors._();

  // ── Brand ramp (dark → light) ────────────────────────────────────────────
  /// Darkest surface. App bars, sidebars, primary buttons, headline text.
  static const Color espresso = Color(0xFF1A0A02);

  /// Gradient partner for [brown] on hero cards.
  static const Color darkBrown = Color(0xFF2D1507);

  /// Mid-dark surface — avatars, gradient tail.
  static const Color brown = Color(0xFF4A2210);

  /// Secondary accent — progress bar tails, chart series 2.
  static const Color caramel = Color(0xFF7D3E1B);

  /// Primary accent. Active states, FABs, selected nav, progress fills.
  static const Color amber = Color(0xFFC4781A);

  /// Highlight accent — tier badges, big numerals on dark surfaces.
  static const Color gold = Color(0xFFDBA842);

  /// Hairline borders, track backgrounds, disabled marks.
  static const Color latte = Color(0xFFEDD9B7);

  /// Tinted fills — icon chips, table headers, subtle surfaces.
  static const Color latteLight = Color(0xFFF5EDD9);

  /// The default page background.
  static const Color cream = Color(0xFFFAF6EF);

  /// Secondary text, inactive icons, captions.
  static const Color muted = Color(0xFF9C8070);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF3A8A5C);
  static const Color warning = Color(0xFFD68910);
  static const Color danger = Color(0xFFC0392B);
  static const Color info = Color(0xFF7D3E1B);

  /// Tinted backgrounds for semantic banners / chips.
  static const Color successSurface = Color(0xFFEDF9F0);
  static const Color dangerSurface = Color(0xFFFFF0F0);
  static const Color dangerBorder = Color(0xFFFFCCCC);

  // ── Neutral ──────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = espresso;

  // ── Legacy aliases ───────────────────────────────────────────────────────
  // Kept so screens written against the previous palette restyle themselves.
  // Prefer the ramp names above in new code.
  static const Color primaryBlack = espresso;
  static const Color primaryBlue = espresso; // primary brand surface
  static const Color primaryDarkBlue = darkBrown;
  static const Color secondaryBlue = amber; // interactive / link accent
  static const Color lightBlue = latteLight; // tinted fill
  static const Color accentBlue = caramel;

  static const Color darkGray = espresso; // primary text
  static const Color mediumGray = muted; // secondary text
  static const Color lightGray = cream; // page background
  static const Color borderGray = latte; // hairline border

  // ── Permission badges ────────────────────────────────────────────────────
  static const Color granted = amber;
  static const Color denied = muted;

  // ── Inspection status ────────────────────────────────────────────────────
  static const Color statusCompleted = success;
  static const Color statusOngoing = warning;
  static const Color statusNotStarted = danger;

  // ── BNR condition colours ────────────────────────────────────────────────
  static const Color conditionGood = Color(0xFF3A8A5C);
  static const Color conditionFair = Color(0xFF7D9B3A);
  static const Color conditionPoor = Color(0xFFDBA842);
  static const Color conditionVeryPoor = Color(0xFFC4781A);
  static const Color conditionCritical = Color(0xFFC0392B);

  // ── Composite decorations ────────────────────────────────────────────────
  /// The signature dark card gradient used on hero surfaces.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBrown, brown],
  );

  /// Accent gradient for progress fills and the FAB.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [caramel, amber],
  );

  /// Soft drop shadow used by raised cards.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: espresso.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Pronounced shadow for hero cards sitting on cream.
  static List<BoxShadow> get heroShadow => [
        BoxShadow(
          color: espresso.withValues(alpha: 0.28),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
      ];
}
