import 'package:flutter/material.dart';
import '../models/defense_meta.dart';
import '../widgets/chat_panel.dart';
import '../widgets/pipeline_dashboard.dart';
import '../widgets/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _lastPipelineId;
  DefenseMeta? _lastDefenseMeta;
  String? _lastVerdict;
  String? _lastDisplayLabel;
  double? _lastAvgAgreement;

  void _onPipelineUpdate(
    String pipelineId,
    DefenseMeta meta, {
    String? verdict,
    String? displayLabel,
    double? avgAgreement,
  }) {
    setState(() {
      _lastPipelineId = pipelineId;
      _lastDefenseMeta = meta;
      _lastVerdict = verdict;
      _lastDisplayLabel = displayLabel;
      _lastAvgAgreement = avgAgreement;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;

      if (isWide) {
        // Side-by-side layout for desktop / tablet
        return Row(
          children: [
            SizedBox(
              width: constraints.maxWidth * 0.42,
              child: ChatPanel(onPipelineUpdate: _onPipelineUpdate),
            ),
            VerticalDivider(
                width: 1,
                color: AppColors.border.withOpacity(0.4)),
            Expanded(
              child: PipelineDashboard(
                pipelineId: _lastPipelineId,
                defenseMeta: _lastDefenseMeta,
                verdict: _lastVerdict,
                displayLabel: _lastDisplayLabel,
                avgAgreement: _lastAvgAgreement,
              ),
            ),
          ],
        );
      } else {
        // Tab-based layout for narrow screens
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: const [
                  Tab(text: 'Chat'),
                  Tab(text: 'Dashboard'),
                ],
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.accent,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ChatPanel(onPipelineUpdate: _onPipelineUpdate),
                    PipelineDashboard(
                      pipelineId: _lastPipelineId,
                      defenseMeta: _lastDefenseMeta,
                      verdict: _lastVerdict,
                      displayLabel: _lastDisplayLabel,
                      avgAgreement: _lastAvgAgreement,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    });
  }
}
