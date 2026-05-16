import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Display / Hero text ───────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  // ── Headings ──────────────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.darkGray,
  );

  static const TextStyle h2 = TextStyle(
    
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGray,
  );

  static const TextStyle h3 = TextStyle(
    
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGray,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.darkGray,
  );

  static const TextStyle bodyMedium = TextStyle(
    
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkGray,
  );

  static const TextStyle bodySmall = TextStyle(
    
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
  );

  // ── Button ────────────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  // ── Label / Caption ───────────────────────────────────────────────────────
  static const TextStyle label = TextStyle(
    
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGray,
    letterSpacing: 0.4,
  );

  static const TextStyle caption = TextStyle(
    
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
  );

  // ── Specialised ───────────────────────────────────────────────────────────
  static const TextStyle appBarTitle = TextStyle(
    
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle chip = TextStyle(
    
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle errorText = TextStyle(
    
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.danger,
  );

  static const TextStyle tableHeader = TextStyle(
    
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle tableCell = TextStyle(
    
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.darkGray,
  );
}
