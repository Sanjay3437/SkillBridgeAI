import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../roadmap/data/roadmap_providers.dart';
import '../data/analysis_providers.dart';

class AnalysisDetailScreen extends ConsumerStatefulWidget {
  const AnalysisDetailScreen({super.key, required this.analysisId});

  final String analysisId;

  @override
  ConsumerState<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends ConsumerState<AnalysisDetailScreen> {
  Timer? _pollTimer;
  bool _buildingRoadmap = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      final detail = ref.read(analysisDetailProvider(widget.analysisId)).value;
      if (detail != null && detail.isProcessing) {
        ref.invalidate(analysisDetailProvider(widget.analysisId));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _buildRoadmap() async {
    if (_buildingRoadmap) return;
    setState(() => _buildingRoadmap = true);
    try {
      await generateRoadmap(ref, widget.analysisId);
      ref.invalidate(roadmapForAnalysisProvider(widget.analysisId));
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      await context.push('/analyses/${widget.analysisId}/roadmap');
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _buildingRoadmap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = analysisDetailProvider(widget.analysisId);
    final analysis = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gap report'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AsyncView(
        value: analysis,
        onRetry: () => ref.invalidate(provider),
        builder: (detail) {
          if (detail.isProcessing) return _ProcessingBody(detail: detail);
          if (detail.isFailed) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Analysis failed',
              message: detail.errorMessage ??
                  'Something went wrong while comparing the documents.',
              action: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            );
          }
          return _ReportBody(
            detail: detail,
            buildingRoadmap: _buildingRoadmap,
            onBuildRoadmap: _buildRoadmap,
            onRefresh: () async {
              ref.invalidate(provider);
              await ref.read(provider.future);
            },
          );
        },
      ),
    );
  }
}

class _ProcessingBody extends StatelessWidget {
  const _ProcessingBody({required this.detail});

  final AnalysisDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
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
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              ),
              const SizedBox(height: 18),
              const Text(
                'Analyzing your evidence',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This usually takes a few seconds. You can leave this screen and '
                'come back from Home.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _ProcessStep(
          icon: Icons.tune_rounded,
          title: 'Normalizing skills',
          text: 'Aliases like “ReactJS” and “React.js” resolve to one skill.',
        ),
        const SizedBox(height: 10),
        const _ProcessStep(
          icon: Icons.manage_search_rounded,
          title: 'Matching evidence',
          text: 'Every required skill is checked against your resume text.',
        ),
        const SizedBox(height: 10),
        const _ProcessStep(
          icon: Icons.percent_rounded,
          title: 'Scoring coverage',
          text: 'Only directly evidenced required skills count toward coverage.',
        ),
        const SizedBox(height: 18),
        const InfoCallout(
          message:
              'Related experience is reported separately. It is never upgraded to a '
              'match without direct evidence.',
        ),
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.detail,
    required this.buildingRoadmap,
    required this.onBuildRoadmap,
    required this.onRefresh,
  });

  final AnalysisDetail detail;
  final bool buildingRoadmap;
  final VoidCallback onBuildRoadmap;
  final Future<void> Function() onRefresh;

  static int _rank(String priority) => switch (priority) {
        'high' => 0,
        'medium' => 1,
        _ => 2,
      };

  @override
  Widget build(BuildContext context) {
    final coverage = detail.coverage;
    final matched = detail.matchedSkills;
    final gaps = [...detail.missingSkills]..sort((a, b) => _rank(a.priority).compareTo(_rank(b.priority)));
    final related = [...detail.relatedSkills]..sort((a, b) => _rank(a.priority).compareTo(_rank(b.priority)));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              StatusPill(status: detail.status),
              const SizedBox(width: 8),
              Text(
                formatDate(detail.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (detail.modelVersion != null)
                Text(
                  detail.modelVersion!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CoverageRing(
                  percentage: coverage?.percentage,
                  size: 116,
                  label: 'coverage',
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Required skills documented',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        coverage == null
                            ? 'No required skills identified'
                            : '${coverage.matchedRequired} of ${coverage.totalRequired}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coverage == null
                            ? 'The role had no required skills to score.'
                            : 'required skills have direct resume evidence.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CountCard(
                  value: matched.length,
                  label: 'Matched',
                  color: AppColors.matched,
                  soft: AppColors.matchedSoft,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountCard(
                  value: gaps.length,
                  label: 'Gaps',
                  color: AppColors.missing,
                  soft: AppColors.missingSoft,
                  icon: Icons.error_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountCard(
                  value: related.length,
                  label: 'Related',
                  color: AppColors.related,
                  soft: AppColors.relatedSoft,
                  icon: Icons.link_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Counts include required and preferred skills. Coverage counts required skills only.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Matched with evidence',
            subtitle: 'Direct support found in your resume.',
            color: AppColors.matched,
            icon: Icons.check_circle_rounded,
            emptyMessage: 'No required skills are directly evidenced yet.',
            children: [
              for (final skill in matched)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MatchedCard(skill: skill),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Gaps to close',
            subtitle: 'Required or preferred skills without direct evidence.',
            color: AppColors.missing,
            icon: Icons.error_rounded,
            emptyMessage: 'No gaps found in this comparison.',
            children: [
              for (final skill in gaps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GapCard(skill: skill, color: AppColors.missing, icon: Icons.trending_up_rounded),
                ),
            ],
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Section(
              title: 'Related experience',
              subtitle: 'Adjacent evidence. Not counted as a match.',
              color: AppColors.related,
              icon: Icons.link_rounded,
              emptyMessage: '',
              children: [
                for (final skill in related)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GapCard(skill: skill, color: AppColors.related, icon: Icons.link_rounded),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _RoadmapCard(building: buildingRoadmap, onPressed: onBuildRoadmap),
          const SizedBox(height: 14),
          const InfoCallout(
            message:
                'Coverage is not a hiring probability. A gap means supporting text was '
                'not found in this resume, not that you lack the skill.',
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.value,
    required this.label,
    required this.color,
    required this.soft,
    required this.icon,
  });

  final int value;
  final String label;
  final Color color;
  final Color soft;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: color,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (children.isEmpty && emptyMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(emptyMessage, style: Theme.of(context).textTheme.bodySmall),
          )
        else
          ...children,
      ],
    );
  }
}

class _MatchedCard extends StatelessWidget {
  const _MatchedCard({required this.skill});

  final MatchedSkill skill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                'MATCHED',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.matched,
                ),
              ),
            ],
          ),
          if (skill.evidence != null && skill.evidence!.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: const BoxDecoration(
                color: AppColors.field,
                border: Border(left: BorderSide(color: AppColors.matched, width: 3)),
              ),
              child: Text(
                '“${skill.evidence!.trim()}”',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.slate,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GapCard extends StatelessWidget {
  const _GapCard({required this.skill, required this.color, required this.icon});

  final GapSkill skill;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(skill.skill, style: Theme.of(context).textTheme.titleMedium),
              ),
              PriorityPill(priority: skill.priority),
            ],
          ),
          if (skill.reason != null && skill.reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              skill.reason!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.building, required this.onPressed});

  final bool building;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.route_rounded, color: AppColors.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turn these gaps into a plan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One task per missing or related skill, ordered by priority, with a curated resource.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: building ? null : onPressed,
            icon: building
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(building ? 'Building roadmap…' : 'Build my roadmap'),
          ),
        ],
      ),
    );
  }
}
