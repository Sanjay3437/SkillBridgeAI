import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../analysis/data/analysis_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../jobs/data/job_providers.dart';
import '../../roadmap/data/roadmap_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(analysesProvider);
    ref.invalidate(jobsProvider);
    try {
      await ref.read(dashboardProvider.future);
    } catch (_) {
      // Errors render inline.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final analyses = ref.watch(analysesProvider);
    final jobs = ref.watch(jobsProvider);
    final user = ref.watch(authControllerProvider).user;

    final summary = dashboard.value;
    final analysisItems = analyses.value ?? const <AnalysisSummary>[];
    final jobTitles = {
      for (final job in jobs.value ?? const <JobSummary>[]) job.id: job.title,
    };
    final name = user?.email.split('@').first ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 30),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.indigo.withValues(alpha: 0.10),
                child: Text(
                  initialsFor(user?.email ?? '?'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              '${_greeting()}, $name',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Here is where your skill bridge stands today.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (dashboard.isLoading && summary == null) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (dashboard.hasError) ...[
              const SizedBox(height: 16),
              ErrorView(
                message: dashboard.error.toString(),
                onRetry: () => ref.invalidate(dashboardProvider),
              ),
            ],
            const SizedBox(height: 20),
            _CoverageHero(
              percentage: summary?.latestCoverage,
              hasAnalysis: analysisItems.isNotEmpty,
              onPrimary: () {
                if (analysisItems.isNotEmpty) {
                  context.push('/analyses/${analysisItems.first.id}');
                } else {
                  context.push('/analyses/new');
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.description_outlined,
                    label: 'Resumes',
                    value: '${summary?.resumes ?? 0}',
                    tint: AppColors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.work_outline_rounded,
                    label: 'Roles',
                    value: '${summary?.jobs ?? 0}',
                    tint: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.insights_outlined,
                    label: 'Analyses',
                    value: '${summary?.analyses ?? 0}',
                    tint: AppColors.related,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.route_outlined,
                    label: 'Roadmaps',
                    value: '${summary?.roadmaps ?? 0}',
                    tint: AppColors.matched,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProgressCard(summary: summary),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/analyses/new'),
                    icon: const Icon(Icons.compare_arrows_rounded, size: 19),
                    label: const Text('New analysis'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/resumes'),
                    icon: const Icon(Icons.upload_file_rounded, size: 19),
                    label: const Text('Add resume'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SectionTitle(
              title: 'Recent analyses',
              subtitle: 'Coverage is measured against required skills only.',
            ),
            const SizedBox(height: 14),
            if (analysisItems.isEmpty)
              _GettingStartedCard(
                onUpload: () => context.go('/resumes'),
                onAnalyze: () => context.push('/analyses/new'),
              )
            else
              ...analysisItems.take(3).map(
                    (analysis) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AnalysisTile(
                        analysis: analysis,
                        jobTitle: jobTitles[analysis.jobId] ?? 'Target role',
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
            const InfoCallout(
              message:
                  'Coverage describes how much of a role\'s required skill set is '
                  'documented in your resume. It is not a hiring probability, and a '
                  'gap is not proof that you lack the skill.',
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageHero extends StatelessWidget {
  const _CoverageHero({
    required this.percentage,
    required this.hasAnalysis,
    required this.onPrimary,
  });

  final double? percentage;
  final bool hasAnalysis;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigoDeep, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'LATEST ANALYSIS',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE0E7FF),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasAnalysis ? 'Your documented coverage' : 'No analysis yet',
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasAnalysis
                      ? 'of required skills in your latest target role'
                      : 'Add a resume and a role to see your first gap report.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: onPrimary,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hasAnalysis ? 'View analysis' : 'Start an analysis'),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CoverageRing(
            percentage: percentage,
            size: 108,
            label: 'coverage',
            trackColor: Colors.white.withValues(alpha: 0.16),
            progressColors: const [Colors.white, Color(0xFFC7D2FE), Colors.white],
            textColor: Colors.white,
            labelColor: const Color(0xFFC7D2FE),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: tint),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final DashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final total = summary?.tasksTotal ?? 0;
    final completed = summary?.tasksCompleted ?? 0;
    final progress = (summary?.completionPercentage ?? 0) / 100;

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
              const Icon(Icons.flag_outlined, size: 18, color: AppColors.matched),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Roadmap progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.matched,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.matched),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0
                ? 'Generate a roadmap from an analysis to start tracking progress.'
                : '$completed of $total tasks complete',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AnalysisTile extends StatelessWidget {
  const _AnalysisTile({required this.analysis, required this.jobTitle});

  final AnalysisSummary analysis;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    final coverage = analysis.coverage;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/analyses/${analysis.id}'),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: analysis.isProcessing
                      ? AppColors.field
                      : AppColors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: analysis.isProcessing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        coverage == null ? '—' : '${coverage.round()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.indigo,
                        ),
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDate(analysis.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: analysis.status),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({required this.onUpload, required this.onAnalyze});

  final VoidCallback onUpload;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your first gap report in three steps',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          const _Step(number: '1', text: 'Upload a text-based PDF resume.'),
          const SizedBox(height: 12),
          const _Step(number: '2', text: 'Paste a job description for a role you want.'),
          const SizedBox(height: 12),
          const _Step(number: '3', text: 'Compare both and get a prioritized roadmap.'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onUpload,
                  child: const Text('Upload resume'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAnalyze,
                  child: const Text('Analyze a role'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.field,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.indigo,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
