import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography from the April 2026 brand book (p31-35).
///
/// Three faces, each with one job:
///   • [display] — CBTL Herb Display, for headlines and big numbers. It has
///     no lowercase letters, so every string set in it must be passed through
///     `.toUpperCase()`; a lowercase letter would fall back to another font.
///     Leading 90%, tracking 0, one to three lines.
///   • [body]    — Booster Sans, everything you read. Tracking 2%, leading
///     160% for running text. Semibold only for short emphasis.
///   • [mono]    — Booster Sans Narrow ("Body Copy Tall"), for chips, codes
///     and timestamps where width is tight.
class AppTextStyles {
  AppTextStyles._();

  static const String display = 'CBTLHerbDisplay';
  static const String body = 'BoosterSans';
  static const String mono = 'BoosterSansNarrow';

  /// Herb Display has no lowercase. Use for every string set in a display
  /// style (displayLarge/Medium, h1, h2, appBarTitle, statValue).
  static String caps(String text) => text.toUpperCase();

  // ── Display / Hero text (Herb Display, capitals) ──────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 52,
    fontWeight: FontWeight.w900,
    color: AppColors.roastedBlack,
    height: 0.9,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: display,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.roastedBlack,
    height: 0.92,
  );

  // ── Headings ──────────────────────────────────────────────────────────────
  /// Screen titles. Herb Display, capitals.
  static const TextStyle h1 = TextStyle(
    fontFamily: display,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.roastedBlack,
    height: 0.92,
  );

  /// Section and dialog titles. Herb Display, capitals.
  static const TextStyle h2 = TextStyle(
    fontFamily: display,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: AppColors.roastedBlack,
    height: 0.95,
  );

  /// Labels inside cards — Booster Semibold, below [h2] in the hierarchy.
  static const TextStyle h3 = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.roastedBlack,
    letterSpacing: 0.3,
    height: 1.4,
  );

  // ── Body (Booster Sans, 2% tracking) ──────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.roastedBlack,
    letterSpacing: 0.3,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.roastedBlack,
    letterSpacing: 0.28,
    height: 1.55,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink2,
    letterSpacing: 0.25,
    height: 1.55,
  );

  // ── Button ────────────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  // ── Label / Caption ───────────────────────────────────────────────────────
  /// Field labels — small, uppercase, wide-tracked. Pass uppercase text.
  static const TextStyle label = TextStyle(
    fontFamily: body,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink2,
    letterSpacing: 1.2,
  );

  /// The book's caption: Booster 12, tracking 2%, leading 160% (p35).
  static const TextStyle caption = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.ink3,
    letterSpacing: 0.24,
    height: 1.6,
  );

  // ── Specialised ───────────────────────────────────────────────────────────
  /// App bar titles sit on cream, in Herb Display capitals.
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: display,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: AppColors.roastedBlack,
    height: 0.95,
  );

  static const TextStyle appBarSubtitle = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink2,
    letterSpacing: 0.25,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.26,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.danger,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static const TextStyle tableHeader = TextStyle(
    fontFamily: body,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink3,
    letterSpacing: 1.2,
  );

  static const TextStyle tableCell = TextStyle(
    fontFamily: body,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.roastedBlack,
    letterSpacing: 0.26,
  );

  // ── Codes and figures (Booster Sans Narrow) ───────────────────────────────
  /// Record IDs, timestamps — anything that should stay compact.
  static const TextStyle monoSmall = TextStyle(
    fontFamily: mono,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink3,
    letterSpacing: 0.4,
  );

  /// Codes a cashier may have to type, so every character must be distinct.
  static const TextStyle monoMedium = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.roastedBlack,
    letterSpacing: 0.5,
  );

  /// Big figures that may hold letters — counters, keys.
  static const TextStyle monoLarge = TextStyle(
    fontFamily: mono,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.roastedBlack,
    letterSpacing: 0.4,
  );

  /// Hero statistic on a card — Herb Display numerals.
  static const TextStyle statValue = TextStyle(
    fontFamily: display,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    color: AppColors.roastedBlack,
    height: 0.9,
  );
}
