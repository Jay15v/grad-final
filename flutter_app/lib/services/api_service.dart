import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/defense_meta.dart';
import '../models/pipeline_state.dart';

const String _baseUrl = 'http://10.0.2.2:5000';

class ChatResponse {
  final String decision;
  final String? reply;
  final DefenseMeta defenseMeta;
  final String? pipelineId;
  final bool rlhfPending;
  final String? verdict;
  final String? displayLabel;
  final double? avgAgreement;
  // Map of model name → "ok" | "error"
  final Map<String, String>? modelStatuses;

  ChatResponse({
    required this.decision,
    required this.reply,
    required this.defenseMeta,
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
    return ChatResponse(
      decision: json['decision'] as String? ?? 'ALLOW',
      reply: json['reply'] as String?,
      defenseMeta: DefenseMeta.fromJson(
          json['defense_meta'] as Map<String, dynamic>? ?? {}),
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
          Uri.parse('$_baseUrl/api/chat'),
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
        .get(Uri.parse('$_baseUrl/api/pipeline/$pipelineId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) return PipelineState.idle();
    if (response.statusCode != 200) {
      throw Exception('Pipeline error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PipelineState.fromJson(data);
  }

  static Future<AnalyzeResponse> analyzePrompt(String prompt) async {
    final token = await getIdToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/analyze'),
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
