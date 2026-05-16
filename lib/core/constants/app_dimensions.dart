/// Layout dimensions — enforces 44dp minimum touch target (WCAG / Apple HIG)
class AppDimensions {
  AppDimensions._();

  // ── Touch targets ─────────────────────────────────────────────────────────
  static const double minTouchTarget = 44.0;
  static const double buttonHeight = 48.0;
  static const double buttonHeightLarge = 56.0;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusRound = 100.0;

  // ── Card / container ──────────────────────────────────────────────────────
  static const double cardElevation = 2.0;
  static const double appBarHeight = 56.0;

  // ── Dashboard grid ────────────────────────────────────────────────────────
  static const double moduleTileSize = 120.0;
  static const int gridColumnsPhone = 2;
  static const int gridColumnsTablet = 3;
  static const double tabletBreakpoint = 600.0;

  // ── Form ─────────────────────────────────────────────────────────────────
  static const double inputHeight = 56.0;
  static const double labelFontSize = 12.0;

  // ── Avatar ────────────────────────────────────────────────────────────────
  static const double avatarSm = 32.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 64.0;
}
