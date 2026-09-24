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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.token, super.key});

  /// Token trong link email; null khi link bị cắt cụt.
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(String token) async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.resetPassword(token: token, password: _password.text);
      if (!mounted) return;
      // Messenger nằm trên router: báo trước, để câu vẫn hiện dù đăng
      // xuất làm router rời màn này.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Vi.authResetDone)),
      );
      // Đang đăng nhập (mở link trên máy đang dùng) thì router sẽ đẩy
      // /login về Trang chủ. Đăng xuất để người chơi thật sự vào lại
      // bằng mật khẩu mới — kiểu thường, không xoá buổi tập nào.
      if (auth.current is SignedIn) await auth.signOut();
      if (!mounted) return;
      context.go(Routes.login);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      return AuthFormScaffold(
        title: Vi.authResetTitle,
        children: [
          const Text(Vi.authResetMissingToken),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () => context.go(Routes.forgotPassword),
            child: const Text(Vi.authToForgot),
          ),
        ],
      );
    }

    return AuthFormScaffold(
      title: Vi.authResetTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _password,
                decoration:
                    const InputDecoration(labelText: Vi.authNewPasswordLabel),
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
                onFieldSubmitted: (_) => _submit(token),
              ),
            ],
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : () => _submit(token),
          child: const Text(Vi.authResetAction),
        ),
      ],
    );
  }
}
