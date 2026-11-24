class JobSkill {
  const JobSkill({
    required this.skill,
    required this.required,
    required this.importance,
    this.evidence,
  });

  final String skill;
  final bool required;
  final double importance;
  final String? evidence;

  factory JobSkill.fromJson(Map<String, dynamic> json) => JobSkill(
        skill: json['skill'] as String,
        required: json['required'] as bool? ?? true,
        importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
        evidence: json['evidence'] as String?,
      );
}

class JobSummary {
  const JobSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.company,
    this.errorMessage,
  });

  final String id;
  final String title;
  final String status;
  final DateTime createdAt;
  final String? company;
  final String? errorMessage;

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory JobSummary.fromJson(Map<String, dynamic> json) => JobSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        company: json['company'] as String?,
        errorMessage: json['error_message'] as String?,
      );
}

class JobDetail extends JobSummary {
  const JobDetail({
    required super.id,
    required super.title,
    required super.status,
    required super.createdAt,
    super.company,
    super.errorMessage,
    this.description = '',
    this.skills = const [],
  });

  final String description;
  final List<JobSkill> skills;

  factory JobDetail.fromJson(Map<String, dynamic> json) => JobDetail(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        company: json['company'] as String?,
        errorMessage: json['error_message'] as String?,
        description: (json['description'] as String?) ?? '',
        skills: ((json['skills'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(JobSkill.fromJson)
            .toList(),
      );
}
