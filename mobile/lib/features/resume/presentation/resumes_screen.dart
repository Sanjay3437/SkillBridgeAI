import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/resume_providers.dart';

class ResumesScreen extends ConsumerStatefulWidget {
  const ResumesScreen({super.key});

  @override
  ConsumerState<ResumesScreen> createState() => _ResumesScreenState();
}

class _ResumesScreenState extends ConsumerState<ResumesScreen> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
    } catch (_) {
      _showMessage('Could not open the file picker on this device.');
      return;
    }
    if (files.isEmpty) return;

    final file = files.single;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _showMessage('That PDF is empty. Try another file.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final id = await uploadResume(ref, bytes: bytes, filename: file.name);
      ref.invalidate(resumesProvider);
      if (!mounted) return;
      await context.push('/resumes/$id');
      ref.invalidate(resumesProvider);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final resumes = ref.watch(resumesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumes'),
        actions: [
          IconButton(
            tooltip: 'Upload PDF',
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AsyncView(
        value: resumes,
        onRetry: () => ref.invalidate(resumesProvider),
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.description_outlined,
              title: 'Add your first resume',
              message:
                  'Upload a text-based PDF. We extract skills and keep the exact '
                  'sentence that supports each one.',
              action: FilledButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: Text(_uploading ? 'Uploading…' : 'Upload PDF'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(resumesProvider);
              await ref.read(resumesProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.indigo.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.indigo),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${items.length} ${items.length == 1 ? 'resume' : 'resumes'} stored. '
                          'Only you can see them.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.indigo,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _uploading ? null : _pickAndUpload,
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(
                  title: 'Your documents',
                  subtitle: 'Tap a resume to inspect its extracted evidence.',
                ),
                const SizedBox(height: 14),
                ...items.map(
                  (resume) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ResumeTile(
                      resume: resume,
                      onTap: () => context.push('/resumes/${resume.id}'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const InfoCallout(
                  message:
                      'Scanned or image-only PDFs are rejected because we cannot '
                      'quote evidence from them. Export a text-based PDF instead.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResumeTile extends StatelessWidget {
  const _ResumeTile({required this.resume, required this.onTap});

  final ResumeSummary resume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.indigo, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resume.originalFilename ?? 'Resume',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDate(resume.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: resume.status),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
