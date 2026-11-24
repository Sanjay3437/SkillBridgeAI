import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/job_providers.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      final detail = ref.read(jobDetailProvider(widget.jobId)).value;
      if (detail != null && detail.isProcessing) {
        ref.invalidate(jobDetailProvider(widget.jobId));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = jobDetailProvider(widget.jobId);
    final job = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Role')),
      body: AsyncView(
        value: job,
        onRetry: () => ref.invalidate(provider),
        builder: (detail) {
          final required = detail.skills.where((skill) => skill.required).toList();
          final preferred = detail.skills.where((skill) => !skill.required).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
              await ref.read(provider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.indigoDeep, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      if (detail.company != null && detail.company!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail.company!,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _HeroStat(
                            value: '${required.length}',
                            label: 'required',
                          ),
                          const SizedBox(width: 22),
                          _HeroStat(
                            value: '${preferred.length}',
                            label: 'preferred',
                          ),
                          const Spacer(),
                          StatusPill(
                            status: detail.status,
                            label: detail.isProcessing ? 'Processing' : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (detail.isProcessing) ...[
                  const SizedBox(height: 16),
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
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Reading the job description',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 6),
                        ),
                      ],
                    ),
                  ),
                ],
                if (detail.isFailed) ...[
                  const SizedBox(height: 16),
                  InfoCallout(
                    icon: Icons.error_outline_rounded,
                    message: detail.errorMessage ?? 'Could not process this role.',
                  ),
                ],
                if (detail.isCompleted) ...[
                  const SizedBox(height: 24),
                  SectionTitle(
                    title: 'Required skills',
                    subtitle: 'These drive the coverage score.',
                  ),
                  const SizedBox(height: 12),
                  if (required.isEmpty)
                    const InfoCallout(message: 'No required skills were recognized.')
                  else
                    ...required.map(
                      (skill) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SkillRow(skill: skill, required: true),
                      ),
                    ),
                  if (preferred.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SectionTitle(
                      title: 'Preferred skills',
                      subtitle: 'Nice to have. Not counted in coverage.',
                    ),
                    const SizedBox(height: 12),
                    ...preferred.map(
                      (skill) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SkillRow(skill: skill, required: false),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => context.push('/analyses/new?jobId=${detail.id}'),
                    icon: const Icon(Icons.compare_arrows_rounded, size: 19),
                    label: const Text('Analyze with a resume'),
                  ),
                  const SizedBox(height: 14),
                  const InfoCallout(
                    message:
                        'Required and preferred labels are inferred from wording in the '
                        'posting. Always check the original description.',
                  ),
                ],
                const SizedBox(height: 24),
                _DescriptionCard(description: detail.description, createdAt: detail.createdAt),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.3,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill, required this.required});

  final JobSkill skill;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: required ? AppColors.indigo.withValues(alpha: 0.08) : AppColors.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              required ? Icons.priority_high_rounded : Icons.star_outline_rounded,
              size: 17,
              color: required ? AppColors.indigo : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skill.skill,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      required ? 'REQUIRED' : 'PREFERRED',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w700,
                        color: required ? AppColors.indigo : AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (skill.evidence != null && skill.evidence!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '“${skill.evidence!.trim()}”',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description, required this.createdAt});

  final String description;
  final DateTime createdAt;

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
          title: Text('Original description', style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
            'Added ${formatDate(createdAt)}',
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
                description,
                style: const TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.slate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
