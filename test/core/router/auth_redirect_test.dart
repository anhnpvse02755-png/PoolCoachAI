import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/domain/auth.dart';

void main() {
  const out = SignedOut();
  const inn = SignedIn(userId: 'u1', displayName: 'An');
  Uri at(String p) => Uri.parse(p);

  test('chưa đăng nhập mở màn tập thì về Đăng nhập', () {
    expect(authRedirect(out, at('/training')), Routes.login);
    expect(authRedirect(out, at('/training/drills/d1/session')), Routes.login);
  });

  test('chưa đăng nhập vẫn mở được ba màn tài khoản', () {
    for (final p in Routes.signedOutOnly) {
      expect(authRedirect(out, at(p)), isNull, reason: p);
    }
  });

  test('đã đăng nhập mà mở màn tài khoản thì về Trang chủ', () {
    for (final p in Routes.signedOutOnly) {
      expect(authRedirect(inn, at(p)), Routes.home, reason: p);
    }
  });

  test('link đặt lại mật khẩu mở được ở cả hai trạng thái', () {
    expect(authRedirect(out, at('/reset-password?token=abc')), isNull);
    expect(authRedirect(inn, at('/reset-password?token=abc')), isNull);
  });

  test('đã đăng nhập thì mọi màn khác giữ nguyên', () {
    expect(authRedirect(inn, at('/training')), isNull);
  });
}
