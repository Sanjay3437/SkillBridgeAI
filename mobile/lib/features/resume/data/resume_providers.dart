import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

final resumesProvider = FutureProvider.autoDispose<List<ResumeSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/resumes');
  return ((json['items'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(ResumeSummary.fromJson)
      .toList();
});

/// Polls the detail endpoint while the resume is being processed.
final resumeDetailProvider =
    FutureProvider.autoDispose.family<ResumeDetail, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getJson('/resumes/$id');
  return ResumeDetail.fromJson(json);
});

/// Uploads a PDF and returns the queued resume id.
Future<String> uploadResume(WidgetRef ref, {required List<int> bytes, required String filename}) async {
  final json = await ref.read(apiClientProvider).uploadPdf(
        '/resumes',
        bytes: bytes,
        filename: filename,
      );
  return json['id'] as String;
}

Future<void> deleteResume(WidgetRef ref, String id) async {
  await ref.read(apiClientProvider).delete('/resumes/$id');
}
