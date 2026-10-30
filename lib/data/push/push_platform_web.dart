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

/// Giới hạn cho register, getSubscription, unsubscribe.
const _callTimeout = Duration(seconds: 15);

/// pushManager.subscribe gọi ra push service (FCM...), có thể chậm hơn.
const _subscribeTimeout = Duration(seconds: 30);

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
  Future<PushSubscriptionInfo?> current() => _wrap(() async {
    if (!isSupported) return null;
    final reg = await _pushRegistration();
    if (reg == null) return null;
    final sub = await _guard(reg.pushManager.getSubscription().toDart);
    return sub == null ? null : _infoOf(sub);
  });

  /// Đăng ký worker push, chờ nó kích hoạt, rồi đăng ký PushManager bằng khoá
  /// VAPID dạng byte (65 byte). Khoá khác với đăng ký cũ thì huỷ bản cũ trước.
  /// Mọi lỗi (kể cả lỗi JS) ra ngoài là [PushPlatformException].
  Future<PushSubscriptionInfo> subscribe(String vapidPublicKey) =>
      _wrap(() async {
        if (!isSupported) {
          throw const PushPlatformException(
            PushFailure.unsupported,
            'Trình duyệt không có web push',
          );
        }
        final keyBytes = decodeVapidKey(vapidPublicKey);
        final reg = await _guard(
          web.window.navigator.serviceWorker
              .register(
                _workerUrl.toJS,
                web.RegistrationOptions(scope: _workerScope),
              )
              .toDart,
        );
        await _activated(reg);
        final existing = await _guard(reg.pushManager.getSubscription().toDart);
        if (existing != null) {
          final info = _infoOf(existing);
          final old = info.applicationServerKey;
          // Trình duyệt không báo khoá (null): coi là "không rõ", giữ nguyên
          // để khỏi đổi endpoint mỗi lần; vapid_mismatch của máy chủ lo phần
          // còn lại.
          if (old == null || old == encodeBase64Url(keyBytes)) return info;
          await _guard(existing.unsubscribe().toDart);
        }
        final sub = await _guard(
          reg.pushManager
              .subscribe(
                web.PushSubscriptionOptionsInit(
                  userVisibleOnly: true,
                  applicationServerKey: keyBytes.toJS,
                ),
              )
              .toDart,
          _subscribeTimeout,
        );
        return _infoOf(sub);
      });

  Future<void> unsubscribe() => _wrap(() async {
    if (!isSupported) return;
    final reg = await _pushRegistration();
    if (reg == null) return;
    final sub = await _guard(reg.pushManager.getSubscription().toDart);
    if (sub != null) await _guard(sub.unsubscribe().toDart);
  });

  /// Đăng ký của worker `/push/`; null nếu chưa có. `getRegistration` trả cả
  /// worker `/` của Flutter khi chưa có worker push, nên kiểm scope.
  Future<web.ServiceWorkerRegistration?> _pushRegistration() async {
    final reg = await _guard(
      web.window.navigator.serviceWorker.getRegistration(_workerScope).toDart,
    );
    if (reg == null || !Uri.parse(reg.scope).path.endsWith(_workerScope)) {
      return null;
    }
    return reg;
  }

  /// Giới hạn thời gian cho một lệnh trình duyệt có thể treo.
  Future<T> _guard<T>(Future<T> f, [Duration? limit]) =>
      f.timeout(limit ?? _callTimeout);

  /// Gói mọi lỗi thành [PushPlatformException] có phân loại.
  Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PushPlatformException {
      rethrow;
    } on TimeoutException {
      throw const PushPlatformException(PushFailure.transient, 'Hết giờ');
    } on FormatException catch (e) {
      throw PushPlatformException(PushFailure.unsupported, e.message);
    } on Object catch (e) {
      throw _classify(e);
    }
  }

  PushPlatformException _classify(Object e) {
    String? name;
    String? message;
    // ignore: invalid_runtime_check_with_js_interop_types
    if (e is JSObject) {
      name = e.getProperty<JSString?>('name'.toJS)?.toDart;
      message = e.getProperty<JSString?>('message'.toJS)?.toDart;
    }
    final kind = switch (name) {
      'NotAllowedError' || 'SecurityError' => PushFailure.denied,
      'NotSupportedError' || 'InvalidStateError' => PushFailure.unsupported,
      _ => PushFailure.transient,
    };
    return PushPlatformException(kind, name ?? message ?? e.toString());
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
          try {
            final shown = PushShown.fromMessage(event.data.dartify());
            if (shown != null) controller.add(shown);
          } on Object {
            // Thông điệp hỏng không được làm hỏng bộ xử lý sự kiện.
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
