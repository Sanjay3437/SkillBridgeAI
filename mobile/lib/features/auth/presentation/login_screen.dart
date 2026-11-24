import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final message = await ref
        .read(authControllerProvider.notifier)
        .login(_email.text, _password.text);
    if (!mounted) return;
    if (message != null) {
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'See the gap.\nClose the gap.',
      subtitle:
          'Upload your resume, add a target role, and get an evidence-backed '
          'map of what to learn next.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('New to SkillBridge?', style: Theme.of(context).textTheme.bodyMedium),
          TextButton(
            onPressed: auth.loading ? null : () => context.go('/register'),
            child: const Text('Create an account'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome back', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sign in to continue building your roadmap.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (_error != null) AuthErrorBanner(message: _error!),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Enter your email';
                if (!text.contains('@') || !text.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter your password';
                return null;
              },
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: auth.loading ? null : _submit,
              child: auth.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 15, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your resume is used only to generate your analysis.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
