import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../jobs/data/job_providers.dart';
import '../../resume/data/resume_providers.dart';

class AnalysisInputs {
  const AnalysisInputs({required this.resumes, required this.jobs});

  final List<ResumeSummary> resumes;
  final List<JobSummary> jobs;
}

/// Completed resumes and roles that can be compared.
final analysisInputsProvider = FutureProvider.autoDispose<AnalysisInputs>((ref) async {
  final (resumes, jobs) = await (
    ref.watch(resumesProvider.future),
    ref.watch(jobsProvider.future),
  ).wait;
  return AnalysisInputs(
    resumes: resumes.where((resume) => resume.isCompleted).toList(),
    jobs: jobs.where((job) => job.isCompleted).toList(),
  );
});

final analysesProvider = FutureProvider.autoDispose<List<AnalysisSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/analyses');
  return ((json['items'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(AnalysisSummary.fromJson)
      .toList();
});

/// Polls the analysis until it reaches a terminal state.
final analysisDetailProvider =
    FutureProvider.autoDispose.family<AnalysisDetail, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/analyses/$id');
  return AnalysisDetail.fromJson(json);
});

Future<String> createAnalysis(
  WidgetRef ref, {
  required String resumeId,
  required String jobId,
}) async {
  final json = await ref.read(apiClientProvider).postJson(
        '/analyses',
        data: {'resume_id': resumeId, 'job_id': jobId},
      );
  return json['id'] as String;
}

/// Creates (or returns the existing) roadmap for an analysis.
Future<Roadmap> generateRoadmap(WidgetRef ref, String analysisId) async {
  final json = await ref
      .read(apiClientProvider)
      .postJson('/analyses/$analysisId/roadmap');
  return Roadmap.fromJson(json);
}
