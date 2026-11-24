class RoadmapTask {
  const RoadmapTask({
    required this.id,
    required this.title,
    required this.status,
    required this.sortOrder,
    this.description,
    this.resourceUrl,
    this.skill,
  });

  final String id;
  final String title;
  final String status;
  final int sortOrder;
  final String? description;
  final String? resourceUrl;
  final String? skill;

  bool get isCompleted => status == 'completed';

  factory RoadmapTask.fromJson(Map<String, dynamic> json) => RoadmapTask(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String? ?? 'pending',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        description: json['description'] as String?,
        resourceUrl: json['resource_url'] as String?,
        skill: json['skill'] as String?,
      );
}

class Roadmap {
  const Roadmap({
    required this.id,
    required this.analysisId,
    required this.createdAt,
    required this.tasks,
  });

  final String id;
  final String analysisId;
  final DateTime createdAt;
  final List<RoadmapTask> tasks;

  int get completedCount => tasks.where((task) => task.isCompleted).length;
  double get progress => tasks.isEmpty ? 0 : completedCount / tasks.length;

  factory Roadmap.fromJson(Map<String, dynamic> json) => Roadmap(
        id: json['id'] as String,
        analysisId: json['analysis_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        tasks: ((json['tasks'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RoadmapTask.fromJson)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
}

class DashboardSummary {
  const DashboardSummary({
    required this.resumes,
    required this.jobs,
    required this.analyses,
    required this.roadmaps,
    required this.tasksTotal,
    required this.tasksCompleted,
    required this.completionPercentage,
    this.latestCoverage,
  });

  final int resumes;
  final int jobs;
  final int analyses;
  final int roadmaps;
  final int tasksTotal;
  final int tasksCompleted;
  final double completionPercentage;
  final double? latestCoverage;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        resumes: (json['resumes'] as num?)?.toInt() ?? 0,
        jobs: (json['jobs'] as num?)?.toInt() ?? 0,
        analyses: (json['analyses'] as num?)?.toInt() ?? 0,
        roadmaps: (json['roadmaps'] as num?)?.toInt() ?? 0,
        tasksTotal: (json['tasks_total'] as num?)?.toInt() ?? 0,
        tasksCompleted: (json['tasks_completed'] as num?)?.toInt() ?? 0,
        completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0,
        latestCoverage: (json['latest_coverage'] as num?)?.toDouble(),
      );
}
