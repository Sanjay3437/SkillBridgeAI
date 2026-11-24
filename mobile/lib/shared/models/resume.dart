class SkillEvidence {
  const SkillEvidence({
    required this.skill,
    required this.evidence,
    required this.confidence,
  });

  final String skill;
  final String evidence;
  final double confidence;

  factory SkillEvidence.fromJson(Map<String, dynamic> json) => SkillEvidence(
        skill: json['skill'] as String,
        evidence: (json['evidence'] as String?) ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

class ResumeSummary {
  const ResumeSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.originalFilename,
    this.errorMessage,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final String? originalFilename;
  final String? errorMessage;

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory ResumeSummary.fromJson(Map<String, dynamic> json) => ResumeSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        originalFilename: json['original_filename'] as String?,
        errorMessage: json['error_message'] as String?,
      );
}

class ResumeDetail extends ResumeSummary {
  const ResumeDetail({
    required super.id,
    required super.status,
    required super.createdAt,
    super.originalFilename,
    super.errorMessage,
    this.extractedText,
    this.skills = const [],
  });

  final String? extractedText;
  final List<SkillEvidence> skills;

  factory ResumeDetail.fromJson(Map<String, dynamic> json) => ResumeDetail(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        originalFilename: json['original_filename'] as String?,
        errorMessage: json['error_message'] as String?,
        extractedText: json['extracted_text'] as String?,
        skills: ((json['skills'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SkillEvidence.fromJson)
            .toList(),
      );
}
