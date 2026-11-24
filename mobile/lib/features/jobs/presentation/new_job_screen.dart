import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/job_providers.dart';

class NewJobScreen extends ConsumerStatefulWidget {
  const NewJobScreen({super.key});

  @override
  ConsumerState<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends ConsumerState<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await createJob(
        ref,
        title: _title.text.trim(),
        company: _company.text,
        description: _description.text.trim(),
      );
      ref.invalidate(jobsProvider);
      if (!mounted) return;
      context.pushReplacement('/jobs/$id');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save the role. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a role')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste the role you are aiming for',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'We read the description and separate required skills from preferred ones. '
                'Nothing is sent anywhere except your configured AI provider.',
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
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Role title',
                  hintText: 'Backend Engineer',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Enter a role title' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _company,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Company (optional)',
                  hintText: 'Acme',
                  prefixIcon: Icon(Icons.business_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                minLines: 9,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Job description',
                  alignLabelWithHint: true,
                  hintText: 'Paste the full posting, including requirements and responsibilities…',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 30) {
                    return 'Paste at least a few sentences (30 characters minimum)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              const InfoCallout(
                message:
                    'Use the original posting text. Paraphrasing can change which '
                    'skills are treated as required.',
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Extract skills'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
