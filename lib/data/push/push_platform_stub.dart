import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';

/// Nền tảng không có push (bản dự phòng khi không biết là web hay native).
class PushPlatform {
  bool get isSupported => false;

  PushChannel get channel => PushChannel.web;

  String? get timeZone => null;

  Future<PushSubscriptionInfo?> current() async => null;

  Future<PushSubscriptionInfo> subscribe(String vapidPublicKey) =>
      throw UnsupportedError('Nền tảng này chưa hỗ trợ push');

  Future<void> unsubscribe() async {}

  Stream<PushShown> get shown => const Stream.empty();
}

PushPlatform createPushPlatform() => PushPlatform();
