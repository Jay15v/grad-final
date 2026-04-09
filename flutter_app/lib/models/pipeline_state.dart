class StageEntry {
  final String status; // 'running' | 'done'
  final dynamic data;
  final String? error;

  StageEntry({required this.status, this.data, this.error});

  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';

  factory StageEntry.fromJson(Map<String, dynamic> json) {
    return StageEntry(
      status: json['status'] as String? ?? 'running',
      data: json['data'],
      error: json['error'] as String?,
    );
  }
}

class PipelineStages {
  final StageEntry? decomposition;
  final StageEntry? reasoning;
  final StageEntry? claims;
  final StageEntry? rag;

  PipelineStages({this.decomposition, this.reasoning, this.claims, this.rag});

  factory PipelineStages.fromJson(Map<String, dynamic> json) {
    return PipelineStages(
      decomposition: json['decomposition'] != null
          ? StageEntry.fromJson(json['decomposition'] as Map<String, dynamic>)
          : null,
      reasoning: json['reasoning'] != null
          ? StageEntry.fromJson(json['reasoning'] as Map<String, dynamic>)
          : null,
      claims: json['claims'] != null
          ? StageEntry.fromJson(json['claims'] as Map<String, dynamic>)
          : null,
      rag: json['rag'] != null
          ? StageEntry.fromJson(json['rag'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PipelineState {
  final String status; // 'idle' | 'running' | 'done' | 'error'
  final PipelineStages stages;

  PipelineState({required this.status, required this.stages});

  bool get isDone => status == 'done' || status == 'error';

  factory PipelineState.idle() =>
      PipelineState(status: 'idle', stages: PipelineStages());

  factory PipelineState.fromJson(Map<String, dynamic> json) {
    return PipelineState(
      status: json['status'] as String? ?? 'running',
      stages: json['stages'] != null
          ? PipelineStages.fromJson(json['stages'] as Map<String, dynamic>)
          : PipelineStages(),
    );
  }
}
