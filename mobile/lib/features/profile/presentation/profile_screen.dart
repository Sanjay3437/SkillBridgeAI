import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your resumes and analyses stay on your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.missing),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final email = auth.user?.email ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.indigo.withValues(alpha: 0.10),
                  child: Text(
                    initialsFor(email),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in as', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'How matching works',
            subtitle: 'Designed to stay explainable and conservative.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                _HowItem(
                  icon: Icons.rule_rounded,
                  title: 'Deterministic first',
                  text:
                      'Skill aliases are normalized against a curated taxonomy before any AI is involved.',
                ),
                Divider(height: 26),
                _HowItem(
                  icon: Icons.format_quote_rounded,
                  title: 'Evidence must be verbatim',
                  text:
                      'Each match quotes an exact span from your resume. Paraphrased claims are discarded.',
                ),
                Divider(height: 26),
                _HowItem(
                  icon: Icons.link_rounded,
                  title: 'Related is not matched',
                  text:
                      'Adjacent experience is surfaced separately and never counted toward coverage.',
                ),
                Divider(height: 26),
                _HowItem(
                  icon: Icons.shield_outlined,
                  title: 'Absence is not proof',
                  text:
                      'A gap means supporting text was not found, not that you lack the skill.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                    const BrandMark(size: 26, showName: false),
                    const SizedBox(width: 10),
                    Text('SkillBridge AI', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppConfig.disclaimer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _MetaRow(label: 'Version', value: '0.1.0 (MVP)'),
                const SizedBox(height: 8),
                _MetaRow(label: 'API', value: AppConfig.apiBaseUrl),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.missing,
              side: BorderSide(color: AppColors.missing.withValues(alpha: 0.35)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 18),
          Text(
            'Built as a portfolio project. Coverage scores are not hiring predictions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HowItem extends StatelessWidget {
  const _HowItem({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.indigo),
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
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ),
      ],
    );
  }
}
