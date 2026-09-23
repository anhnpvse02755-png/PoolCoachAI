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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).register(
            displayName: _name.text,
            email: _email.text,
            password: _password.text,
          );
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: Vi.authRegisterTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: Vi.authDisplayNameLabel),
                autofillHints: const [AutofillHints.name],
                validator: validateRequired,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: Vi.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                decoration:
                    const InputDecoration(labelText: Vi.authPasswordLabel),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validateNewPassword,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: Vi.authPasswordConfirmLabel,
                ),
                obscureText: true,
                validator: (v) =>
                    v == _password.text ? null : Vi.authPasswordMismatch,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(Vi.authRegisterAction),
        ),
        TextButton(
          onPressed: () => context.go(Routes.login),
          child: const Text(Vi.authToLogin),
        ),
      ],
    );
  }
}
