import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

final jobsProvider = FutureProvider.autoDispose<List<JobSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/jobs');
  return ((json['items'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(JobSummary.fromJson)
      .toList();
});

/// Polls the detail endpoint while the job description is being processed.
final jobDetailProvider =
    FutureProvider.autoDispose.family<JobDetail, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/jobs/$id');
  return JobDetail.fromJson(json);
});

Future<String> createJob(
  WidgetRef ref, {
  required String title,
  String? company,
  required String description,
}) async {
  final json = await ref.read(apiClientProvider).postJson(
        '/jobs',
        data: {
          'title': title,
          if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
          'description': description,
        },
      );
  return json['id'] as String;
}
