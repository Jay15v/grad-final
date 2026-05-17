import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Animated verdict banner shown below an AI response.
/// Accepted [verdict] values: "CONSENSUS", "PARTIAL", "DISAGREEMENT".
class VerdictBanner extends StatefulWidget {
  final String verdict;

  const VerdictBanner({super.key, required this.verdict});

  @override
  State<VerdictBanner> createState() => _VerdictBannerState();
}

class _VerdictBannerState extends State<VerdictBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Theming helpers ────────────────────────────────────────────────────────

  _VerdictTheme _theme() {
    switch (widget.verdict) {
      case 'CONSENSUS':
        return _VerdictTheme(
          bg: const Color(0xFF16A34A).withValues(alpha: 0.15),
          border: const Color(0xFF16A34A).withValues(alpha: 0.4),
          text: const Color(0xFF4ADE80),
          icon: Icons.check_circle_outline,
          label: 'Consensus — Models Agree',
        );
      case 'PARTIAL':
        return _VerdictTheme(
          bg: const Color(0xFFCA8A04).withValues(alpha: 0.15),
          border: const Color(0xFFCA8A04).withValues(alpha: 0.4),
          text: const Color(0xFFFBBF24),
          icon: Icons.warning_amber_outlined,
          label: 'Partial — Possible Hallucination',
        );
      case 'DISAGREEMENT':
        return _VerdictTheme(
          bg: const Color(0xFFDC2626).withValues(alpha: 0.15),
          border: const Color(0xFFDC2626).withValues(alpha: 0.4),
          text: const Color(0xFFF87171),
          icon: Icons.dangerous_outlined,
          label: 'Disagreement — High Risk',
        );
      default:
        return _VerdictTheme(
          bg: AppColors.border.withValues(alpha: 0.15),
          border: AppColors.border.withValues(alpha: 0.4),
          text: AppColors.textSecondary,
          icon: Icons.info_outline,
          label: widget.verdict,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme();
    return ClipRect(
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: t.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.icon, size: 13, color: t.text),
                const SizedBox(width: 6),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerdictTheme {
  final Color bg;
  final Color border;
  final Color text;
  final IconData icon;
  final String label;

  const _VerdictTheme({
    required this.bg,
    required this.border,
    required this.text,
    required this.icon,
    required this.label,
  });
}
