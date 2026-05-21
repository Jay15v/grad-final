class DefenseMeta {
  final String decision;
  final double bertRisk;
  final String semanticDomain;
  final double semanticSimilarity;
  final double finalRisk;
  final double ragBoost;
  final int ragCasesFound;

  DefenseMeta({
    required this.decision,
    required this.bertRisk,
    required this.semanticDomain,
    required this.semanticSimilarity,
    required this.finalRisk,
    this.ragBoost = 0.0,
    this.ragCasesFound = 0,
  });

  factory DefenseMeta.fromJson(Map<String, dynamic> json) {
    return DefenseMeta(
      decision: json['decision'] as String? ?? 'ALLOW',
      bertRisk: (json['bert_risk'] as num?)?.toDouble() ?? 0.0,
      semanticDomain: json['semantic_domain'] as String? ?? '',
      semanticSimilarity: (json['semantic_similarity'] as num?)?.toDouble() ?? 0.0,
      finalRisk: (json['final_risk'] as num?)?.toDouble() ?? 0.0,
      ragBoost: (json['rag_boost'] as num?)?.toDouble() ?? 0.0,
      ragCasesFound: (json['rag_cases_found'] as num?)?.toInt() ?? 0,
    );
  }

  int get riskPercent => (finalRisk * 100).round();
  int get bertPercent => (bertRisk * 100).round();
  int get semanticPercent => (semanticSimilarity * 100).round();
  String get domainReadable => semanticDomain.replaceAll('_', ' ');
}
