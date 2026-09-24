import 'package:poolcoachai/core/strings/vi.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateRequired(String? value) =>
    (value ?? '').trim().isEmpty ? Vi.authFieldRequired : null;

String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return Vi.authFieldRequired;
  return _email.hasMatch(text) ? null : Vi.authEmailInvalid;
}

String? validateNewPassword(String? value) =>
    (value ?? '').length < 8 ? Vi.authPasswordTooShort : null;
