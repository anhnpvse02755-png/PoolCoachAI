import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Máy chủ chỉ nhận tối đa chừng này mục `shownToday` (devices.mjs).
const maxShownToday = 50;

/// Một thông báo máy này đã hiện hôm nay.
final class PushShownRef {
  const PushShownRef({required this.kind, required this.key});

  final NotificationKind kind;
  final String key;
}

final class NotifyConfig {
  const NotifyConfig({required this.enabled, required this.publicKey});

  final bool enabled;
  final String? publicKey;
}

final class NotifyRegistration {
  const NotifyRegistration({
    required this.deviceId,
    required this.serverKinds,
    required this.leaseUntil,
    required this.serverNow,
    required this.enabled,
  });

  final String deviceId;
  final Set<NotificationKind> serverKinds;
  final DateTime? leaseUntil;
  final DateTime serverNow;
  final bool enabled;
}

/// Máy chủ trả mã lỗi. [code] là trường `error` của thân (có thể null).
class NotifyError implements Exception {
  const NotifyError(this.status, this.code);

  final int status;
  final String? code;

  @override
  String toString() => 'NotifyError($status, $code)';
}

/// Không tới được máy chủ (mất mạng, hết giờ).
class NotifyUnreachable implements Exception {
  const NotifyUnreachable();

  @override
  String toString() => 'NotifyUnreachable';
}

/// Client HTTP mỏng cho dịch vụ notify (server/notify).
class NotifyClient {
  NotifyClient({
    required this._client,
    required this._baseUrl,
    this._timeout = const Duration(seconds: 10),
  });

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  Uri _uri(String path) {
    final root = _baseUrl.path.endsWith('/')
        ? _baseUrl.path.substring(0, _baseUrl.path.length - 1)
        : _baseUrl.path;
    return _baseUrl.replace(path: '$root$path');
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final request = http.Request(method, _uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      ).timeout(_timeout);
    } on TimeoutException {
      throw const NotifyUnreachable();
    } on http.ClientException {
      throw const NotifyUnreachable();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    String? code;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] is String) {
        code = decoded['error'] as String;
      }
    } on FormatException {
      // Thân không phải JSON: code null.
    }
    throw NotifyError(response.statusCode, code);
  }

  Map<String, Object?> _json(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // rơi xuống lỗi bên dưới
    }
    throw NotifyError(response.statusCode, null);
  }

  /// `GET /push/config`.
  Future<NotifyConfig> config() async {
    final response = await _send('GET', '/push/config');
    final j = _json(response);
    final enabled = j['enabled'];
    final key = j['publicKey'];
    if (enabled is! bool || (key != null && key is! String)) {
      throw NotifyError(response.statusCode, null);
    }
    return NotifyConfig(enabled: enabled, publicKey: key as String?);
  }

  /// `POST /push/devices`. [shownToday] là các thông báo máy này đã hiện hôm
  /// nay (cắt ở [maxShownToday]).
  Future<NotifyRegistration> register({
    required String token,
    required PushSubscriptionInfo subscription,
    required String timezone,
    required String? seedFingerprint,
    required String vapidPublicKey,
    List<PushShownRef> shownToday = const [],
  }) async {
    final response = await _send(
      'POST',
      '/push/devices',
      token: token,
      body: {
        'channel': 'web',
        'endpoint': subscription.endpoint,
        'keys': {'p256dh': subscription.p256dh, 'auth': subscription.auth},
        'timezone': timezone,
        'seedFingerprint': seedFingerprint,
        'vapidPublicKey': vapidPublicKey,
        'shownToday': [
          for (final s in shownToday.take(maxShownToday))
            {'kind': s.kind.name, 'key': s.key},
        ],
      },
    );
    final j = _json(response);
    final deviceId = j['deviceId'];
    final kinds = j['serverKinds'];
    final leaseRaw = j['leaseUntil'];
    final nowRaw = j['serverNow'];
    final enabled = j['enabled'];
    final lease = leaseRaw is String ? DateTime.tryParse(leaseRaw) : null;
    final serverNow = nowRaw is String ? DateTime.tryParse(nowRaw) : null;
    if (deviceId is! String ||
        kinds is! List ||
        serverNow == null ||
        enabled is! bool ||
        (leaseRaw != null && lease == null)) {
      throw NotifyError(response.statusCode, null);
    }
    final known = {for (final k in NotificationKind.values) k.name: k};
    return NotifyRegistration(
      deviceId: deviceId,
      serverKinds: {
        for (final k in kinds)
          if (k is String && known.containsKey(k)) known[k]!,
      },
      leaseUntil: lease,
      serverNow: serverNow,
      enabled: enabled,
    );
  }

  /// `DELETE /push/devices/<id>` (204 dù dòng có hay không).
  Future<void> unregister({
    required String token,
    required String deviceId,
  }) async {
    await _send(
      'DELETE',
      '/push/devices/${Uri.encodeComponent(deviceId)}',
      token: token,
    );
  }
}
