import 'package:flutter/material.dart';
import 'app_colors.dart';

/// All text styles used throughout the app.
/// Derived from the Inter font family used in the Figma design.
abstract final class AppTextStyles {
  static const String _font = 'Inter';

  // ── Display ───────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _font, fontSize: 32, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.2,
  );
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _font, fontSize: 28, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.25,
  );

  // ── Headings ──────────────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontFamily: _font, fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.3,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.35,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.4,
  );
  static const TextStyle h4 = TextStyle(
    fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.4,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.5,
  );

  // ── Label / Button ────────────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w700,
    color: AppColors.white, letterSpacing: 0.8, height: 1.0,
  );
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.0,
  );
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary, height: 1.0,
  );

  // ── Caption / Hint ────────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.textHint, height: 1.4,
  );

  // ── Price / Fare ──────────────────────────────────────────────────────────
  static const TextStyle price = TextStyle(
    fontFamily: _font, fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.2,
  );
  static const TextStyle priceMedium = TextStyle(
    fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.2,
  );
}
