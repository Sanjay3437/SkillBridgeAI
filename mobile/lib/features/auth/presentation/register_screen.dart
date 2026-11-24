import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final message = await ref
        .read(authControllerProvider.notifier)
        .register(_email.text, _password.text);
    if (!mounted) return;
    if (message != null) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'Build your bridge.',
      subtitle:
          'Create an account to turn your resume into a clear, prioritized '
          'learning plan.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Already have an account?', style: Theme.of(context).textTheme.bodyMedium),
          TextButton(
            onPressed: auth.loading ? null : () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create your account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'It takes less than a minute.',
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
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters',
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
                if (value == null || value.length < 8) {
                  return 'Use at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
              ),
              validator: (value) {
                if (value != _password.text) return 'Passwords do not match';
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
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
