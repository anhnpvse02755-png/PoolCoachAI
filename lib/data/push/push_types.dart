import 'dart:convert';
import 'dart:typed_data';

import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Đăng ký push của trình duyệt, đúng hình `PushSubscription.toJSON()`.
/// Mọi khoá là base64url không đệm.
final class PushSubscriptionInfo {
  const PushSubscriptionInfo({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
    this.applicationServerKey,
  });

  final String endpoint;
  final String p256dh;
  final String auth;

  /// Khoá VAPID công khai mà đăng ký này đã dùng (base64url, không đệm).
  final String? applicationServerKey;
}

/// Một thông báo mà worker push vừa hiện ra trên máy này.
final class PushShown {
  const PushShown({
    required this.deliveryId,
    required this.notificationId,
    required this.kind,
    required this.key,
    required this.title,
    required this.body,
    required this.shownAt,
  });

  final String deliveryId;
  final int notificationId;
  final NotificationKind kind;
  final String key;
  final String title;
  final String body;
  final DateTime shownAt;

  /// Đọc thông điệp `{type:'shown', ...}` của worker; null khi hỏng.
  /// `shownAt` là mili giây epoch hoặc chuỗi ISO 8601.
  static PushShown? fromMessage(Object? data) {
    if (data is! Map) return null;
    final deliveryId = data['deliveryId'];
    final id = data['notificationId'];
    final kindName = data['kind'];
    final key = data['key'];
    final title = data['title'];
    final body = data['body'];
    final at = data['shownAt'];
    if (deliveryId is! String || deliveryId.isEmpty) return null;
    if (id is! num || !id.isFinite || id != id.truncate()) return null;
    if (kindName is! String || key is! String || key.isEmpty) return null;
    if (title is! String || body is! String) return null;
    NotificationKind? kind;
    for (final k in NotificationKind.values) {
      if (k.name == kindName) kind = k;
    }
    if (kind == null) return null;
    final DateTime? shownAt = switch (at) {
      num() when at.isFinite => DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      String() => DateTime.tryParse(at),
      _ => null,
    };
    if (shownAt == null) return null;
    return PushShown(
      deliveryId: deliveryId,
      notificationId: id.toInt(),
      kind: kind,
      key: key,
      title: title,
      body: body,
      shownAt: shownAt,
    );
  }
}

/// base64url không đệm.
String encodeBase64Url(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Khoá VAPID công khai (base64url) thành đúng 65 byte của điểm P-256 không
/// nén. Truyền cho `PushManager.subscribe` dưới dạng byte, không bao giờ là
/// chuỗi. Ném [FormatException] khi sai.
Uint8List decodeVapidKey(String key) {
  final padded = key.padRight((key.length + 3) ~/ 4 * 4, '=');
  final bytes = base64Url.decode(padded);
  if (bytes.length != 65 || bytes[0] != 4) {
    throw const FormatException('Khoá VAPID phải là điểm P-256 65 byte');
  }
  return bytes;
}
