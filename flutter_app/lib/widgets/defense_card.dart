import 'package:flutter/material.dart';
import '../models/defense_meta.dart';
import 'app_colors.dart';

class DefenseCard extends StatelessWidget {
  final DefenseMeta meta;

  const DefenseCard({super.key, required this.meta});

  Color get _borderColor {
    if (meta.decision == 'BLOCK') return AppColors.danger.withOpacity(0.4);
    if (meta.decision == 'HESITATE') return AppColors.warning.withOpacity(0.4);
    return AppColors.success.withOpacity(0.3);
  }

  Color get _bgColor {
    if (meta.decision == 'BLOCK')
      return const Color(0xFF450A0A).withOpacity(0.25);
    if (meta.decision == 'HESITATE')
      return const Color(0xFF422006).withOpacity(0.25);
    return const Color(0xFF052E16).withOpacity(0.2);
  }

  Color get _decisionColor {
    if (meta.decision == 'BLOCK') return AppColors.danger;
    if (meta.decision == 'HESITATE') return AppColors.warning;
    return AppColors.success;
  }

  Color get _barColor {
    if (meta.finalRisk >= 0.6) return AppColors.danger;
    if (meta.finalRisk >= 0.35) return AppColors.warning;
    return AppColors.success;
  }

  IconData get _icon {
    if (meta.decision == 'BLOCK') return Icons.shield_outlined;
    if (meta.decision == 'HESITATE') return Icons.warning_amber_outlined;
    return Icons.verified_user_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(_icon, size: 16, color: _decisionColor),
              const SizedBox(width: 6),
              Text('Defense Check',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _decisionColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  meta.decision,
                  style: TextStyle(
                      fontSize: 10,
                      color: _decisionColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Risk bar
          Row(
            children: [
              Text('Final Risk',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
              const Spacer(),
              Text('${meta.riskPercent}%',
                  style: TextStyle(
                      fontSize: 10,
                      color: _barColor,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: meta.finalRisk.clamp(0.0, 1.0),
              backgroundColor: AppColors.border.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // Stats grid
          Row(
            children: [
              _StatItem(label: 'BERT', value: '${meta.bertPercent}%',
                  color: _colorFor(meta.bertRisk)),
              const SizedBox(width: 16),
              _StatItem(label: 'Semantic', value: '${meta.semanticPercent}%',
                  color: AppColors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: _StatItem(
                    label: 'Domain',
                    value: meta.domainReadable.isEmpty
                        ? 'unknown'
                        : meta.domainReadable,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorFor(double risk) {
    if (risk >= 0.6) return AppColors.danger;
    if (risk >= 0.35) return AppColors.warning;
    return AppColors.success;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 9, color: AppColors.textMuted)),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
