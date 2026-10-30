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

/// Giới hạn miền của Date (±8.64e15 ms).
const _maxEpochMs = 8640000000000000;

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

  /// Đọc thông điệp BroadcastChannel của worker; null khi hỏng, không ném.
  ///
  /// Hợp đồng (phiên bản 1):
  /// `{v: 1, type: 'shown', deliveryId: String, notificationId: int,
  /// kind: String (tên NotificationKind), key: String, title: String,
  /// body: String, shownAt: chuỗi ISO 8601 hoặc mili giây epoch}`.
  /// `v` khác 1 (hoặc thiếu) bị từ chối.
  static PushShown? fromMessage(Object? data) {
    if (data is! Map || data['v'] != 1 || data['type'] != 'shown') return null;
    final deliveryId = data['deliveryId'];
    final id = data['notificationId'];
    final kindName = data['kind'];
    final key = data['key'];
    final title = data['title'];
    final body = data['body'];
    final at = data['shownAt'];
    if (deliveryId is! String || deliveryId.isEmpty) return null;
    if (id is! num || !id.isFinite || id != id.truncate()) return null;
    if (id.abs() > 9007199254740991) return null;
    if (kindName is! String || key is! String || key.isEmpty) return null;
    if (title is! String || body is! String) return null;
    NotificationKind? kind;
    for (final k in NotificationKind.values) {
      if (k.name == kindName) kind = k;
    }
    if (kind == null) return null;
    final DateTime? shownAt = switch (at) {
      num() when at.isFinite && at.abs() <= _maxEpochMs =>
        DateTime.fromMillisecondsSinceEpoch(at.toInt()),
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
/// Vì sao một lệnh push thất bại, để mã dùng chung phân loại mà không cần
/// biết về interop.
enum PushFailure {
  /// Người dùng hoặc trình duyệt từ chối (quyền, chế độ riêng tư).
  denied,

  /// Nền tảng không có web push / FCM.
  unsupported,

  /// Mạng, hết giờ, push service bận: thử lại sau được.
  transient,
}

/// Mọi lỗi của `PushPlatform` được gói thành kiểu này.
class PushPlatformException implements Exception {
  const PushPlatformException(this.kind, [this.message]);

  final PushFailure kind;
  final String? message;

  @override
  String toString() => 'PushPlatformException(${kind.name}, $message)';
}
