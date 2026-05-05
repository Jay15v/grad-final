import 'package:flutter/material.dart';
import '../models/pipeline_state.dart';
import 'app_colors.dart';

class _ExpandableText extends StatefulWidget {
  final String text;
  final int maxChars;
  final TextStyle? style;
  const _ExpandableText({required this.text, this.maxChars = 200, this.style});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > widget.maxChars;
    final display = (isLong && !_expanded)
        ? _sentenceTrim(widget.text, widget.maxChars)
        : widget.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(display, style: widget.style),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class StageCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final StageEntry? stage;
  final Widget Function(dynamic data)? contentBuilder;

  const StageCard({
    super.key,
    required this.title,
    required this.icon,
    this.stage,
    this.contentBuilder,
  });

  @override
  State<StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<StageCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final isRunning = stage?.isRunning ?? false;
    final isDone = stage?.isDone ?? false;
    final isIdle = stage == null;

    Color iconColor;
    if (isDone) {
      iconColor = AppColors.accent;
    } else if (isRunning) {
      iconColor = AppColors.warning;
    } else {
      iconColor = AppColors.textMuted;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withOpacity(0.6),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(widget.icon, size: 15, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (isRunning)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.warning,
                      ),
                    ),
                  if (isDone)
                    Icon(Icons.check_circle_outline,
                        size: 13, color: AppColors.success),
                  if (isIdle)
                    Text('waiting',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Body
          if (_expanded) ...[
            Divider(height: 1, color: AppColors.border.withOpacity(0.4)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildBody(stage),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(StageEntry? stage) {
    if (stage == null) {
      return Text(
        'Will run after defense check passes.',
        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
      );
    }
    if (stage.isRunning) {
      return Row(
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.warning),
          ),
          const SizedBox(width: 8),
          Text('Processing...',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.warning.withOpacity(0.7))),
        ],
      );
    }
    if (stage.error != null) {
      return Text('Error: ${stage.error}',
          style: TextStyle(fontSize: 11, color: AppColors.danger));
    }
    if (stage.data != null && widget.contentBuilder != null) {
      return widget.contentBuilder!(stage.data);
    }
    return Text('Done',
        style: TextStyle(fontSize: 11, color: AppColors.textMuted));
  }
}

// ─── Specific stage content builders ────────────────────────────────────────

class DecompositionContent extends StatelessWidget {
  final dynamic data;
  const DecompositionContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final steps = (data['steps'] as List?)?.cast<Map>() ?? [];
    final quality = (data['quality']?['score'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${step['id']}.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontFamily: 'monospace')),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step['text'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
        if (quality != null) ...[
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.border.withOpacity(0.3)),
          const SizedBox(height: 4),
          Text(
            'Quality score: ${(quality * 100).round()}%',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class ReasoningContent extends StatelessWidget {
  final dynamic data;
  const ReasoningContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = (data as List?)?.cast<Map>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final stepId = item['step_id'];
        final reasoning = (item['reasoning'] as String? ?? '').trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step $stepId',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              reasoning.isEmpty
                  ? Text('No reasoning generated',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic))
                  : _ExpandableText(
                      text: reasoning,
                      maxChars: 200,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFCBD5E1),
                          height: 1.4),
                    ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _sentenceTrim(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  final sub = text.substring(0, maxChars);
  final lastEnd = sub.lastIndexOf(RegExp(r'[.!?]'));
  if (lastEnd > maxChars ~/ 2) return sub.substring(0, lastEnd + 1);
  final lastSpace = sub.lastIndexOf(' ');
  return lastSpace > 0 ? '${sub.substring(0, lastSpace)}…' : '$sub…';
}

class RagContent extends StatelessWidget {
  final dynamic data;
  const RagContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final results = (data['results'] as List?)?.cast<Map>() ?? [];
    final eval_ = data['rag_eval'] as Map? ?? {};
    final total = (eval_['total_steps'] as num?)?.toInt() ?? 0;
    final hits = (eval_['hits'] as num?)?.toInt() ?? 0;
    final misses = (eval_['misses'] as num?)?.toInt() ?? 0;
    final hitRate = (eval_['hit_rate'] as num?)?.toDouble() ?? 0.0;

    if (results.isEmpty) {
      return Text(
        'No claims to verify (RAG disabled or no claims extracted).',
        style: TextStyle(
            fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...results.take(6).map((r) {
          final verdict = r['verdict'] as String? ?? '';
          final claim = r['claim'] as String? ?? '';
          final bestEvidence = r['best_evidence'] as Map?;
          final source = bestEvidence?['source'] as String?;
          final similarity = (bestEvidence?['similarity'] as num?)?.toDouble();
          final coverage = (bestEvidence?['coverage'] as num?)?.toDouble();
          IconData icon;
          Color color;
          String label;
          if (verdict == 'SUPPORTED_WEAK') {
            icon = Icons.check_circle_outline;
            color = AppColors.success;
            label = 'Supported';
          } else if (verdict == 'NO_EVIDENCE') {
            icon = Icons.cancel_outlined;
            color = AppColors.danger;
            label = 'No Evidence';
          } else {
            icon = Icons.warning_amber_outlined;
            color = AppColors.warning;
            label = 'Weak Evidence';
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verdict badge row
                Row(
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color),
                      ),
                    ),
                    if (source != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          source,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                    if (similarity != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'sim ${(similarity * 100).round()}%',
                        style: TextStyle(fontSize: 10, color: AppColors.accent),
                      ),
                    ],
                    if (coverage != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        'cov ${(coverage * 100).round()}%',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                _ExpandableText(
                  text: claim,
                  maxChars: 180,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFCBD5E1),
                      height: 1.4),
                ),
              ],
            ),
          );
        }),
        if (total > 0) ...[
          Divider(height: 12, color: AppColors.border.withOpacity(0.3)),
          Row(
            children: [
              Text('Total: $total',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(width: 10),
              Text('Hits: $hits',
                  style: TextStyle(fontSize: 10, color: AppColors.success)),
              const SizedBox(width: 10),
              Text('Misses: $misses',
                  style: TextStyle(fontSize: 10, color: AppColors.danger)),
              const SizedBox(width: 10),
              Text('Rate: ${(hitRate * 100).round()}%',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ],
    );
  }
}
