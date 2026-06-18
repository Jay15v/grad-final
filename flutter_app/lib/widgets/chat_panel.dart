import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import 'message_bubble.dart';
import 'app_colors.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isSending = false;
  bool _rlhfPending = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _stopRequested = false;

  final String _sessionId =
      'session_${DateTime.now().millisecondsSinceEpoch}';
  final Set<String> _blockedMsgIds = {};

  // per-message rating state: aiMsgId → 'good' | 'bad'
  final Map<String, String> _messageRatings = {};
  // aiMsgId → the user prompt that triggered that response
  final Map<String, String> _msgPrompts = {};

  List<Map<String, String>> get _history {
    return _messages
        .where((m) =>
            (m.role == MessageRole.user || m.role == MessageRole.assistant) &&
            !m.isLoading &&
            !_blockedMsgIds.contains(m.id))
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
          _blockedMsgIds.add(userMsgId);
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            role: MessageRole.blocked,
            content: response.reply ?? '',
            decision: 'BLOCK',
            defenseMeta: response.defenseMeta,
          ));
        } else {
          final aiMsgId = UniqueKey().toString();
          _msgPrompts[aiMsgId] = text;
          _messages.add(ChatMessage(
            id: aiMsgId,
            role: MessageRole.assistant,
            content: response.reply ?? '(no response)',
            decision: response.decision,
            defenseMeta: response.defenseMeta,
            pipelineId: response.pipelineId,
            verdict: response.verdict,
          ));
        }
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == loadingMsgId);
        _messages.add(ChatMessage(
          id: UniqueKey().toString(),
          role: MessageRole.assistant,
          content:
              'Error: Could not reach the backend. Make sure it\'s running on port 5000.',
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
    _audioRecorder.dispose();
    super.dispose();
  }

  // ── Voice input ────────────────────────────────────────────────────────────

  bool get _voiceBusy => _isRecording || _isTranscribing;

  Future<void> _startRecording() async {
    if (kIsWeb || _isSending || _voiceBusy) return;
    _stopRequested = false;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showVoiceError('Microphone permission denied');
      return;
    }
    if (_stopRequested) return;

    try {
      final dir = await getTemporaryDirectory();
      if (_stopRequested) return;

      final path =
          '${dir.path}/aegismind_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
        path: path,
      );
      if (mounted) setState(() => _isRecording = true);
      if (_stopRequested) await _doStopAndTranscribe();
    } catch (_) {
      _showVoiceError('Could not start recording');
    }
  }

  Future<void> _stopAndTranscribe() async {
    _stopRequested = true;
    if (!_isRecording) return;
    await _doStopAndTranscribe();
  }

  Future<void> _doStopAndTranscribe() async {
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    await _transcribeFile(path);

    if (mounted) setState(() => _isTranscribing = false);
  }

  Future<void> _transcribeFile(String? path) async {
    if (path == null) {
      _showVoiceError('Voice input failed, please try again');
      return;
    }

    try {
      final file = File(path);
      if (!await file.exists()) {
        _showVoiceError('Voice input failed, please try again');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/transcribe'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', path,
            filename: 'voice.m4a'),
      );

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final text = (data['text'] as String? ?? '').trim();
        if (text.isNotEmpty) {
          if (mounted) setState(() => _controller.text = text);
        } else {
          _showVoiceError('No speech detected — try again');
        }
      } else {
        _showVoiceError('Transcribe error ${streamed.statusCode}: $body');
      }
    } catch (e) {
      _showVoiceError('Voice error: $e');
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  void _showVoiceError([String msg = 'Voice input failed, please try again']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Per-message rating ─────────────────────────────────────────────────────

  Future<void> _rateMessage(String msgId, String rating) async {
    if (_messageRatings.containsKey(msgId)) return;
    setState(() => _messageRatings[msgId] = rating);

    final userPrompt = _msgPrompts[msgId] ?? '';
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    ApiService.rateMessage(
      message: userPrompt,
      sessionId: _sessionId,
      userId: userId,
      rating: rating,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rating == 'good'
              ? 'Glad it was helpful!'
              : 'Thanks — we\'ll review this response.',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: rating == 'good'
            ? AppColors.success
            : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMessageRatingRow(ChatMessage msg) {
    final rated = _messageRatings[msg.id];
    if (rated != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rated == 'good' ? Icons.thumb_up : Icons.thumb_down,
              size: 12,
              color: rated == 'good' ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 4),
            Text(
              rated == 'good' ? 'Helpful' : 'Reported',
              style: TextStyle(
                fontSize: 11,
                color: rated == 'good' ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _rateMessage(msg.id, 'good'),
            child: Icon(Icons.thumb_up_outlined,
                size: 15, color: AppTheme.of(context).textMuted),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _rateMessage(msg.id, 'bad'),
            child: Icon(Icons.thumb_down_outlined,
                size: 15, color: AppTheme.of(context).textMuted),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
                    BorderSide(color: AppTheme.of(context).border.withValues(alpha: 0.5))),
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
                        color: AppColors.success.withValues(alpha: 0.5),
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
                      fontSize: 11, color: AppTheme.of(context).textMuted)),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final msg = _messages[i];
              if (msg.role == MessageRole.assistant && !msg.isLoading) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MessageBubble(message: msg),
                    _buildMessageRatingRow(msg),
                  ],
                );
              }
              return MessageBubble(message: msg);
            },
          ),
        ),

        // RLHF banner
        if (_rlhfPending)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
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
                top: BorderSide(color: AppTheme.of(context).border.withValues(alpha: 0.5))),
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
                      enabled: !_isSending && !_voiceBusy,
                      style: TextStyle(
                          color: AppTheme.of(context).textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: AppTheme.of(context).textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppTheme.of(context).surface.withValues(alpha: 0.7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.of(context).border.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.of(context).border.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.5)),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.of(context).border.withValues(alpha: 0.2)),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic button — hold to record, release to transcribe
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _startRecording(),
                      onPointerUp: (_) => _stopAndTranscribe(),
                      onPointerCancel: (_) => _stopAndTranscribe(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? Colors.red.withValues(alpha: 0.8)
                              : AppTheme.of(context).surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isRecording
                                ? Colors.red.withValues(alpha: 0.5)
                                : AppTheme.of(context).border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: _isTranscribing
                            ? Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent),
                                ),
                              )
                            : Icon(
                                _isRecording ? Icons.mic : Icons.mic_none,
                                color: _isRecording
                                    ? Colors.white
                                    : AppTheme.of(context).textMuted,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: (_isSending || _voiceBusy) ? null : _send,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          gradient: (_isSending || _voiceBusy)
                              ? null
                              : AppColors.accentGradient,
                          color: (_isSending || _voiceBusy)
                              ? AppTheme.of(context).border.withValues(alpha: 0.3)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (_isSending || _voiceBusy)
                              ? null
                              : [
                                  BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.3),
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
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter to send  ·  Every message is defense-checked before response',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.of(context).textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
