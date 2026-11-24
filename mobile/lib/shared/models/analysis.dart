class Coverage {
  const Coverage({
    required this.matchedRequired,
    required this.totalRequired,
    this.percentage,
  });

  final int matchedRequired;
  final int totalRequired;
  final double? percentage;

  factory Coverage.fromJson(Map<String, dynamic> json) => Coverage(
        matchedRequired: (json['matched_required'] as num?)?.toInt() ?? 0,
        totalRequired: (json['total_required'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble(),
      );
}

class MatchedSkill {
  const MatchedSkill({
    required this.skill,
    required this.confidence,
    this.evidence,
  });

  final String skill;
  final double confidence;
  final String? evidence;

  factory MatchedSkill.fromJson(Map<String, dynamic> json) => MatchedSkill(
        skill: json['skill'] as String,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        evidence: json['evidence'] as String?,
      );
}

class GapSkill {
  const GapSkill({
    required this.skill,
    required this.priority,
    required this.status,
    this.reason,
  });

  final String skill;
  final String priority;
  final String status;
  final String? reason;

  factory GapSkill.fromJson(Map<String, dynamic> json) => GapSkill(
        skill: json['skill'] as String,
        priority: json['priority'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'not_evidenced',
        reason: json['reason'] as String?,
      );
}

class AnalysisSummary {
  const AnalysisSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.resumeId,
    required this.jobId,
    this.coverage,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final String resumeId;
  final String jobId;
  final double? coverage;

  bool get isProcessing => status == 'queued' || status == 'processing';

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) => AnalysisSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        resumeId: json['resume_id'] as String,
        jobId: json['job_id'] as String,
        coverage: (json['coverage'] as num?)?.toDouble(),
      );
}

class AnalysisDetail {
  const AnalysisDetail({
    required this.id,
    required this.status,
    required this.createdAt,
    this.coverage,
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.relatedSkills = const [],
    this.modelVersion,
    this.errorMessage,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final Coverage? coverage;
  final List<MatchedSkill> matchedSkills;
  final List<GapSkill> missingSkills;
  final List<GapSkill> relatedSkills;
  final String? modelVersion;
  final String? errorMessage;

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory AnalysisDetail.fromJson(Map<String, dynamic> json) {
    final coverageJson = json['coverage'];
    return AnalysisDetail(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      coverage: coverageJson is Map<String, dynamic> ? Coverage.fromJson(coverageJson) : null,
      matchedSkills: ((json['matched_skills'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MatchedSkill.fromJson)
          .toList(),
      missingSkills: ((json['missing_skills'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GapSkill.fromJson)
          .toList(),
      relatedSkills: ((json['related_skills'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GapSkill.fromJson)
          .toList(),
      modelVersion: json['model_version'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }
}
