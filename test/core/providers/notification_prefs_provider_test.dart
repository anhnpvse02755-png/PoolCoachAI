import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_notification_settings_stores.dart';
import '../../support/fake_recommendation_seen_store.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeNotificationPrefsStore prefsStore;
  late FakeRecommendationSeenStore seenStore;
  late FakeNotificationSettingsMetaStore metaStore;
  final now = DateTime.utc(2026, 10, 30, 12);

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        notificationPrefsStoreProvider.overrideWithValue(prefsStore),
        recommendationSeenStoreProvider.overrideWithValue(seenStore),
        notificationSettingsMetaStoreProvider.overrideWithValue(metaStore),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    // Giữ các provider sống như app thật.
    c.listen(currentUserIdProvider, (_, _) {});
    c.listen(notificationPrefsProvider, (_, _) {});
    c.listen(recommendationSeenProvider, (_, _) {});
    return c;
  }

  setUp(() {
    auth = FakeAuthRepository.signedIn();
    prefsStore = FakeNotificationPrefsStore();
    seenStore = FakeRecommendationSeenStore();
    metaStore = FakeNotificationSettingsMetaStore();
  });

  test('adopt của người khác bị bỏ qua', () async {
    final c = make();
    await pumpEventQueue();
    c
        .read(notificationPrefsProvider.notifier)
        .adopt('khac', const NotificationPrefs(streak: false));
    c
        .read(recommendationSeenProvider.notifier)
        .adopt(
          'khac',
          SeenRecommendation(cat: SkillCategory.kick, drillId: 'x', at: now),
        );
    expect(c.read(notificationPrefsProvider).value, const NotificationPrefs());
    expect(c.read(recommendationSeenProvider).value, isNull);

    c
        .read(notificationPrefsProvider.notifier)
        .adopt('u1', const NotificationPrefs(streak: false));
    expect(
      c.read(notificationPrefsProvider).value,
      const NotificationPrefs(streak: false),
    );
    // Nhận từ server không đánh dấu bẩn.
    expect(metaStore.saved, isEmpty);
  });

  test(
    'setEnabled đánh dấu bẩn và gọi localPrefsChanged; markSeen gọi '
    'localSeenChanged',
    () async {
      final c = make();
      await pumpEventQueue();

      await c
          .read(notificationPrefsProvider.notifier)
          .setEnabled(NotificationKind.streak, false);
      expect(prefsStore.saved['u1'], const NotificationPrefs(streak: false));
      expect(metaStore.saved['u1']?.prefsDirty, true);
      expect(metaStore.saved['u1']?.prefsUpdatedAt, now);
      expect(metaStore.saved['u1']?.seenDirty, false);

      await c
          .read(recommendationSeenProvider.notifier)
          .markSeen(SkillCategory.kick, 'd1');
      expect(seenStore.saved['u1']?.drillId, 'd1');
      expect(metaStore.saved['u1']?.seenDirty, true);
    },
  );

  test(
    'lưu kho công tắc lỗi: không đánh dấu bẩn, không đóng dấu giờ mới',
    () async {
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          notificationPrefsStoreProvider.overrideWithValue(
            _FailingPrefsStore(),
          ),
          recommendationSeenStoreProvider.overrideWithValue(seenStore),
          notificationSettingsMetaStoreProvider.overrideWithValue(metaStore),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      c.listen(notificationPrefsProvider, (_, _) {});
      await pumpEventQueue();
      await c
          .read(notificationPrefsProvider.notifier)
          .setEnabled(NotificationKind.streak, false);
      expect(metaStore.saved, isEmpty);
    },
  );
}

class _FailingPrefsStore extends FakeNotificationPrefsStore {
  @override
  Future<void> save(String userId, NotificationPrefs prefs) =>
      Future.error(StateError('đầy bộ nhớ'));
}
