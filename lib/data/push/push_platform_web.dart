import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';
import 'package:web/web.dart' as web;

/// Worker push riêng ở scope `/push/`, tách khỏi worker `/` của Flutter.
const _workerUrl = '/push/sw.js';
const _workerScope = '/push/';

/// Chờ worker kích hoạt tối đa chừng này.
const _activationTimeout = Duration(seconds: 20);

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

/// Web push qua PushManager. Chỉ file này dùng `package:web`.
class PushPlatform {
  /// Trình duyệt có đủ `serviceWorker` và `PushManager`.
  bool get isSupported =>
      web.window.navigator.has('serviceWorker') && web.window.has('PushManager');

  PushChannel get channel => PushChannel.web;

  /// Tên IANA như trình duyệt báo (nguyên văn).
  String? get timeZone {
    try {
      final tz = _DateTimeFormat().resolvedOptions().timeZone;
      return (tz == null || tz.isEmpty) ? null : tz;
    } on Object {
      return null;
    }
  }

  /// Đăng ký hiện có của worker `/push/`, hoặc null.
  Future<PushSubscriptionInfo?> current() async {
    if (!isSupported) return null;
    final reg = await web.window.navigator.serviceWorker
        .getRegistration(_workerScope)
        .toDart;
    // getRegistration trả cả worker `/` của Flutter khi chưa có worker push.
    if (reg == null || !Uri.parse(reg.scope).path.endsWith(_workerScope)) {
      return null;
    }
    final sub = await reg.pushManager.getSubscription().toDart;
    return sub == null ? null : _infoOf(sub);
  }

  /// Đăng ký worker push, chờ nó kích hoạt, rồi đăng ký PushManager bằng khoá
  /// VAPID dạng byte (65 byte). Khoá khác với đăng ký cũ thì huỷ bản cũ trước.
  Future<PushSubscriptionInfo> subscribe(String vapidPublicKey) async {
    if (!isSupported) throw UnsupportedError('Trình duyệt không có web push');
    final keyBytes = decodeVapidKey(vapidPublicKey);
    final reg = await web.window.navigator.serviceWorker
        .register(
          _workerUrl.toJS,
          web.RegistrationOptions(scope: _workerScope),
        )
        .toDart;
    await _activated(reg);
    final existing = await reg.pushManager.getSubscription().toDart;
    if (existing != null) {
      final old = _infoOf(existing).applicationServerKey;
      if (old == encodeBase64Url(keyBytes)) return _infoOf(existing);
      await existing.unsubscribe().toDart;
    }
    final sub = await reg.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: keyBytes.toJS,
          ),
        )
        .toDart;
    return _infoOf(sub);
  }

  Future<void> unsubscribe() async {
    if (!isSupported) return;
    final reg = await web.window.navigator.serviceWorker
        .getRegistration(_workerScope)
        .toDart;
    if (reg == null || !Uri.parse(reg.scope).path.endsWith(_workerScope)) {
      return;
    }
    final sub = await reg.pushManager.getSubscription().toDart;
    await sub?.unsubscribe().toDart;
  }

  /// Thông báo worker vừa hiện, qua BroadcastChannel `pcai-push`.
  Stream<PushShown> get shown {
    late final StreamController<PushShown> controller;
    web.BroadcastChannel? channel;
    controller = StreamController<PushShown>.broadcast(
      onListen: () {
        if (!isSupported) return;
        final c = web.BroadcastChannel('pcai-push');
        c.onmessage = ((web.MessageEvent event) {
          final data = event.data.dartify();
          if (data is Map && data['type'] == 'shown') {
            final shown = PushShown.fromMessage(data);
            if (shown != null) controller.add(shown);
          }
        }).toJS;
        channel = c;
      },
      onCancel: () {
        channel?.close();
        channel = null;
      },
    );
    return controller.stream;
  }

  /// KHÔNG dùng `serviceWorker.ready`: worker `/` của Flutter cũng làm nó
  /// xong. Chờ đúng worker của đăng ký vừa tạo.
  Future<void> _activated(web.ServiceWorkerRegistration reg) async {
    if (reg.active?.state == 'activated') return;
    final worker = reg.installing ?? reg.waiting ?? reg.active;
    if (worker == null) throw StateError('Không có worker push');
    final done = Completer<void>();
    void check() {
      if (done.isCompleted) return;
      if (worker.state == 'activated') {
        done.complete();
      } else if (worker.state == 'redundant') {
        done.completeError(StateError('Worker push bị loại'));
      }
    }

    worker.onstatechange = ((web.Event _) => check()).toJS;
    check();
    try {
      await done.future.timeout(_activationTimeout);
    } finally {
      worker.onstatechange = null;
    }
  }

  PushSubscriptionInfo _infoOf(web.PushSubscription sub) {
    final json = sub.toJSON();
    final keys = json.keys;
    final p256dh = (keys['p256dh'] as JSString?)?.toDart;
    final auth = (keys['auth'] as JSString?)?.toDart;
    if (p256dh == null || auth == null) {
      throw StateError('Đăng ký push thiếu khoá');
    }
    final buffer = sub.options.applicationServerKey;
    return PushSubscriptionInfo(
      endpoint: json.endpoint,
      p256dh: p256dh,
      auth: auth,
      applicationServerKey: buffer == null
          ? null
          : encodeBase64Url(buffer.toDart.asUint8List()),
    );
  }
}

PushPlatform createPushPlatform() => PushPlatform();
