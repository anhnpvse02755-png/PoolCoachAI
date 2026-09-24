import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/auth_form_scaffold.dart';
import 'package:poolcoachai/features/auth/presentation/auth_validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: Vi.authForgotTitle,
      children: [
        const Text(Vi.authForgotHint),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: Vi.authEmailLabel),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        if (_sent)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Text(Vi.authForgotSent),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(Vi.authForgotAction),
        ),
        TextButton(
          onPressed: () => context.go(Routes.login),
          child: const Text(Vi.authToLogin),
        ),
      ],
    );
  }
}
