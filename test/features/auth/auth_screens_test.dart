import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/login_screen.dart';
import 'package:poolcoachai/features/auth/presentation/reset_password_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';

import '../../support/test_data.dart';

void main() {
  Future<void> fill(WidgetTester tester, String label, String value) =>
      tester.enterText(find.widgetWithText(TextFormField, label), value);

  Finder button(String text) => find.widgetWithText(FilledButton, text);

  group('Đăng nhập', () {
    testWidgets('chưa đăng nhập thì mở app là vào màn Đăng nhập', (tester) async {
      await pumpAuthApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('email sai dạng thì chặn, không gọi server', (tester) async {
      final (_, auth) = await pumpAuthApp(tester);

      await fill(tester, Vi.authEmailLabel, 'khong-phai-email');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authEmailInvalid), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('đăng nhập đúng thì router tự vào Trang chủ', (tester) async {
      await pumpAuthApp(tester);

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sai mật khẩu thì nói bằng tiếng Việt', (tester) async {
      final (_, auth) = await pumpAuthApp(tester);
      auth.nextFailure = AuthFailure.wrongCredentials;

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'sai');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.wrongCredentials)), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('bấm Đăng nhập hai lần chỉ gọi một lần', (tester) async {
      final (_, auth) = await pumpAuthApp(tester);
      auth.hold = Completer<void>();

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pump();
      await tester.tap(button(Vi.authLoginAction));
      await tester.pump();
      auth.hold!.complete();
      await tester.pumpAndSettle();

      expect(auth.calls.where((c) => c.startsWith('signIn')), hasLength(1));
    });

    testWidgets('phiên hết hạn thì màn Đăng nhập nói lý do', (tester) async {
      await pumpAuthApp(tester, initial: const SignedOut(expired: true));

      expect(find.text(Vi.authSessionExpired), findsOneWidget);
    });

    testWidgets('đang đăng nhập mà phiên hết hạn thì về Đăng nhập', (tester) async {
      final (_, auth) = await pumpAuthApp(
        tester,
        initial: const SignedIn(userId: 'u1', displayName: 'An'),
      );
      expect(find.byType(HomeScreen), findsOneWidget);

      auth.emit(const SignedOut(expired: true));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(Vi.authSessionExpired), findsOneWidget);
    });
  });

  group('Đăng ký', () {
    testWidgets('hai mật khẩu không khớp thì chặn', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.register);

      await fill(tester, Vi.authDisplayNameLabel, 'An');
      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau124');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authPasswordMismatch), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('mật khẩu dưới 8 ký tự thì chặn', (tester) async {
      await pumpAuthApp(tester, location: Routes.register);

      await fill(tester, Vi.authPasswordLabel, '1234567');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authPasswordTooShort), findsOneWidget);
    });

    testWidgets('đăng ký xong vào thẳng app', (tester) async {
      await pumpAuthApp(tester, location: Routes.register);

      await fill(tester, Vi.authDisplayNameLabel, 'An');
      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('email đã có tài khoản thì nói rõ và chỉ đường', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.register);
      auth.nextFailure = AuthFailure.emailTaken;

      await fill(tester, Vi.authDisplayNameLabel, 'An');
      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.emailTaken)), findsOneWidget);
    });
  });

  group('Quên mật khẩu', () {
    testWidgets('gửi xong luôn cùng một câu', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.forgotPassword);

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await tester.tap(button(Vi.authForgotAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authForgotSent), findsOneWidget);
      expect(auth.calls, ['request:an@example.com']);
    });

    testWidgets('mất mạng thì báo mạng, không báo đã gửi', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.forgotPassword);
      auth.nextFailure = AuthFailure.network;

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await tester.tap(button(Vi.authForgotAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.network)), findsOneWidget);
      expect(find.text(Vi.authForgotSent), findsNothing);
    });
  });

  group('Đặt lại mật khẩu', () {
    testWidgets('link mang token thì màn nhận đúng token', (tester) async {
      await pumpAuthApp(tester, location: '${Routes.resetPassword}?token=abc');

      final screen = tester.widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen));
      expect(screen.token, 'abc');
    });

    testWidgets('link thiếu token thì nói rõ, không có form', (tester) async {
      await pumpAuthApp(tester, location: Routes.resetPassword);

      expect(find.text(Vi.authResetMissingToken), findsOneWidget);
      expect(button(Vi.authResetAction), findsNothing);
    });

    testWidgets('đặt lại xong thì về Đăng nhập kèm thông báo', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: '${Routes.resetPassword}?token=abc');

      await fill(tester, Vi.authNewPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authResetAction));
      await tester.pumpAndSettle();

      expect(auth.calls, ['reset:abc']);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(Vi.authResetDone), findsOneWidget);
    });

    testWidgets('link đã dùng thì bảo xin link mới', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: '${Routes.resetPassword}?token=abc');
      auth.nextFailure = AuthFailure.resetLinkInvalid;

      await fill(tester, Vi.authNewPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authResetAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.resetLinkInvalid)), findsOneWidget);
    });
  });
}
