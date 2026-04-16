import 'package:flutter/material.dart';

/// A small colored banner that shows the cross-model consensus verdict
/// for an AI response.
///
/// Accepted [verdict] values: "CONSENSUS", "PARTIAL", "DISAGREEMENT".
/// Any other value renders a neutral grey banner without crashing.
class VerdictBanner extends StatelessWidget {
  final String verdict;

  const VerdictBanner({super.key, required this.verdict});

  // ── Color helpers ──────────────────────────────────────────────────────────

  Color _getBannerColor(String verdict) {
    switch (verdict) {
      case 'CONSENSUS':
        return const Color(0xFF16A34A); // green-600
      case 'PARTIAL':
        return const Color(0xFFCA8A04); // yellow-600
      case 'DISAGREEMENT':
        return const Color(0xFFDC2626); // red-600
      default:
        return const Color(0xFF6B7280); // gray-500
    }
  }

  Color _getTextColor(String verdict) {
    // DISAGREEMENT uses white text on red; others use dark text for contrast.
    switch (verdict) {
      case 'DISAGREEMENT':
        return Colors.white;
      default:
        return const Color(0xFF111827); // near-black
    }
  }

  // ── Label / icon helpers ───────────────────────────────────────────────────

  String _getLabel(String verdict) {
    switch (verdict) {
      case 'CONSENSUS':
        return 'Consensus';
      case 'PARTIAL':
        return 'Partially Hallucinating';
      case 'DISAGREEMENT':
        return 'High Risk of Hallucination';
      default:
        return verdict;
    }
  }

  String _getIcon(String verdict) {
    switch (verdict) {
      case 'CONSENSUS':
        return '✅';
      case 'PARTIAL':
        return '⚠️';
      case 'DISAGREEMENT':
        return '🔴';
      default:
        return 'ℹ️';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg        = _getBannerColor(verdict);
    final textColor = _getTextColor(verdict);
    final label     = _getLabel(verdict);
    final icon      = _getIcon(verdict);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
