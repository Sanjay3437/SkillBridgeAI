import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/analysis_providers.dart';

class NewAnalysisScreen extends ConsumerStatefulWidget {
  const NewAnalysisScreen({super.key, this.initialResumeId, this.initialJobId});

  final String? initialResumeId;
  final String? initialJobId;

  @override
  ConsumerState<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends ConsumerState<NewAnalysisScreen> {
  String? _resumeId;
  String? _jobId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resumeId = widget.initialResumeId;
    _jobId = widget.initialJobId;
  }

  Future<void> _submit(String resumeId, String jobId) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await createAnalysis(ref, resumeId: resumeId, jobId: jobId);
      ref.invalidate(analysesProvider);
      if (!mounted) return;
      context.pushReplacement('/analyses/$id');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start the analysis. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputs = ref.watch(analysisInputsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New analysis')),
      body: AsyncView(
        value: inputs,
        onRetry: () => ref.invalidate(analysisInputsProvider),
        builder: (data) {
          if (data.resumes.isEmpty || data.jobs.isEmpty) {
            return _MissingInputs(resumesMissing: data.resumes.isEmpty, jobsMissing: data.jobs.isEmpty);
          }

          final resumeId = data.resumes.any((resume) => resume.id == _resumeId)
              ? _resumeId!
              : data.resumes.first.id;
          final jobId =
              data.jobs.any((job) => job.id == _jobId) ? _jobId! : data.jobs.first.id;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                'Compare your evidence',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'We match your documented skills against the role, then show what '
                'is evidenced, what is related, and what is missing.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.missingSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.missing.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 13, color: AppColors.missing),
                  ),
                ),
              ],
              _StepCard(
                number: '1',
                title: 'Choose a resume',
                child: DropdownButtonFormField<String>(
                  initialValue: resumeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                  items: [
                    for (final resume in data.resumes)
                      DropdownMenuItem(
                        value: resume.id,
                        child: Text(
                          resume.originalFilename ?? 'Resume',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _resumeId = value),
                ),
              ),
              const SizedBox(height: 14),
              _StepCard(
                number: '2',
                title: 'Choose a target role',
                child: DropdownButtonFormField<String>(
                  initialValue: jobId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                  ),
                  items: [
                    for (final job in data.jobs)
                      DropdownMenuItem(
                        value: job.id,
                        child: Text(
                          job.company == null || job.company!.isEmpty
                              ? job.title
                              : '${job.title} · ${job.company}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _jobId = value),
                ),
              ),
              const SizedBox(height: 14),
              Container(
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
                        const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.indigo),
                        const SizedBox(width: 8),
                        Text('What you will get', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _Bullet(
                      icon: Icons.verified_outlined,
                      title: 'Evidence-linked matches',
                      text: 'Every match points to the sentence in your resume.',
                    ),
                    const SizedBox(height: 12),
                    const _Bullet(
                      icon: Icons.link_rounded,
                      title: 'Related experience, kept separate',
                      text: 'Adjacent skills are surfaced but never counted as matches.',
                    ),
                    const SizedBox(height: 12),
                    const _Bullet(
                      icon: Icons.route_outlined,
                      title: 'A prioritized roadmap',
                      text: 'One task per gap, with a curated learning resource.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const InfoCallout(
                message:
                    'Coverage counts required skills that have direct resume evidence. '
                    'A gap means evidence was not found, not that the skill is absent.',
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _submitting ? null : () => _submit(resumeId, jobId),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.compare_arrows_rounded, size: 19),
                label: Text(_submitting ? 'Starting analysis…' : 'Run gap analysis'),
              ),
              const SizedBox(height: 10),
              Text(
                'Latest documents selected automatically. You can change them above.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.title, required this.child});

  final String number;
  final String title;
  final Widget child;

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
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.indigo,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.matched),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  )),
              Text(text, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissingInputs extends StatelessWidget {
  const _MissingInputs({required this.resumesMissing, required this.jobsMissing});

  final bool resumesMissing;
  final bool jobsMissing;

  @override
  Widget build(BuildContext context) {
    final both = resumesMissing && jobsMissing;
    return EmptyState(
      icon: Icons.compare_arrows_rounded,
      title: both ? 'Add both inputs first' : (resumesMissing ? 'Add a resume first' : 'Add a role first'),
      message: both
          ? 'An analysis needs one processed resume and one processed role description.'
          : (resumesMissing
              ? 'Upload a text-based PDF resume so we have evidence to match.'
              : 'Paste a target role so we know which skills to check.'),
      action: Column(
        children: [
          if (resumesMissing)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/resumes'),
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: const Text('Go to resumes'),
              ),
            ),
          if (resumesMissing && jobsMissing) const SizedBox(height: 10),
          if (jobsMissing)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/jobs/new'),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add a role'),
              ),
            ),
        ],
      ),
    );
  }
}
