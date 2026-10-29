import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/bootstrap.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import '../support/fake_auth.dart';
import '../support/fake_recommendation_seen_store.dart';

/// Kho cài đặt giả: mỗi tài khoản một bộ, vắng thì mặc định.
class _PrefsStore implements NotificationPrefsStore {
  _PrefsStore(this.saved);

  final Map<String, NotificationPrefs> saved;

  @override
  Future<NotificationPrefs> load(String userId) async =>
      saved[userId] ?? const NotificationPrefs();

  @override
  Future<void> save(String userId, NotificationPrefs prefs) async =>
      saved[userId] = prefs;
}

/// Nạp seed lúc khởi động — mục 4.3.1 của thiết kế.
///
/// Quên bước này thì mọi tầng bên dưới vẫn đúng và mọi test khác vẫn
/// xanh, nhưng app chạy thật mở ra với thư viện bài tập rỗng: DB chưa
/// ai ghi gì vào.
void main() {
  test('nạp seed xong thì bài tập đã sẵn sàng cho màn hình đầu tiên',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await loadSeed(container);

    container.listen(drillsProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(drillsProvider).value?.length, 19);
  });

  test('khôi phục phiên trước khung đầu tiên', () async {
    final auth = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await restoreSession(container);

    expect(auth.calls, ['restore']);
  });

  test(
    'startNotifications giữ dịch vụ luôn nghe: đăng nhập sau khi mở app thì '
    'cài đặt của tài khoản tới được dịch vụ',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final auth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(auth),
          notificationPrefsStoreProvider.overrideWithValue(
            _PrefsStore({'u1': const NotificationPrefs(streak: false)}),
          ),
          recommendationSeenStoreProvider.overrideWithValue(
            FakeRecommendationSeenStore(),
          ),
        ],
      );
      addTearDown(container.dispose);

      startNotifications(container);
      await pumpEventQueue();
      final service = container.read(notificationServiceProvider);
      expect(service.prefs, const NotificationPrefs());

      // Chỉ cái nghe thường trực làm chuỗi auth → cài đặt dựng lại; một lần
      // `read` để dịch vụ ngưng nghe, nên nó giữ mặc định của lúc chưa đăng
      // nhập.
      auth.emit(const SignedIn(userId: 'u1', displayName: 'An'));
      await pumpEventQueue();
      expect(service.prefs, const NotificationPrefs(streak: false));
      expect(service.recommendationSource?.userId, 'u1');
    },
  );

  test('startSync bật thông báo qua startNotifications', () {
    final source = File('lib/core/bootstrap.dart').readAsStringSync();
    final body = source.substring(source.indexOf('void startSync('));
    expect(body, contains('startNotifications(container)'));
    expect(body, isNot(contains('container.read(notificationServiceProvider)')));
  });

  test('main nạp seed xong mới dựng app', () {
    // Không có cách nào chạy main() trong kiểm thử mà không dựng app
    // thật, nên kiểm ngay trên mã: thứ tự hai lời gọi này là cả luật.
    final source = File('lib/main.dart').readAsStringSync();

    final seedAt = source.indexOf('await loadSeed(');
    final runAt = source.indexOf('runApp(');

    expect(seedAt, isNonNegative, reason: 'main phải nạp seed lúc khởi động');
    expect(
      seedAt,
      lessThan(runAt),
      reason: 'nạp seed phải xong trước khi màn hình đầu tiên đọc dữ liệu',
    );
  });

  test('main khôi phục phiên và bật đồng bộ trước khi dựng app', () {
    final source = File('lib/main.dart').readAsStringSync();
    final restoreAt = source.indexOf('await restoreSession(');
    final syncAt = source.indexOf('startSync(');
    final runAt = source.indexOf('runApp(');

    expect(restoreAt, isNonNegative);
    expect(restoreAt, lessThan(runAt),
        reason: 'router phải biết đã đăng nhập hay chưa ngay khung đầu');
    expect(syncAt, greaterThan(restoreAt),
        reason: 'đồng bộ chỉ có nghĩa sau khi biết người đang đăng nhập');
  });
}
