import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/resume_providers.dart';

class ResumeDetailScreen extends ConsumerStatefulWidget {
  const ResumeDetailScreen({super.key, required this.resumeId});

  final String resumeId;

  @override
  ConsumerState<ResumeDetailScreen> createState() => _ResumeDetailScreenState();
}

class _ResumeDetailScreenState extends ConsumerState<ResumeDetailScreen> {
  Timer? _pollTimer;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      final detail = ref.read(resumeDetailProvider(widget.resumeId)).value;
      if (detail != null && detail.isProcessing) {
        ref.invalidate(resumeDetailProvider(widget.resumeId));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this resume?'),
        content: const Text(
          'Its skills and any analyses that used it will no longer be available.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.missing),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _deleting) return;
    setState(() => _deleting = true);
    try {
      await deleteResume(ref, widget.resumeId);
      ref.invalidate(resumesProvider);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = resumeDetailProvider(widget.resumeId);
    final resume = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume'),
        actions: [
          IconButton(
            tooltip: 'Delete resume',
            onPressed: _deleting ? null : _confirmDelete,
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AsyncView(
        value: resume,
        onRetry: () => ref.invalidate(provider),
        builder: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            await ref.read(provider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _HeaderCard(resume: detail),
              if (detail.isProcessing) ...[
                const SizedBox(height: 16),
                _ProcessingCard(
                  title: 'Reading your resume',
                  message: 'Extracting skills and verifying each quote against the source text.',
                  progress: detail.status == 'queued' ? null : 0.6,
                ),
              ],
              if (detail.isFailed) ...[
                const SizedBox(height: 16),
                InfoCallout(
                  icon: Icons.error_outline_rounded,
                  message: detail.errorMessage ?? 'Processing failed. Try uploading the PDF again.',
                ),
              ],
              if (detail.isCompleted) ...[
                const SizedBox(height: 24),
                SectionTitle(
                  title: 'Skills with evidence',
                  subtitle:
                      '${detail.skills.length} ${detail.skills.length == 1 ? 'skill' : 'skills'} '
                      'found. Every quote is verbatim from your resume.',
                ),
                const SizedBox(height: 14),
                if (detail.skills.isEmpty)
                  const InfoCallout(
                    message:
                        'No recognized skills were found. Try a resume with a skills '
                        'section or project descriptions.',
                  )
                else
                  ...detail.skills.map(
                    (skill) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EvidenceCard(skill: skill),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.push('/analyses/new?resumeId=${detail.id}'),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 19),
                  label: const Text('Analyze against a role'),
                ),
                const SizedBox(height: 14),
                const InfoCallout(
                  message:
                      'A missing skill means we did not find supporting text, not that '
                      'you lack the skill. Add concrete evidence to your resume and re-upload.',
                ),
              ],
              if (detail.extractedText != null && detail.extractedText!.isNotEmpty) ...[
                const SizedBox(height: 18),
                _ExtractedText(text: detail.extractedText!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.resume});

  final ResumeDetail resume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.indigo),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 4),
                Text(
                  'Uploaded ${formatDate(resume.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(status: resume.status),
        ],
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({
    required this.title,
    required this.message,
    this.progress,
  });

  final String title;
  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.skill});

  final SkillEvidence skill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.matched),
              const SizedBox(width: 7),
              Expanded(
                child: Text(skill.skill, style: Theme.of(context).textTheme.titleMedium),
              ),
              const Text(
                'EVIDENCED',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.matched,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: AppColors.field,
              border: Border(left: BorderSide(color: AppColors.indigo, width: 3)),
            ),
            child: Text(
              '“${skill.evidence.trim()}”',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: AppColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractedText extends StatelessWidget {
  const _ExtractedText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('Extracted text', style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
            'The source we verify evidence against',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          iconColor: AppColors.indigo,
          collapsedIconColor: AppColors.muted,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 12, height: 1.55, color: AppColors.slate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
