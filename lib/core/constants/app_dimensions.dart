/// Layout dimensions — enforces 44dp minimum touch target (WCAG / Apple HIG).
///
/// Radii are modest and consistent: the brand is flat and confident, with the
/// round seal of the logo and the stamps as its only full circles.
class AppDimensions {
  AppDimensions._();

  // ── Touch targets ─────────────────────────────────────────────────────────
  static const double minTouchTarget = 44.0;
  static const double buttonHeight = 54.0;
  static const double buttonHeightLarge = 58.0;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  /// The page's side margin.
  static const double gutter = 20.0;

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double radiusSm = 8.0; // inputs, small tiles
  static const double radiusMd = 10.0; // buttons
  static const double radiusLg = 12.0; // cards, grouped containers
  static const double radiusXl = 16.0; // the stamp card, dialogs
  static const double radiusSheet = 20.0; // bottom sheets
  static const double radiusRound = 100.0;

  // ── Card / container ──────────────────────────────────────────────────────
  /// The design uses hairline borders, not shadows, so elevation stays flat.
  static const double cardElevation = 0.0;
  static const double cardBorderWidth = 1.0;
  static const double appBarHeight = 56.0;

  // ── Dashboard grid ────────────────────────────────────────────────────────
  static const double moduleTileSize = 120.0;
  static const int gridColumnsPhone = 2;
  static const int gridColumnsTablet = 3;
  static const double tabletBreakpoint = 600.0;

  // ── Form ─────────────────────────────────────────────────────────────────
  static const double inputHeight = 54.0;
  static const double labelFontSize = 10.5;

  // ── Avatar ────────────────────────────────────────────────────────────────
  static const double avatarSm = 32.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 64.0;
}
