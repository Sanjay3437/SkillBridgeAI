import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

/// Loads an existing roadmap. Throws a 404 [ApiException] when none exists yet.
final roadmapForAnalysisProvider =
    FutureProvider.autoDispose.family<Roadmap, String>((ref, analysisId) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/analyses/$analysisId/roadmap');
  return Roadmap.fromJson(json);
});

Future<void> updateRoadmapTask(
  WidgetRef ref,
  String taskId, {
  required String status,
}) async {
  await ref.read(apiClientProvider).patchJson(
        '/roadmap-tasks/$taskId',
        data: {'status': status},
      );
}

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/dashboard');
  return DashboardSummary.fromJson(json);
});
