import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/defense_meta.dart';
import '../models/pipeline_state.dart';
import '../config/api_config.dart';

class ChatResponse {
  final String? decision;
  final String? reply;
  final DefenseMeta? defenseMeta;
  final String? pipelineId;
  final bool rlhfPending;
  final String? verdict;
  final String? displayLabel;
  final double? avgAgreement;
  final Map<String, String>? modelStatuses;

  ChatResponse({
    this.decision,
    required this.reply,
    this.defenseMeta,
    required this.pipelineId,
    this.rlhfPending = false,
    this.verdict,
    this.displayLabel,
    this.avgAgreement,
    this.modelStatuses,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    Map<String, String>? statuses;
    if (json['model_statuses'] is Map) {
      statuses = (json['model_statuses'] as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    final rawMeta = json['defense_meta'];
    return ChatResponse(
      decision: json['decision'] as String?,
      reply: json['reply'] as String?,
      defenseMeta: rawMeta is Map<String, dynamic>
          ? DefenseMeta.fromJson(rawMeta)
          : null,
      pipelineId: json['pipeline_id'] as String?,
      rlhfPending: json['rlhf_pending'] as bool? ?? false,
      verdict: json['verdict'] as String?,
      displayLabel: json['display_label'] as String?,
      avgAgreement: (json['avg_agreement'] as num?)?.toDouble(),
      modelStatuses: statuses,
    );
  }
}

class AnalyzeResponse {
  final String status;
  final Map<String, dynamic> raw;
  final dynamic caseId;
  final bool rlhfPending;

  AnalyzeResponse({
    required this.status,
    required this.raw,
    this.caseId,
    this.rlhfPending = false,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return AnalyzeResponse(
      status: json['status'] as String? ?? 'ALLOW',
      raw: json,
      caseId: json['case_id'],
      rlhfPending: json['rlhf_pending'] ?? false,
    );
  }
}

class ApiService {
  static Future<String?> getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (e) {
      return null;
    }
  }

  static Future<ChatResponse> sendChat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final token = await getIdToken();
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/chat'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'message': message, 'history': history}),
        )
        .timeout(const Duration(seconds: 150));

    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print("DEBUG flutter received: ${data['verdict']}");
    return ChatResponse.fromJson(data);
  }

  static Future<PipelineState> getPipelineStatus(String pipelineId) async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/pipeline/$pipelineId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) return PipelineState.idle();
    if (response.statusCode != 200) {
      throw Exception('Pipeline error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PipelineState.fromJson(data);
  }

  static Future<void> rateMessage({
    required String message,
    required String sessionId,
    required String userId,
    required String rating,
  }) async {
    try {
      final token = await getIdToken();
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/message_rating'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'message': message,
              'session_id': sessionId,
              'user_id': userId,
              'rating': rating,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<AnalyzeResponse> analyzePrompt(String prompt) async {
    final token = await getIdToken();
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/analyze'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'prompt': prompt}),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    return AnalyzeResponse.fromJson(responseData);
  }
}
