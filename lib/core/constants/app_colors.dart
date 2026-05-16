import 'package:flutter/material.dart';

/// DPWH BMS color palette — Updated to Light Blue Theme
class AppColors {
  AppColors._();

  // ── Primary palette ──────────────────────────────────────────────────────
  static const Color primaryBlack = Color(0xFF000000); // Pure Black
  static const Color primaryBlue = Color(0xFF000000); // Alias for compatibility
  static const Color primaryDarkBlue = Color(0xFF1E293B); // Dark Slate for states
  static const Color secondaryBlue = Color(0xFF000000);
  static const Color lightBlue = Color(0xFFF1F5F9); // Light Gray
  static const Color accentBlue = Color(0xFF64748B); // Slate Gray

  // ── Neutral ──────────────────────────────────────────────────────────────
  static const Color black = Color(0xFF000000); // Pure Black
  static const Color darkGray = Color(0xFF000000); // Black for text
  static const Color mediumGray = Color(0xFF1E293B); // Dark Slate for secondary text
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFFFFFFF); // Pure White background
  static const Color borderGray = Color(0xFFE2E8F0); // Slate 200

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // ── Permission badges ────────────────────────────────────────────────────
  static const Color granted = Color(0xFF38BDF8); 
  static const Color denied = Color(0xFF64748B);

  // ── Inspection status (from spec) ────────────────────────────────────────
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusOngoing = Color(0xFFF59E0B);
  static const Color statusNotStarted = Color(0xFFEF4444);

  // ── BNR condition colours ────────────────────────────────────────────────
  static const Color conditionGood = Color(0xFF10B981);
  static const Color conditionFair = Color(0xFF84CC16);
  static const Color conditionPoor = Color(0xFFFBBF24);
  static const Color conditionVeryPoor = Color(0xFFF97316);
  static const Color conditionCritical = Color(0xFFEF4444);
}
