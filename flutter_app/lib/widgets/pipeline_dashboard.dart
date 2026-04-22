import 'dart:async';
import 'package:flutter/material.dart';
import '../models/defense_meta.dart';
import '../models/pipeline_state.dart';
import '../services/api_service.dart';
import 'defense_card.dart';
import 'stage_card.dart';
import 'app_colors.dart';

class PipelineDashboard extends StatefulWidget {
  final String? pipelineId;
  final DefenseMeta? defenseMeta;
  final String? verdict;
  final String? displayLabel;
  final double? avgAgreement;
  final Map<String, String>? modelStatuses;

  const PipelineDashboard({
    super.key,
    this.pipelineId,
    this.defenseMeta,
    this.verdict,
    this.displayLabel,
    this.avgAgreement,
    this.modelStatuses,
  });

  @override
  State<PipelineDashboard> createState() => _PipelineDashboardState();
}

class _PipelineDashboardState extends State<PipelineDashboard> {
  PipelineState _pipeline = PipelineState.idle();
  Timer? _timer;
  String? _lastId;

  @override
  void didUpdateWidget(PipelineDashboard old) {
    super.didUpdateWidget(old);
    if (widget.pipelineId != old.pipelineId) {
      _startPolling(widget.pipelineId);
    }
  }

  void _startPolling(String? id) {
    _timer?.cancel();
    _lastId = id;

    if (id == null || id.startsWith('blocked-')) {
      setState(() => _pipeline = PipelineState.idle());
      return;
    }

    setState(() => _pipeline = PipelineState(
          status: 'running',
          stages: PipelineStages(),
        ));

    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_lastId != id) return;
      try {
        final state = await ApiService.getPipelineStatus(id);
        if (!mounted || _lastId != id) return;
        setState(() => _pipeline = state);
        if (state.isDone) _timer?.cancel();
      } catch (_) {}
    });

    // First poll immediately
    Future.microtask(() async {
      try {
        final state = await ApiService.getPipelineStatus(id);
        if (!mounted || _lastId != id) return;
        setState(() => _pipeline = state);
        if (state.isDone) _timer?.cancel();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isBlocked => widget.defenseMeta?.decision == 'BLOCK';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: AppColors.border.withOpacity(0.5))),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 15, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('Defense Dashboard',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              if (_pipeline.status == 'running')
                Row(
                  children: [
                    SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.warning),
                    ),
                    const SizedBox(width: 6),
                    Text('Running pipeline...',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.warning)),
                  ],
                ),
              if (_pipeline.status == 'done')
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('Complete',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.success)),
                  ],
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Empty state
                if (widget.defenseMeta == null) ...[
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 48,
                            color: AppColors.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('Defense pipeline',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Send a message to see real-time analysis',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],

                // Defense check result
                if (widget.defenseMeta != null) ...[
                  DefenseCard(meta: widget.defenseMeta!),
                  const SizedBox(height: 10),
                ],

                // Pipeline stages (only if not blocked)
                if (widget.defenseMeta != null && !_isBlocked) ...[
                  StageCard(
                    title: 'Decomposition',
                    icon: Icons.account_tree_outlined,
                    stage: _pipeline.stages.decomposition,
                    contentBuilder: (data) =>
                        DecompositionContent(data: data),
                  ),
                  const SizedBox(height: 8),
                  StageCard(
                    title: 'Reasoning',
                    icon: Icons.psychology_outlined,
                    stage: _pipeline.stages.reasoning,
                    contentBuilder: (data) => ReasoningContent(data: data),
                  ),
                  const SizedBox(height: 8),
                  StageCard(
                    title: 'RAG Verification',
                    icon: Icons.manage_search_outlined,
                    stage: _pipeline.stages.rag,
                    contentBuilder: (data) => RagContent(data: data),
                  ),
                  const SizedBox(height: 8),
                  _CrossModelCard(
                    verdict: widget.verdict,
                    displayLabel: widget.displayLabel,
                    avgAgreement: widget.avgAgreement,
                    modelStatuses: widget.modelStatuses,
                  ),
                ],

                // Blocked message — no pipeline stages
                if (widget.defenseMeta != null && _isBlocked) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 32, color: AppColors.danger),
                        const SizedBox(height: 8),
                        Text('Message Blocked',
                            style: TextStyle(
                                color: AppColors.dangerLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'RAG & reasoning pipeline only runs for allowed messages.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.danger.withOpacity(0.6)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Cross-Model Validation card ──────────────────────────────────────────────

class _CrossModelCard extends StatelessWidget {
  final String? verdict;
  final String? displayLabel;
  final double? avgAgreement;
  final Map<String, String>? modelStatuses;

  const _CrossModelCard({
    this.verdict,
    this.displayLabel,
    this.avgAgreement,
    this.modelStatuses,
  });

  Color get _verdictColor {
    switch (verdict) {
      case 'CONSENSUS':
        return const Color(0xFF16A34A);
      case 'PARTIAL':
        return const Color(0xFFCA8A04);
      case 'DISAGREEMENT':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = verdict != null;
    final color = isReady ? _verdictColor : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              const Text(
                'Cross-Model Validation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (!isReady)
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.warning),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Model rows — driven by real backend data
          ...() {
            final models = (modelStatuses != null && modelStatuses!.isNotEmpty)
                ? modelStatuses!.entries.toList()
                : [
                    for (final m in ['phi3', 'llama3', 'mistral'])
                      MapEntry(m, isReady ? 'ok' : 'pending')
                  ];
            return models.map((entry) {
              final modelOk = entry.value == 'ok';
              final icon = !isReady
                  ? '⏳'
                  : modelOk
                      ? '✅'
                      : '❌';
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: !isReady
                            ? AppColors.textMuted
                            : modelOk
                                ? Colors.white
                                : AppColors.danger,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (isReady && !modelOk) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(unavailable)',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              );
            });
          }(),

          if (isReady) ...[
            const SizedBox(height: 8),
            Divider(color: color.withOpacity(0.2), height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Avg Agreement:',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                Text(
                  avgAgreement != null
                      ? avgAgreement!.toStringAsFixed(2)
                      : '—',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Verdict:',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    displayLabel ?? verdict ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
