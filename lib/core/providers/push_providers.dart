import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/config.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/notification_platform_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/remote/notify_client.dart';
import 'package:poolcoachai/data/push/push_platform.dart';
import 'package:poolcoachai/data/push/push_registration_store.dart';
import 'package:poolcoachai/data/push/push_service.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';

final pushPlatformProvider = Provider<PushPlatform>(
  (ref) => createPushPlatform(),
);

final pushRegistrationStoreProvider = Provider<PushRegistrationStore>(
  (ref) => SharedPreferencesPushRegistrationStore(),
);

final notifyClientProvider = Provider<NotifyClient>((ref) {
  return NotifyClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Uri.parse(notifyBaseUrl),
  );
});

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    auth: ref.watch(authRepositoryProvider),
    notify: ref.watch(notifyClientProvider),
    api: ref.watch(directusClientProvider),
    platform: ref.watch(pushPlatformProvider),
    store: ref.watch(pushRegistrationStoreProvider),
    now: ref.watch(nowProvider),
    vapidPublicKey: vapidPublicKey,
    permission: () => ref.read(notificationPlatformProvider).permission,
  );
  List<Drill>? drills;
  List<KnowledgeArticle>? knowledge;
  void updateCatalog() {
    final d = drills;
    final k = knowledge;
    if (d != null && k != null) {
      service.setCatalog(d, k);
    }
  }

  ref.listen(drillsProvider, (_, next) {
    drills = next.value;
    updateCatalog();
  }, fireImmediately: true);
  ref.listen(knowledgeProvider, (_, next) {
    knowledge = next.value;
    updateCatalog();
  }, fireImmediately: true);
  ref.onDispose(service.dispose);
  return service;
});

final pushUnregisterProvider = Provider<Future<void> Function(String userId)>(
  (ref) => ref.watch(pushServiceProvider).unregister,
);

final pushStateProvider = StreamProvider<PushState>(
  (ref) => ref.watch(pushServiceProvider).states,
);

final pushDeliveredProvider =
    StreamProvider<(String, List<NotificationLogEntry>)>(
      (ref) => ref.watch(pushServiceProvider).delivered,
    );

void startPush(ProviderContainer container) {
  container.listen(pushServiceProvider, (_, _) {}).read().start();
}
