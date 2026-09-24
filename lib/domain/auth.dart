/// Trạng thái đăng nhập mà router và màn hình đọc.
sealed class AuthState {
  const AuthState();
}

/// Chưa đăng nhập.
///
/// [expired] là true khi server từ chối phiên (tự động đăng xuất). Màn
/// Đăng nhập dựa vào đó để nói lý do, thay vì để người chơi tưởng app
/// tự văng ra.
final class SignedOut extends AuthState {
  const SignedOut({this.expired = false});

  final bool expired;

  @override
  bool operator ==(Object other) =>
      other is SignedOut && other.expired == expired;

  @override
  int get hashCode => expired.hashCode;
}

/// Đang đăng nhập bằng [userId].
final class SignedIn extends AuthState {
  const SignedIn({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is SignedIn &&
      other.userId == userId &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(userId, displayName);
}

/// Lỗi mà màn hình tài khoản biết cách nói bằng tiếng Việt.
///
/// Không bao giờ hiện nguyên văn lỗi server: mỗi loại ở đây có đúng một
/// câu trong `Vi.authFailure`.
enum AuthFailure implements Exception {
  wrongCredentials,
  emailTaken,
  weakPassword,
  network,
  resetLinkInvalid,
  sessionExpired,

  /// Server trả lỗi ngoài dự kiến (5xx, cấu hình sai).
  unknown,
}
