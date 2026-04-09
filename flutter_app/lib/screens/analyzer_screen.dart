import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_colors.dart';

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isAnalyzing = false;
  AnalyzeResponse? _result;
  String? _error;

  Future<void> _analyze() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _error = null;
    });

    try {
      final res = await ApiService.analyzePrompt(prompt);
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface.withOpacity(0.5),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    const Text(
                      'Submit a Prompt for Analysis',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'AegisMind evaluates intent, safety, and semantic risk using layered AI defense.',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter your prompt here...',
                    hintStyle:
                        TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bg.withOpacity(0.8),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.border.withOpacity(0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.border.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.accent.withOpacity(0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isAnalyzing ? null : _analyze,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _isAnalyzing
                            ? null
                            : AppColors.accentGradient,
                        color: _isAnalyzing
                            ? AppColors.border.withOpacity(0.3)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isAnalyzing
                            ? null
                            : [
                                BoxShadow(
                                    color:
                                        AppColors.accent.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3))
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isAnalyzing) ...[
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent),
                            ),
                            const SizedBox(width: 8),
                            const Text('Analyzing...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ] else ...[
                            const Icon(Icons.shield_outlined,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Analyze Prompt',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                border:
                    Border.all(color: AppColors.danger.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!,
                  style: TextStyle(
                      color: AppColors.dangerLight, fontSize: 12)),
            ),
          ],

          // Result
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AnalyzeResponse result;
  const _ResultCard({required this.result});

  Color get _color {
    if (result.status == 'BLOCK') return AppColors.danger;
    if (result.status == 'HESITATE') return AppColors.warning;
    return AppColors.success;
  }

  IconData get _icon {
    if (result.status == 'BLOCK') return Icons.block;
    if (result.status == 'HESITATE') return Icons.warning_amber_outlined;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final meta = result.raw['decision_meta'] as Map? ?? {};
    final finalRisk = ((meta['final_risk'] as num?)?.toDouble() ?? 0.0);
    final bertRisk = ((meta['bert_risk'] as num?)?.toDouble() ?? 0.0);
    final semSim = ((meta['semantic_similarity'] as num?)?.toDouble() ?? 0.0);
    final domain = (meta['semantic_domain'] as String? ?? '').replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        border: Border.all(color: _color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _color, size: 24),
              const SizedBox(width: 10),
              Text(
                result.status,
                style: TextStyle(
                    color: _color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Row('Final Risk', '${(finalRisk * 100).round()}%', _color),
          _Row('BERT Risk', '${(bertRisk * 100).round()}%', AppColors.textSecondary),
          _Row('Semantic Similarity', '${(semSim * 100).round()}%', AppColors.textSecondary),
          _Row('Domain', domain.isEmpty ? 'unknown' : domain, AppColors.textSecondary),

          if (result.status == 'ALLOW' && result.raw['decomposition'] != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 8),
            Text('Decomposition',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...(((result.raw['decomposition']['steps']) as List?) ?? [])
                .cast<Map>()
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                          '${s['id']}. ${s['text']}',
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1), fontSize: 12)),
                    )),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _Row(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
