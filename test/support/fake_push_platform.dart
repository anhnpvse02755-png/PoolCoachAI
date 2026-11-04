import 'dart:async';

import 'package:poolcoachai/data/push/push_platform.dart';
import 'package:poolcoachai/data/push/push_types.dart';

class FakePushPlatform extends PushPlatform {
  bool supported = true;
  String? zone = 'Asia/Ho_Chi_Minh';
  PushSubscriptionInfo subscription = const PushSubscriptionInfo(
    endpoint: 'https://push.example/device',
    p256dh: 'public-key',
    auth: 'auth-key',
  );
  int subscribeCalls = 0;
  int unsubscribeCalls = 0;
  final shownController = StreamController<PushShown>.broadcast();

  @override
  bool get isSupported => supported;

  @override
  String? get timeZone => zone;

  @override
  Future<PushSubscriptionInfo?> current() async => subscription;

  @override
  Future<PushSubscriptionInfo> subscribe(String vapidPublicKey) async {
    subscribeCalls++;
    return subscription;
  }

  @override
  Future<void> unsubscribe() async {
    unsubscribeCalls++;
  }

  @override
  Stream<PushShown> get shown => shownController.stream;

  void show(PushShown value) => shownController.add(value);

  Future<void> dispose() => shownController.close();
}
