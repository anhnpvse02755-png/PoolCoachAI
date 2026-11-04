import 'dart:js_interop';

import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:web/web.dart' as web;

@JS('globalThis.Notification')
external JSFunction? get _browserNotification;

class NotificationPlatform {
  // ignore: avoid_unused_constructor_parameters
  NotificationPlatform({NotificationScheduler? scheduler});

  /// Dịch vụ đặt vào đây để nhận lần chạm thông báo.
  void Function(String payload)? _onTap;
  web.BroadcastChannel? _pushChannel;

  set onTap(void Function(String payload)? callback) {
    _onTap = callback;
    _pushChannel?.close();
    _pushChannel = null;
    if (callback == null) return;
    final channel = web.BroadcastChannel('pcai-push');
    channel.onmessage = ((web.MessageEvent event) {
      try {
        final data = event.data.dartify();
        if (web.document.visibilityState == 'visible' &&
            data is Map &&
            data['type'] == 'tap' &&
            data['payload'] is String) {
          _onTap?.call(data['payload'] as String);
        }
      } on Object {
        // Ignore malformed messages from other tabs or workers.
      }
    }).toJS;
    _pushChannel = channel;
  }

  /// Đọc một lần payload từ URL mở app lạnh, rồi bỏ query khỏi thanh địa chỉ.
  Future<String?> takeLaunchPayload() async {
    final uri = Uri.base;
    final payload = uri.queryParameters['n'];
    if (payload == null) return null;
    final query = Map<String, String>.from(uri.queryParameters)..remove('n');
    final cleanUri = uri.replace(queryParameters: query.isEmpty ? null : query);
    web.window.history.replaceState(null, '', cleanUri.toString());
    return payload;
  }

  /// Trình duyệt không đặt lịch được: dịch vụ tự kiểm tra bằng timer.
  NotificationScheduler? get scheduler => null;

  Future<void> loadPermission() async {}

  bool get isSupported => _browserNotification != null;

  String? get permission => isSupported ? web.Notification.permission : null;

  Future<String?> requestPermission() async {
    if (!isSupported) return null;
    return (await web.Notification.requestPermission().toDart).toDart;
  }

  void show({
    required String title,
    required String body,
    required String tag,
    required String payload,
  }) {
    final notification = web.Notification(
      title,
      web.NotificationOptions(body: body, tag: tag),
    );
    notification.onclick = (web.Event _) {
      _onTap?.call(payload);
      web.window.focus();
      notification.close();
    }.toJS;
  }

  String? readValue(String key) => web.window.localStorage.getItem(key);

  void writeValue(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }
}

NotificationPlatform createNotificationPlatform() => NotificationPlatform();
