import 'package:flutter/material.dart';

// ─── App Theme Extension (light / dark structural colors) ─────────────────────
//
// Use AppTheme.of(context).bg etc. for background / text / border colors that
// differ between light and dark mode.  Keep AppColors.xxx for semantic /
// brand colors that stay the same in both modes.

class AppTheme extends ThemeExtension<AppTheme> {
  final Color bg;
  final Color bgSurface;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final LinearGradient bgGradient;
  final LinearGradient headerGradient;
  final List<BoxShadow> cardShadow;
  // Auth-screen specifics
  final Color authBg;
  final Color authCard;
  final Color authCardBorder;
  final Color authField;
  final Color authBorder;

  const AppTheme({
    required this.bg,
    required this.bgSurface,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.bgGradient,
    required this.headerGradient,
    required this.cardShadow,
    required this.authBg,
    required this.authCard,
    required this.authCardBorder,
    required this.authField,
    required this.authBorder,
  });

  static AppTheme of(BuildContext context) =>
      Theme.of(context).extension<AppTheme>()!;

  // ── Dark palette ────────────────────────────────────────────────────────────
  static final dark = AppTheme(
    bg:          const Color(0xFF0A1628),
    bgSurface:   const Color(0xFF0F1F3D),
    surface:     const Color(0xFF162038),
    border:      const Color(0xFF1E3A5F),
    textPrimary:   Colors.white,
    textSecondary: const Color(0xFFCBD5E1),
    textMuted:     const Color(0xFF8B949E),
    bgGradient: const LinearGradient(
      colors: [Color(0xFF0A1628), Color(0xFF0F1F3D), Color(0xFF0A1628)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: const LinearGradient(
      colors: [Color(0xFF0A1628), Color(0xFF0F2448), Color(0xFF0A1628)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    cardShadow: const [
      BoxShadow(color: Color(0x73000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
    authBg:          const Color(0xFF0A1628),
    authCard:        const Color(0x0DFFFFFF), // white 5 %
    authCardBorder:  const Color(0x1EFFFFFF), // white 12 %
    authField:       const Color(0xFF0E2040),
    authBorder:      const Color(0xFF1E3A5F),
  );

  // ── Light palette ───────────────────────────────────────────────────────────
  static final light = AppTheme(
    bg:          const Color(0xFFF8FAFC),
    bgSurface:   const Color(0xFFEFF3F8),
    surface:     const Color(0xFFE4EDF6),
    border:      const Color(0xFFBFD3E8),
    textPrimary:   const Color(0xFF0F172A),
    textSecondary: const Color(0xFF334155),
    textMuted:     const Color(0xFF64748B),
    bgGradient: const LinearGradient(
      colors: [Color(0xFFF8FAFC), Color(0xFFEFF3F8), Color(0xFFF8FAFC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: const LinearGradient(
      colors: [Color(0xFFF0F4F8), Color(0xFFE8F0FA), Color(0xFFF0F4F8)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    cardShadow: const [
      BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    authBg:          const Color(0xFFF0F4F8),
    authCard:        const Color(0xFFFFFFFF),
    authCardBorder:  const Color(0xFFE2ECF5),
    authField:       const Color(0xFFF8FAFC),
    authBorder:      const Color(0xFFCBD5E1),
  );

  @override
  AppTheme copyWith({
    Color? bg, Color? bgSurface, Color? surface, Color? border,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
    LinearGradient? bgGradient, LinearGradient? headerGradient,
    List<BoxShadow>? cardShadow,
    Color? authBg, Color? authCard, Color? authCardBorder,
    Color? authField, Color? authBorder,
  }) => AppTheme(
    bg: bg ?? this.bg,
    bgSurface: bgSurface ?? this.bgSurface,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    bgGradient: bgGradient ?? this.bgGradient,
    headerGradient: headerGradient ?? this.headerGradient,
    cardShadow: cardShadow ?? this.cardShadow,
    authBg: authBg ?? this.authBg,
    authCard: authCard ?? this.authCard,
    authCardBorder: authCardBorder ?? this.authCardBorder,
    authField: authField ?? this.authField,
    authBorder: authBorder ?? this.authBorder,
  );

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) return this;
    return AppTheme(
      bg:           Color.lerp(bg, other.bg, t)!,
      bgSurface:    Color.lerp(bgSurface, other.bgSurface, t)!,
      surface:      Color.lerp(surface, other.surface, t)!,
      border:       Color.lerp(border, other.border, t)!,
      textPrimary:  Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary:Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:    Color.lerp(textMuted, other.textMuted, t)!,
      bgGradient:      t < 0.5 ? bgGradient : other.bgGradient,
      headerGradient:  t < 0.5 ? headerGradient : other.headerGradient,
      cardShadow:      t < 0.5 ? cardShadow : other.cardShadow,
      authBg:          Color.lerp(authBg, other.authBg, t)!,
      authCard:        Color.lerp(authCard, other.authCard, t)!,
      authCardBorder:  Color.lerp(authCardBorder, other.authCardBorder, t)!,
      authField:       Color.lerp(authField, other.authField, t)!,
      authBorder:      Color.lerp(authBorder, other.authBorder, t)!,
    );
  }
}

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
