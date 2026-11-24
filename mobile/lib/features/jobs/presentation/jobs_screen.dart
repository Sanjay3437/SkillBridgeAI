import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/job_providers.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Target roles'),
        actions: [
          IconButton(
            tooltip: 'Add a role',
            onPressed: () => context.push('/jobs/new'),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AsyncView(
        value: jobs,
        onRetry: () => ref.invalidate(jobsProvider),
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.work_outline_rounded,
              title: 'Add a target role',
              message:
                  'Paste a job description and we will pull out the required and '
                  'preferred skills, with the sentence that supports each one.',
              action: FilledButton.icon(
                onPressed: () => context.push('/jobs/new'),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add a role'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(jobsProvider);
              await ref.read(jobsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                SectionTitle(
                  title: '${items.length} ${items.length == 1 ? 'role' : 'roles'} in your pipeline',
                  subtitle: 'Each role becomes the target for a gap analysis.',
                ),
                const SizedBox(height: 16),
                ...items.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JobTile(
                      job: job,
                      onTap: () => context.push('/jobs/${job.id}'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.push('/jobs/new'),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add another role'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.onTap});

  final JobSummary job;
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
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.work_outline_rounded, color: AppColors.info, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [if (job.company != null && job.company!.isNotEmpty) job.company!, formatDate(job.createdAt)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: job.status),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
