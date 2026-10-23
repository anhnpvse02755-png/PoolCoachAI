import 'package:flutter/foundation.dart' show kIsWeb;

/// Địa chỉ Directus. Đổi khi build: `--dart-define=API_URL=…`.
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://poolcoachai-api.kjdybl.easypanel.host',
);

/// Link trong email quên mật khẩu mở về đây.
///
/// Dựng từ origin đang chạy nên đúng cả trên bản live lẫn
/// `localhost:5555`. Cả hai phải có trong `PASSWORD_RESET_URL_ALLOW_LIST`
/// của server, không thì Directus từ chối gửi thư.
///
/// Trên Android/iOS `Uri.base` là đường dẫn file nên không dùng được:
/// người dùng đặt lại mật khẩu trên trang web ([webBaseUrl]), địa chỉ này
/// cũng phải nằm trong allow-list của server.
Uri resetPasswordUrl() =>
    resetPasswordUrlFor(isWeb: kIsWeb, base: Uri.base, webUrl: webBaseUrl);

/// Địa chỉ bản web, dùng cho link trong email khi app chạy native.
/// Đổi khi build: `--dart-define=WEB_URL=…`.
const webBaseUrl = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'https://poolcoachai.kjdybl.easypanel.host',
);

/// Địa chỉ dịch vụ coach-chat (Giai đoạn B, spec mục 9).
/// Đổi khi build: `--dart-define=COACH_CHAT_URL=…`.
const coachChatUrl = String.fromEnvironment(
  'COACH_CHAT_URL',
  defaultValue: 'https://poolcoachai-coach.kjdybl.easypanel.host',
);

Uri resetPasswordUrlFor({
  required bool isWeb,
  required Uri base,
  required String webUrl,
}) {
  if (isWeb) return base.resolve('/reset-password');
  final root = webUrl.endsWith('/')
      ? webUrl.substring(0, webUrl.length - 1)
      : webUrl;
  return Uri.parse('$root/reset-password');
}
