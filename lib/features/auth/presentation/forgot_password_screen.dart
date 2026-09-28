import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_buttons.dart';
import '../data/auth_providers.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  AppFailure? _error;

  @override
  void dispose() {
    _email.dispose();
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
          .resetPassword(_email.text.trim());
      setState(() => _sent = true);
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
    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'We\'ll email you a reset link if the account exists.',
      footer: TextButton(
        onPressed: () => context.go('/auth'),
        child: const Text('Back to sign in'),
      ),
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Color(0xFF22C55E),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Check your inbox. The reset link is on its way.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.apply(color: secondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppPrimaryButton(
                  label: 'Back to sign in',
                  onPressed: () => context.go('/auth'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your email.';
                      if (!value.contains('@'))
                        return 'That email looks wrong.';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    FormErrorText(message: _error!.friendlyMessage),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: 'Send reset link',
                    onPressed: _submitting ? null : _submit,
                    loading: _submitting,
                    icon: Icons.send_outlined,
                  ),
                ],
              ),
            ),
    );
  }
}
