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
Uri resetPasswordUrl() => Uri.base.resolve('/reset-password');
