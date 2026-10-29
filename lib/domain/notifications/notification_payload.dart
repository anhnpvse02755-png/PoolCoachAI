import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Một thông báo mà người dùng vừa chạm: loại và khoá của nó.
final class NotificationTap {
  const NotificationTap(this.kind, this.key);

  final NotificationKind kind;
  final String key;

  @override
  bool operator ==(Object other) =>
      other is NotificationTap && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => 'NotificationTap(${kind.name}, $key)';
}

/// Chuỗi đi kèm thông báo của hệ điều hành/trình duyệt để nhận ra nó khi chạm.
String notificationPayload(NotificationKind kind, String key) =>
    '${kind.name}|$key';

/// Đọc lại [notificationPayload]. Null khi chuỗi hỏng; không bao giờ ném.
NotificationTap? parseNotificationPayload(String? payload) {
  if (payload == null) return null;
  final cut = payload.indexOf('|');
  if (cut < 0) return null;
  final kind = NotificationKind.values.asNameMap()[payload.substring(0, cut)];
  final key = payload.substring(cut + 1);
  if (kind == null || key.isEmpty) return null;
  return NotificationTap(kind, key);
}
