import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../analysis/data/analysis_providers.dart';
import '../data/roadmap_providers.dart';

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key, required this.analysisId});

  final String analysisId;

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  final Set<String> _pendingTasks = {};
  bool _generating = false;

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      await generateRoadmap(ref, widget.analysisId);
      ref.invalidate(roadmapForAnalysisProvider(widget.analysisId));
      ref.invalidate(dashboardProvider);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _toggleTask(RoadmapTask task) async {
    if (_pendingTasks.contains(task.id)) return;
    setState(() => _pendingTasks.add(task.id));
    try {
      await updateRoadmapTask(
        ref,
        task.id,
        status: task.isCompleted ? 'pending' : 'completed',
      );
      ref.invalidate(roadmapForAnalysisProvider(widget.analysisId));
      ref.invalidate(dashboardProvider);
    } catch (error) {
      _showMessage('Could not update the task. $error');
    } finally {
      if (mounted) setState(() => _pendingTasks.remove(task.id));
    }
  }

  Future<void> _openResource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('This resource link is invalid.');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _showMessage('Could not open the resource link.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openTaskSheet(RoadmapTask task) {
    final priority = _priorityOf(task.description);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              22 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (task.skill != null)
                        Chip(
                          avatar: const Icon(Icons.psychology_outlined, size: 15),
                          label: Text(task.skill!),
                        ),
                      if (priority != null) PriorityPill(priority: priority),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Suggested steps',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._stepsOf(task.description).map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 5, color: AppColors.indigo),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              step,
                              style: Theme.of(sheetContext).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (task.resourceUrl != null) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _openResource(task.resourceUrl!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open learning resource'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pendingTasks.contains(task.id)
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _toggleTask(task);
                          },
                    icon: Icon(
                      task.isCompleted ? Icons.undo_rounded : Icons.check_rounded,
                      size: 18,
                    ),
                    label: Text(task.isCompleted ? 'Mark as not started' : 'Mark as complete'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String? _priorityOf(String? description) {
    if (description == null) return null;
    final match = RegExp(r'Priority:\s*(high|medium|low)', caseSensitive: false)
        .firstMatch(description);
    return match?.group(1)?.toLowerCase();
  }

  List<String> _stepsOf(String? description) {
    if (description == null || description.trim().isEmpty) return const [];
    final newline = description.indexOf('\n');
    final raw = newline == -1 ? description : description.substring(newline + 1);
    final steps = raw
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*-\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return steps.isEmpty ? [description.trim()] : steps;
  }

  @override
  Widget build(BuildContext context) {
    final provider = roadmapForAnalysisProvider(widget.analysisId);
    final roadmap = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadmap'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: roadmap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          if (error is ApiException && error.isNotFound) {
            return EmptyState(
              icon: Icons.route_outlined,
              title: 'No roadmap yet',
              message:
                  'Generate a plan from this analysis. We create one task for each '
                  'missing or related skill, ordered by priority.',
              action: FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_generating ? 'Building roadmap…' : 'Generate roadmap'),
              ),
            );
          }
          return ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(provider),
          );
        },
        data: (plan) {
          final tasks = plan.tasks;
          final completed = plan.completedCount;
          final allDone = tasks.isNotEmpty && completed == tasks.length;

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
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.indigoDeep, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR BRIDGE PLAN',
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC7D2FE),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tasks.isEmpty
                                  ? 'Nothing to close'
                                  : allDone
                                      ? 'You finished every task'
                                      : 'Keep the momentum',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tasks.isEmpty
                                  ? 'This comparison produced no tasks.'
                                  : '$completed of ${tasks.length} tasks complete',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CoverageRing(
                        percentage: plan.progress * 100,
                        size: 96,
                        label: 'done',
                        trackColor: Colors.white.withValues(alpha: 0.16),
                        progressColors: const [Colors.white, Color(0xFFA7F3D0), Colors.white],
                        textColor: Colors.white,
                        labelColor: const Color(0xFFA7F3D0),
                      ),
                    ],
                  ),
                ),
                if (tasks.isEmpty) ...[
                  const SizedBox(height: 18),
                  EmptyState(
                    icon: Icons.verified_rounded,
                    title: 'No gaps to work on',
                    message:
                        'Every required skill in this comparison already has direct '
                        'evidence in your resume.',
                    action: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back to gap report'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  SectionTitle(
                    title: 'Your tasks',
                    subtitle: 'Tap a task for suggested steps and its resource.',
                    trailing: Text(
                      '${(plan.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TaskCard(
                        task: task,
                        priority: _priorityOf(task.description),
                        pending: _pendingTasks.contains(task.id),
                        onToggle: () => _toggleTask(task),
                        onOpen: () => _openTaskSheet(task),
                        onResource: task.resourceUrl == null
                            ? null
                            : () => _openResource(task.resourceUrl!),
                      ),
                    ),
                  ),
                  if (allDone) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.matchedSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.matched.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.emoji_events_rounded, color: AppColors.matched),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Roadmap complete. Re-upload an updated resume to see how your coverage changes.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: AppColors.matched,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                const InfoCallout(
                  message:
                      'Tasks are generated from this analysis. Resource links are curated, '
                      'not generated by AI, and progress is saved as you check tasks off.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.priority,
    required this.pending,
    required this.onToggle,
    required this.onOpen,
    required this.onResource,
  });

  final RoadmapTask task;
  final String? priority;
  final bool pending;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback? onResource;

  @override
  Widget build(BuildContext context) {
    final completed = task.isCompleted;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: completed ? AppColors.matched.withValues(alpha: 0.35) : AppColors.border,
            ),
            color: completed ? AppColors.matchedSoft.withValues(alpha: 0.35) : Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: InkResponse(
                  onTap: pending ? null : onToggle,
                  radius: 22,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed ? AppColors.matched : Colors.transparent,
                      border: Border.all(
                        color: completed ? AppColors.matched : AppColors.border,
                        width: 1.6,
                      ),
                    ),
                    child: pending
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          )
                        : completed
                            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: completed ? AppColors.muted : AppColors.ink,
                            decoration: completed ? TextDecoration.lineThrough : null,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        if (task.skill != null)
                          _MiniPill(label: task.skill!, color: AppColors.indigo),
                        if (priority != null) PriorityPill(priority: priority!),
                      ],
                    ),
                  ],
                ),
              ),
              if (onResource != null)
                IconButton(
                  tooltip: 'Open resource',
                  onPressed: onResource,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  color: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
