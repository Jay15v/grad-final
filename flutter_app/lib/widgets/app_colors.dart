import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFF020617);        // slate-950
  static const Color bgSurface = Color(0xFF0F172A); // slate-900
  static const Color surface = Color(0xFF1E293B);   // slate-800
  static const Color border = Color(0xFF334155);    // slate-700
  static const Color accent = Color(0xFF06B6D4);    // cyan-500
  static const Color accentDark = Color(0xFF0891B2);// cyan-600
  static const Color blue = Color(0xFF2563EB);      // blue-600
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1); // slate-300
  static const Color textMuted = Color(0xFF64748B);     // slate-500

  static const Color success = Color(0xFF22C55E);   // green-500
  static const Color warning = Color(0xFFEAB308);   // yellow-500
  static const Color danger = Color(0xFFEF4444);    // red-500
  static const Color dangerLight = Color(0xFFFCA5A5);

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [Color(0xFF0891B2), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get bgGradient => const LinearGradient(
        colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF020617)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
