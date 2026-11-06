import 'package:flutter/material.dart';

/// Application colour palette — the April 2026 brand book (p29), applied as
/// "Option D: Craft".
///
/// The rules the book sets, which every screen follows:
///   • Roasted Black and Creamy White are the base. Keep a layout to one base
///     plus one accent; the accent is Golden Caramel.
///   • Purple is used sparingly, for key brand moments only, and never as a
///     default background.
///
/// The palette is organised in three tiers:
///   1. Brand       — the book's seven colours, by their book names.
///   2. Roles       — ink, lines and semantic states built from them.
///   3. Ramp aliases— the previous "BrewPass" names, remapped onto the brand so
///                    screens written against them keep working. Prefer the
///                    brand and role names in new code.
class AppColors {
  AppColors._();

  // ── Brand (p29) ──────────────────────────────────────────────────────────
  /// The base. Text, primary buttons, the stamp card, the logo disc.
  static const Color roastedBlack = Color(0xFF272323);

  /// The base. Page background, and text on Roasted Black.
  static const Color creamyWhite = Color(0xFFFAEFE6);

  /// Warmth: tinted panels, stat tiles, tracks.
  static const Color californiaCream = Color(0xFFF2DECD);

  /// The one accent: Holiday stamps, progress, the member-code button.
  /// Never for text on cream — it reads at 1.8:1 there.
  static const Color goldenCaramel = Color(0xFFE5A944);

  /// The accent's darker partner, for edges on caramel.
  static const Color toastedCaramel = Color(0xFFC79445);

  /// Key moments only: the Purple Aura and the squiggle under a headline.
  /// Not for small text: Roasted Black on it reads at 4.47:1.
  static const Color purplePop = Color(0xFFB468E4);

  /// Key moments that carry text, such as "Reward unlocked". Creamy White on
  /// it reads at 9.4:1.
  static const Color purpleStraw = Color(0xFF532D6D);

  // ── Roles ────────────────────────────────────────────────────────────────
  /// Secondary text and icons. 7.6:1 on Creamy White.
  static const Color ink2 = Color(0xFF514A4C);

  /// Captions and placeholders. 5.3:1 on Creamy White.
  static const Color ink3 = Color(0xFF6A6260);

  /// Hairlines between and around cards: Roasted Black at 15% on cream.
  static const Color line = Color(0xFFDDD2C9);

  /// Field outlines: Roasted Black at 50%.
  static const Color fieldLine = Color(0x80272323);

  /// The book has no error colour, so errors use the red of its own "do not"
  /// marks (p22). 5.7:1 on Creamy White.
  static const Color danger = Color(0xFFC00000);
  static const Color dangerSurface = Color(0xFFF9E3DA);
  static const Color dangerBorder = Color(0x59C00000);

  /// Confirmations stay in the base colours rather than adding a green.
  static const Color success = roastedBlack;
  static const Color successSurface = californiaCream;

  /// Warnings: Roasted Black text on California Cream, edged in caramel.
  /// Use [goldenCaramel] for the edge and [roastedBlack] for the words.
  static const Color warning = goldenCaramel;
  static const Color info = ink2;

  // ── Neutral ──────────────────────────────────────────────────────────────
  /// The brand's white is Creamy White; pure white is only for QR plates,
  /// where scanners want the most contrast.
  static const Color white = creamyWhite;
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color black = roastedBlack;

  // ── Ramp aliases ─────────────────────────────────────────────────────────
  static const Color espresso = roastedBlack;
  static const Color darkBrown = roastedBlack;
  static const Color brown = roastedBlack;
  static const Color caramel = ink2;
  static const Color amber = goldenCaramel;
  static const Color gold = goldenCaramel;
  static const Color latte = line;
  static const Color latteLight = californiaCream;
  static const Color cream = creamyWhite;
  static const Color muted = ink3;

  static const Color primaryBlack = roastedBlack;
  static const Color primaryBlue = roastedBlack;
  static const Color primaryDarkBlue = roastedBlack;
  static const Color secondaryBlue = roastedBlack;
  static const Color lightBlue = californiaCream;
  static const Color accentBlue = ink2;

  static const Color darkGray = roastedBlack;
  static const Color mediumGray = ink2;
  static const Color lightGray = creamyWhite;
  static const Color borderGray = line;

  // ── Permission badges ────────────────────────────────────────────────────
  static const Color granted = roastedBlack;
  static const Color denied = ink3;

  // ── Inspection status ────────────────────────────────────────────────────
  static const Color statusCompleted = success;
  static const Color statusOngoing = goldenCaramel;
  static const Color statusNotStarted = danger;

  // ── BNR condition colours ────────────────────────────────────────────────
  static const Color conditionGood = Color(0xFF3A8A5C);
  static const Color conditionFair = Color(0xFF7D9B3A);
  static const Color conditionPoor = Color(0xFFDBA842);
  static const Color conditionVeryPoor = Color(0xFFC4781A);
  static const Color conditionCritical = Color(0xFFC0392B);

  // ── Composite decorations ────────────────────────────────────────────────
  // The brand is flat: solid colour, no gradients on chrome, no card shadows.
  // These stay so older call sites compile, and draw flat.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [roastedBlack, roastedBlack],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [roastedBlack, roastedBlack],
  );

  static List<BoxShadow> get cardShadow => const [];

  static List<BoxShadow> get heroShadow => const [];

  /// The one lift in the app: the member-code button over the page.
  static List<BoxShadow> get fabShadow => [
        BoxShadow(
          color: roastedBlack.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}
