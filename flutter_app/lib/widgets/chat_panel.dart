import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/defense_meta.dart';
import '../services/api_service.dart';
import 'message_bubble.dart';
import 'app_colors.dart';

class ChatPanel extends StatefulWidget {
  final void Function(String pipelineId, DefenseMeta meta) onPipelineUpdate;

  const ChatPanel({super.key, required this.onPipelineUpdate});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'welcome',
      role: MessageRole.assistant,
      content:
          "Hello! I'm AegisMind. Every message you send is checked by the defense pipeline before I respond. Ask me anything.",
    ),
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _rlhfPending = false;

  List<Map<String, String>> get _history {
    return _messages
        .where((m) =>
            (m.role == MessageRole.user || m.role == MessageRole.assistant) &&
            !m.isLoading)
        .take(10)
        .map((m) => {
              'role': m.role == MessageRole.assistant ? 'assistant' : 'user',
              'content': m.content,
            })
        .toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _isSending = true;
      _rlhfPending = false;
    });

    final userMsgId = UniqueKey().toString();
    final loadingMsgId = UniqueKey().toString();

    setState(() {
      _messages.add(ChatMessage(
          id: userMsgId, role: MessageRole.user, content: text));
      _messages.add(ChatMessage(
          id: loadingMsgId,
          role: MessageRole.assistant,
          content: '',
          isLoading: true));
    });
    _scrollToBottom();

    try {
      final response =
          await ApiService.sendChat(message: text, history: _history);

      setState(() {
        _rlhfPending = response.rlhfPending;
        _messages.removeWhere((m) => m.id == loadingMsgId);

        if (response.decision == 'BLOCK') {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            role: MessageRole.blocked,
            content: '',
            decision: 'BLOCK',
            defenseMeta: response.defenseMeta,
          ));
          widget.onPipelineUpdate(
              'blocked-$userMsgId', response.defenseMeta);
        } else {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            role: MessageRole.assistant,
            content: response.reply ?? '(no response)',
            decision: response.decision,
            defenseMeta: response.defenseMeta,
            pipelineId: response.pipelineId,
          ));
          if (response.pipelineId != null) {
            widget.onPipelineUpdate(
                response.pipelineId!, response.defenseMeta);
          }
        }
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == loadingMsgId);
        _messages.add(ChatMessage(
          id: UniqueKey().toString(),
          role: MessageRole.assistant,
          content:
              'Error: Could not reach the backend. Make sure it\'s running on port 53908.',
        ));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.success.withOpacity(0.5),
                        blurRadius: 4)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('Chat',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              Text('phi3 · defense-gated',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) =>
                MessageBubble(message: _messages[i]),
          ),
        ),

        // RLHF banner
        if (_rlhfPending)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This prompt has been flagged for parental review',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: AppColors.border.withOpacity(0.5))),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      enabled: !_isSending,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surface.withOpacity(0.7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.border.withOpacity(0.2)),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isSending
                            ? null
                            : AppColors.accentGradient,
                        color: _isSending
                            ? AppColors.border.withOpacity(0.3)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isSending
                            ? null
                            : [
                                BoxShadow(
                                    color: AppColors.accent.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                      ),
                      child: _isSending
                          ? Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter to send  ·  Every message is defense-checked before response',
                style: TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
