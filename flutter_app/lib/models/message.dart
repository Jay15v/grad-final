import 'defense_meta.dart';

enum MessageRole { user, assistant, blocked }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final String? decision;
  final DefenseMeta? defenseMeta;
  final String? pipelineId;
  final bool isLoading;
  final String? verdict;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.decision,
    this.defenseMeta,
    this.pipelineId,
    this.isLoading = false,
    this.verdict,
  });

  ChatMessage copyWith({//safe update pattern when we want to update a message we can use copy with to create a new instance with updated fields
    String? content,
    bool? isLoading,
    String? pipelineId,
    DefenseMeta? defenseMeta,
    String? decision,
    String? verdict,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      decision: decision ?? this.decision,
      defenseMeta: defenseMeta ?? this.defenseMeta,
      pipelineId: pipelineId ?? this.pipelineId,
      isLoading: isLoading ?? this.isLoading,
      verdict: verdict ?? this.verdict,
    );
  }
}
