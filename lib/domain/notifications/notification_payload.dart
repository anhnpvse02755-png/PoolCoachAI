import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Một thông báo mà người dùng vừa chạm: loại, khoá và tài khoản của nó.
final class NotificationTap {
  const NotificationTap(this.kind, this.key, {this.userId});

  final NotificationKind kind;
  final String key;

  /// Tài khoản mà thông báo được gửi cho. Null: thông báo đặt từ bản trước,
  /// khi payload chưa mang tài khoản (coi như của người đang đăng nhập).
  final String? userId;

  @override
  bool operator ==(Object other) =>
      other is NotificationTap &&
      other.kind == kind &&
      other.key == key &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(kind, key, userId);

  @override
  String toString() => 'NotificationTap(${kind.name}, $key, $userId)';
}

const _v2 = 'v2|';

/// Chuỗi đi kèm thông báo của hệ điều hành/trình duyệt để nhận ra nó khi chạm:
/// `v2|<tài khoản>|<loại>|<khoá>`; không có [userId] thì `<loại>|<khoá>` như
/// bản trước. Tài khoản được mã hoá nên không chứa `|`; khoá đứng cuối nên
/// chứa gì cũng được.
String notificationPayload(
  NotificationKind kind,
  String key, {
  String? userId,
}) => userId == null
    ? '${kind.name}|$key'
    : '$_v2${Uri.encodeComponent(userId)}|${kind.name}|$key';

/// Đọc lại [notificationPayload], cả dạng có và không có tài khoản. Null khi
/// chuỗi hỏng; không bao giờ ném.
NotificationTap? parseNotificationPayload(String? payload) {
  if (payload == null) return null;
  String? userId;
  var rest = payload;
  if (payload.startsWith(_v2)) {
    final body = payload.substring(_v2.length);
    final cut = body.indexOf('|');
    if (cut <= 0) return null;
    try {
      userId = Uri.decodeComponent(body.substring(0, cut));
    } on Object {
      // ArgumentError khi "%" sai dạng, FormatException khi hex đúng mà các
      // byte không phải UTF-8 (%FF, %E0%A4). Chuỗi hỏng: không đi đâu cả.
      return null;
    }
    rest = body.substring(cut + 1);
  }
  final cut = rest.indexOf('|');
  if (cut < 0) return null;
  final kind = NotificationKind.values.asNameMap()[rest.substring(0, cut)];
  final key = rest.substring(cut + 1);
  if (kind == null || key.isEmpty) return null;
  return NotificationTap(kind, key, userId: userId);
}
