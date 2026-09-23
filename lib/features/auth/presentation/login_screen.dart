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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Chặn bấm lần hai khi lần đầu chưa xong.
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      // Không điều hướng ở đây: đăng nhập xong thì router tự đưa vào app.
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = switch (ref.watch(authStateProvider)) {
      SignedOut(expired: true) => true,
      _ => false,
    };

    return AuthFormScaffold(
      title: Vi.authLoginTitle,
      children: [
        if (expired)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(Vi.authSessionExpired),
          ),
        Form(
          key: _formKey,
          child: Column(
            children: [
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
                autofillHints: const [AutofillHints.password],
                validator: validateRequired,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(Vi.authLoginAction),
        ),
        TextButton(
          onPressed: () => context.go(Routes.forgotPassword),
          child: const Text(Vi.authToForgot),
        ),
        TextButton(
          onPressed: () => context.go(Routes.register),
          child: const Text(Vi.authToRegister),
        ),
      ],
    );
  }
}
