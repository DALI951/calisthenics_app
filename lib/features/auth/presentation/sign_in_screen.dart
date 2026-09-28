import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/backend_status.dart';
import '../../../core/widgets/app_buttons.dart';
import '../data/auth_providers.dart';
import 'auth_scaffold.dart';

/// Sign in with email + password. All errors are user-readable [AppFailure]s.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  AppFailure? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: _email.text.trim(), password: _password.text);
      // Router redirect handles navigation on auth state change.
    } on AppFailure catch (e) {
      setState(() => _error = e);
    } catch (_) {
      setState(() => _error = const NetworkFailure());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final backend = ref.watch(backendStatusProvider);

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to keep your training streak alive.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No account yet?',
            style: Theme.of(context).textTheme.bodyMedium
                ?.apply(color: secondary),
          ),
          TextButton(
            onPressed: _submitting ? null : () => context.push('/auth/sign-up'),
            child: const Text('Create one'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Enter your email.';
                if (!value.contains('@')) return 'That email looks wrong.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              FormErrorText(message: _error!.friendlyMessage),
            ],
            if (backend == BackendStatus.unavailable) ...[
              const SizedBox(height: AppSpacing.md),
              // Honest local-only mode: never fake a working backend.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Local build — no Firebase configured yet. '
                  'You can still browse the app; syncing arrives with '
                  'docs/firebase-setup.md.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.apply(color: secondary),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'Sign in',
              onPressed: _submitting ? null : _submit,
              loading: _submitting,
              icon: Icons.arrow_forward,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => context.push('/auth/forgot'),
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }
}
