import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/defense_meta.dart';
import 'app_colors.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case MessageRole.user:
        return _UserBubble(message: message);
      case MessageRole.blocked:
        return _BlockedBubble(message: message);
      case MessageRole.assistant:
        return _AssistantBubble(message: message);
    }
  }
}

// ─── User bubble ────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('You',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(width: 4),
                    Icon(Icons.person, size: 13, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0891B2), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blocked bubble ─────────────────────────────────────────────────────────

class _BlockedBubble extends StatelessWidget {
  final ChatMessage message;
  const _BlockedBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final meta = message.defenseMeta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 13, color: AppColors.danger),
              const SizedBox(width: 4),
              Text('Blocked',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF450A0A).withOpacity(0.4),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This message was blocked by the defense pipeline.',
                  style: TextStyle(
                      color: AppColors.dangerLight,
                      fontSize: 13,
                      height: 1.5),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Risk ${meta.riskPercent}%  ·  ${meta.domainReadable}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.danger.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assistant bubble ────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined,
                  size: 13, color: AppColors.accent),
              const SizedBox(width: 4),
              Text('AegisMind',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              if (message.decision != null) ...[
                const SizedBox(width: 6),
                _DecisionChip(decision: message.decision!),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: message.isLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Thinking...',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  )
                : Text(
                    message.content,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.5),
                  ),
          ),
          if (message.defenseMeta != null && !message.isLoading) ...[
            const SizedBox(height: 4),
            _DefenseBadge(meta: message.defenseMeta!),
          ],
        ],
      ),
    );
  }
}

// ─── Small helpers ───────────────────────────────────────────────────────────

class _DecisionChip extends StatelessWidget {
  final String decision;
  const _DecisionChip({required this.decision});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    if (decision == 'ALLOW') {
      bg = const Color(0xFF14532D).withOpacity(0.5);
      text = const Color(0xFF86EFAC);
    } else if (decision == 'HESITATE') {
      bg = const Color(0xFF713F12).withOpacity(0.5);
      text = const Color(0xFFFDE68A);
    } else {
      bg = const Color(0xFF450A0A).withOpacity(0.5);
      text = const Color(0xFFFCA5A5);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(decision,
          style:
              TextStyle(fontSize: 9, color: text, fontWeight: FontWeight.w600)),
    );
  }
}

class _DefenseBadge extends StatelessWidget {
  final DefenseMeta meta;
  const _DefenseBadge({required this.meta});

  @override
  Widget build(BuildContext context) {
    final isBlock = meta.decision == 'BLOCK';
    final isHesitate = meta.decision == 'HESITATE';
    final color = isBlock
        ? AppColors.danger
        : isHesitate
            ? AppColors.warning
            : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            'Risk ${meta.riskPercent}%  ·  ${meta.domainReadable}',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}
