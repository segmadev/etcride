import 'package:flutter/material.dart';

/// Central colour palette for ETC Rides Customer App.
/// Change values here and every widget that uses AppColors updates automatically.
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFFF5A623); // amber/golden
  static const Color primaryDark    = Color(0xFFE09010); // pressed / darker
  static const Color primaryLight   = Color(0xFFFFF3DC); // tinted background

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color black          = Color(0xFF1A1A1A);
  static const Color white          = Color(0xFFFFFFFF);
  static const Color background     = Color(0xFFFFFFFF);
  static const Color surface        = Color(0xFFF7F7F7);
  static const Color inputFill      = Color(0xFFF2F2F2);
  static const Color divider        = Color(0xFFEEEEEE);
  static const Color disabled       = Color(0xFFE5E5E5);
  static const Color splash         = Color(0xFF000000);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1A1A1A);
  static const Color textSecondary  = Color(0xFF6B6B6B);
  static const Color textHint       = Color(0xFFABABAB);
  static const Color textDisabled   = Color(0xFFBBBBBB);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success        = Color(0xFF22C55E);
  static const Color successLight   = Color(0xFFDCFCE7);
  static const Color error          = Color(0xFFEF4444);
  static const Color errorLight     = Color(0xFFFEE2E2);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color warningLight   = Color(0xFFFEF3C7);

  // ── Map pin colours ───────────────────────────────────────────────────────
  static const Color pickupPin      = Color(0xFF22C55E);   // green
  static const Color destinationPin = Color(0xFFF97316);   // orange
  static const Color routeLine      = Color(0xFFF5A623);   // brand amber

  // ── Star rating ───────────────────────────────────────────────────────────
  static const Color starFilled     = Color(0xFFF97316);
  static const Color starEmpty      = Color(0xFFE5E5E5);

  // ── Notification card ─────────────────────────────────────────────────────
  static const Color notifBg        = Color(0xFFFFF8EC);
  static const Color notifAccent    = Color(0xFFF5A623);
}
