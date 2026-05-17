import 'package:flutter/material.dart';

class AppColors {
  // ── Base palette ────────────────────────────────────────────────────────────
  static const Color bg        = Color(0xFF0A1628); // dark navy
  static const Color bgSurface = Color(0xFF0F1F3D); // navy surface
  static const Color surface   = Color(0xFF162038); // card surface
  static const Color border    = Color(0xFF1E3A5F); // navy border

  // ── Primary blue ────────────────────────────────────────────────────────────
  static const Color accent     = Color(0xFF2196F3);
  static const Color accentDark = Color(0xFF1565C0);
  static const Color blue       = Color(0xFF1565C0);

  // ── Role accents ────────────────────────────────────────────────────────────
  static const Color adminAccent  = Color(0xFFE53935); // red
  static const Color parentAccent = Color(0xFF7B1FA2); // purple
  static const Color childAccent  = Color(0xFF00897B); // teal

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted     = Color(0xFF8B949E);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success     = Color(0xFF22C55E);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color danger      = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFCA5A5);

  // ── Gradients ───────────────────────────────────────────────────────────────
  static LinearGradient get accentGradient => const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get bgGradient => const LinearGradient(
        colors: [Color(0xFF0A1628), Color(0xFF0F1F3D), Color(0xFF0A1628)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get adminGradient => const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get parentGradient => const LinearGradient(
        colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get childGradient => const LinearGradient(
        colors: [Color(0xFF00897B), Color(0xFF004D40)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get headerGradient => const LinearGradient(
        colors: [Color(0xFF0A1628), Color(0xFF0F2448), Color(0xFF0A1628)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  // ── Shadows ─────────────────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x73000000), // ~45% black
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color, {double alpha = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // ── Border radii ────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
}
