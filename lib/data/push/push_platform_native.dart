import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';

/// Android và iOS: chưa có push từ máy chủ cho tới P6b-2 (FCM).
class PushPlatform {
  bool get isSupported => false;

  PushChannel get channel => PushChannel.fcm;

  String? get timeZone => null;

  Future<PushSubscriptionInfo?> current() async => null;

  Future<PushSubscriptionInfo> subscribe(String vapidPublicKey) =>
      throw UnsupportedError('Push native chưa có (P6b-2)');

  Future<void> unsubscribe() async {}

  Stream<PushShown> get shown => const Stream.empty();
}

PushPlatform createPushPlatform() => PushPlatform();
