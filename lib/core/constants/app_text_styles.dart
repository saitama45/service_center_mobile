import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography for the "BrewPass" design language.
///
/// Three typefaces, each with one job:
///   • [display] — Playfair Display, a serif reserved for headings and hero
///     numerals. It is what makes the app read as premium rather than generic.
///   • [body]    — DM Sans, everything else.
///   • [mono]    — DM Mono, for figures that need to line up: IDs, timestamps,
///     counters, coordinates.
class AppTextStyles {
  AppTextStyles._();

  static const String display = 'PlayfairDisplay';
  static const String body = 'DMSans';
  static const String mono = 'DMMono';

  // ── Display / Hero text ───────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    letterSpacing: -0.4,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: display,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.2,
  );

  // ── Headings ──────────────────────────────────────────────────────────────
  /// Screen titles. Serif — the signature of the design.
  static const TextStyle h1 = TextStyle(
    fontFamily: display,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.25,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: display,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.3,
  );

  /// Section labels inside cards — sans, so it sits below [h2] in the hierarchy.
  static const TextStyle h3 = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.35,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.espresso,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: body,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.espresso,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
    height: 1.4,
  );

  // ── Button ────────────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  // ── Label / Caption ───────────────────────────────────────────────────────
  /// Field labels — small, uppercase, wide-tracked. Straight from the mock.
  static const TextStyle label = TextStyle(
    fontFamily: body,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
    letterSpacing: 0.9,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
    height: 1.4,
  );

  // ── Specialised ───────────────────────────────────────────────────────────
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: display,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.cream,
    letterSpacing: 0.2,
  );

  static const TextStyle appBarSubtitle = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.latte,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.danger,
    height: 1.4,
  );

  static const TextStyle tableHeader = TextStyle(
    fontFamily: body,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.muted,
    letterSpacing: 0.8,
  );

  static const TextStyle tableCell = TextStyle(
    fontFamily: body,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.espresso,
  );

  // ── Monospace ─────────────────────────────────────────────────────────────
  /// Record IDs, timestamps, coordinates — anything that should align.
  static const TextStyle monoSmall = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle monoMedium = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.espresso,
  );

  /// Big figures — clock readouts, counters, KPI values.
  static const TextStyle monoLarge = TextStyle(
    fontFamily: mono,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.espresso,
    letterSpacing: -0.5,
  );

  /// Hero statistic on a card — serif, heavy.
  static const TextStyle statValue = TextStyle(
    fontFamily: display,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.1,
  );
}
