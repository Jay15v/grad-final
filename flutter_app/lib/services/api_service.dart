import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/defense_meta.dart';
import '../models/pipeline_state.dart';

const String _baseUrl = 'http://127.0.0.1:5000';

class ChatResponse {
  final String decision;
  final String? reply;
  final DefenseMeta defenseMeta;
  final String? pipelineId;

  ChatResponse({
    required this.decision,
    required this.reply,
    required this.defenseMeta,
    required this.pipelineId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      decision: json['decision'] as String? ?? 'ALLOW',
      reply: json['reply'] as String?,
      defenseMeta: DefenseMeta.fromJson(
          json['defense_meta'] as Map<String, dynamic>? ?? {}),
      pipelineId: json['pipeline_id'] as String?,
    );
  }
}

class AnalyzeResponse {
  final String status;
  final Map<String, dynamic> raw;

  AnalyzeResponse({required this.status, required this.raw});

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return AnalyzeResponse(
      status: json['status'] as String? ?? 'ALLOW',
      raw: json,
    );
  }
}

class ApiService {
  static Future<ChatResponse> sendChat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': message, 'history': history}),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
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
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': prompt}),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AnalyzeResponse.fromJson(data);
  }
}
