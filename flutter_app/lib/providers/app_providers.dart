import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ─── 1. authProvider ────────────────────────────────────────────────────────

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── 2. chatProvider ────────────────────────────────────────────────────────

class ChatState {
  final List<Map<String, dynamic>> messages;
  final String? currentPipelineId;
  final bool isLoading;

  const ChatState({
    this.messages = const [],
    this.currentPipelineId,
    this.isLoading = false,
  });

  ChatState copyWith({
    List<Map<String, dynamic>>? messages,
    String? currentPipelineId,
    bool clearPipelineId = false,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      currentPipelineId:
          clearPipelineId ? null : currentPipelineId ?? this.currentPipelineId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState());

  void addMessage(Map<String, dynamic> message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void setPipelineId(String? id) {
    if (id == null) {
      state = state.copyWith(clearPipelineId: true);
    } else {
      state = state.copyWith(currentPipelineId: id);
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

// ─── 3. pipelineProvider ────────────────────────────────────────────────────
// Polls every 2 s until the top-level status is 'done' or 'error' (all 4
// stages — decomposition, reasoning, claims, rag — have been resolved).

final pipelineProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, pipelineId) async {
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  while (!cancelled) {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/pipeline/$pipelineId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status == 'done' || status == 'error') return data;
      }
    } catch (_) {
      // Network hiccup — keep polling
    }

    if (!cancelled) await Future.delayed(const Duration(seconds: 2));
  }

  throw StateError('Pipeline provider disposed before completion');
});

// ─── 4. locationProvider ────────────────────────────────────────────────────
// Listens to users/{child_id}/location/current in Firestore.

final locationProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, childId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(childId)
      .collection('location')
      .doc('current')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return {
      'lat': data['lat'],
      'lng': data['lng'],
      'updated_at': data['updated_at'],
    };
  });
});

// ─── 5. pendingCasesProvider ─────────────────────────────────────────────────

final pendingCasesProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];
  final token = await user.getIdToken();

  final response = await http
      .get(
        Uri.parse('${ApiConfig.baseUrl}/api/pending'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception('Failed to load pending cases: ${response.statusCode}');
  }

  final data = jsonDecode(response.body);
  if (data is List) return data;
  if (data is Map && data['cases'] is List) return data['cases'] as List;
  return [];
});

// ─── 6. adminFlagsProvider ───────────────────────────────────────────────────

final adminFlagsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('admin_flags')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList());
});
