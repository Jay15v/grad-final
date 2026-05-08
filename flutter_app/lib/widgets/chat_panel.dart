import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/api_config.dart';
import '../models/message.dart';
import '../models/defense_meta.dart';
import '../services/api_service.dart';
import 'message_bubble.dart';
import 'app_colors.dart';

class ChatPanel extends StatefulWidget {
  final void Function(
    String pipelineId,
    DefenseMeta meta, {
    String? verdict,
    String? displayLabel,
    double? avgAgreement,
    Map<String, String>? modelStatuses,
  }) onPipelineUpdate;

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isSending = false;
  bool _rlhfPending = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _stopRequested = false;

  bool _hasAiResponded = false;
  bool _feedbackSubmitted = false;
  final String _sessionId =
      'session_${DateTime.now().millisecondsSinceEpoch}';
  String? _currentPipelineId;
  String? _currentVerdict;
  String? _lastUserMessage;

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
      _lastUserMessage = text;
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

        _hasAiResponded = true;
        if (response.decision == 'BLOCK') {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            role: MessageRole.blocked,
            content: '',
            decision: 'BLOCK',
            defenseMeta: response.defenseMeta,
          ));
          widget.onPipelineUpdate('blocked-$userMsgId', response.defenseMeta);
        } else {
          _currentPipelineId = response.pipelineId;
          _currentVerdict = response.verdict;
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            role: MessageRole.assistant,
            content: response.reply ?? '(no response)',
            decision: response.decision,
            defenseMeta: response.defenseMeta,
            pipelineId: response.pipelineId,
            verdict: response.verdict,
          ));
          if (response.pipelineId != null) {
            widget.onPipelineUpdate(
              response.pipelineId!,
              response.defenseMeta,
              verdict: response.verdict,
              displayLabel: response.displayLabel,
              avgAgreement: response.avgAgreement,
              modelStatuses: response.modelStatuses,
            );
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

  // ── Session feedback ───────────────────────────────────────────────────────

  Future<void> _submitFeedback(String rating) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous';

    setState(() => _feedbackSubmitted = true);

    try {
      await FirebaseFirestore.instance
          .collection('session_feedback')
          .doc(_sessionId)
          .set({
        'session_id': _sessionId,
        'user_id': userId,
        'rating': rating,
        'verdict': _currentVerdict,
        'pipeline_id': _currentPipelineId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    try {
      final token = await ApiService.getIdToken();
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/feedback'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'session_id': _sessionId,
              'user_id': userId,
              'rating': rating,
              'verdict': _currentVerdict,
              'pipeline_id': _currentPipelineId,
              'message': _lastUserMessage,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rating == 'good'
            ? 'Thanks! Glad it was helpful.'
            : 'Thanks for your feedback.'),
        backgroundColor: rating == 'good'
            ? AppColors.success.withValues(alpha: 0.9)
            : AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _ratingButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
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

        // Session feedback bar
        if (_hasAiResponded)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.4)),
            ),
            child: _feedbackSubmitted
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Thanks for your feedback!',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text(
                        'Rate this session',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                      const Spacer(),
                      _ratingButton(
                        icon: Icons.thumb_up_outlined,
                        label: 'Good',
                        color: AppColors.success,
                        onTap: () => _submitFeedback('good'),
                      ),
                      const SizedBox(width: 8),
                      _ratingButton(
                        icon: Icons.thumb_down_outlined,
                        label: 'Bad',
                        color: AppColors.danger,
                        onTap: () => _submitFeedback('bad'),
                      ),
                    ],
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
                      enabled: !_isSending && !_voiceBusy,
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
                              ? Colors.red.withOpacity(0.8)
                              : AppColors.surface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isRecording
                                ? Colors.red.withOpacity(0.5)
                                : AppColors.border.withOpacity(0.5),
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
                                    : AppColors.textMuted,
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
                              ? AppColors.border.withOpacity(0.3)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (_isSending || _voiceBusy)
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
