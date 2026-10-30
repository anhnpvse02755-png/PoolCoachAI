import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/data/notifications/notification_settings_meta_store.dart';
import 'package:poolcoachai/data/notifications/notification_schedule_version_store.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/data/notifications/recommendation_seen_store.dart';
import 'package:poolcoachai/data/sync/notification_settings_sync.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

final notificationPrefsStoreProvider = Provider<NotificationPrefsStore>(
  (ref) => SharedPreferencesNotificationPrefsStore(),
);

/// Loại thông báo đang bật của người đang đăng nhập, lưu trên máy này.
///
/// [AsyncLoading] tới khi đọc xong: dịch vụ không được báo gì trước đó,
/// kẻo báo nhầm loại người dùng đã tắt.
final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsController, AsyncValue<NotificationPrefs>>(
      NotificationPrefsController.new,
    );

class NotificationPrefsController
    extends Notifier<AsyncValue<NotificationPrefs>> {
  @override
  AsyncValue<NotificationPrefs> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const AsyncData(NotificationPrefs());
    var disposed = false;
    ref.onDispose(() => disposed = true);
    ref
        .read(notificationPrefsStoreProvider)
        .load(userId)
        .then<NotificationPrefs>(
          (prefs) => prefs,
          onError: (Object _) => const NotificationPrefs(),
        )
        .then((prefs) {
          // Đã đổi tay trong lúc đang đọc thì giữ lựa chọn của người dùng.
          if (!disposed && state is AsyncLoading) state = AsyncData(prefs);
        });
    return const AsyncLoading();
  }

  Future<void> setEnabled(NotificationKind kind, bool enabled) async {
    final userId = ref.read(currentUserIdProvider);
    final next = (state.value ?? const NotificationPrefs()).toggled(
      kind,
      enabled,
    );
    state = AsyncData(next);
    if (userId == null) return;
    try {
      await ref.read(notificationPrefsStoreProvider).save(userId, next);
    } on Object {
      // Không lưu được thì lựa chọn chỉ có hiệu lực tới khi mở lại app.
    }
    try {
      await ref
          .read(notificationSettingsSyncProvider)
          .localPrefsChanged(userId);
    } on Object {
      // Đồng bộ là việc phụ: lỗi ở đây không được làm hỏng công tắc.
    }
  }

  /// Nhận cài đặt từ server (máy khác đổi). Chỉ nhận cho người đang đăng
  /// nhập, và không đánh dấu bẩn nên không đẩy ngược lên.
  void adopt(String userId, NotificationPrefs prefs) {
    if (ref.read(currentUserIdProvider) != userId) return;
    state = AsyncData(prefs);
  }
}

final recommendationSeenStoreProvider = Provider<RecommendationSeenStore>(
  (ref) => SharedPreferencesRecommendationSeenStore(),
);

/// Cặp gợi ý người đang đăng nhập thấy lần cuối trên Trang chủ.
///
/// [AsyncLoading] tới khi đọc xong; `AsyncData(null)` là chưa thấy lần nào.
final recommendationSeenProvider =
    NotifierProvider<
      RecommendationSeenController,
      AsyncValue<SeenRecommendation?>
    >(RecommendationSeenController.new);

class RecommendationSeenController
    extends Notifier<AsyncValue<SeenRecommendation?>> {
  @override
  AsyncValue<SeenRecommendation?> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const AsyncData(null);
    // Mỗi lần build một cờ riêng: Notifier giữ nguyên instance khi build lại.
    var disposed = false;
    ref.onDispose(() => disposed = true);
    ref
        .read(recommendationSeenStoreProvider)
        .load(userId)
        .then<SeenRecommendation?>(
          (seen) => seen,
          onError: (Object _) => null,
        )
        .then((seen) {
          // Đã ghi trong lúc đang đọc thì giữ cặp mới nhất.
          if (!disposed && state is AsyncLoading) state = AsyncData(seen);
        });
    return const AsyncLoading();
  }

  Future<void> markSeen(SkillCategory cat, String drillId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final seen = SeenRecommendation(
      cat: cat,
      drillId: drillId,
      at: ref.read(nowProvider)(),
    );
    state = AsyncData(seen);
    try {
      await ref.read(recommendationSeenStoreProvider).save(userId, seen);
    } on Object {
      // Không lưu được thì chỉ nhớ tới khi mở lại app.
    }
    try {
      await ref.read(notificationSettingsSyncProvider).localSeenChanged(userId);
    } on Object {
      // Đồng bộ là việc phụ: lỗi ở đây không được làm hỏng việc ghi nhớ.
    }
  }

  /// Nhận cặp đã thấy từ server. Chỉ cho người đang đăng nhập, không đẩy ngược.
  void adopt(String userId, SeenRecommendation seen) {
    if (ref.read(currentUserIdProvider) != userId) return;
    state = AsyncData(seen);
  }
}

final notificationSettingsMetaStoreProvider =
    Provider<NotificationSettingsMetaStore>(
      (ref) => SharedPreferencesNotificationSettingsMetaStore(),
    );

/// Đồng bộ công tắc và cặp gợi ý đã thấy với Directus. Không tự chạy:
/// `startSync` giữ nó và gọi `start()`. Chỉ xem các provider ổn định.
final notificationSettingsSyncProvider =
    Provider<NotificationSettingsSyncService>((ref) {
      final service = NotificationSettingsSyncService(
        auth: ref.watch(authRepositoryProvider),
        api: ref.watch(directusClientProvider),
        prefs: ref.watch(notificationPrefsStoreProvider),
        seen: ref.watch(recommendationSeenStoreProvider),
        meta: ref.watch(notificationSettingsMetaStoreProvider),
        now: ref.watch(nowProvider),
        // Task 16 nối vào nền tảng đẩy.
        timeZone: () => null,
        onAdopted: (userId, {prefs, seen}) {
          if (prefs != null) {
            ref.read(notificationPrefsProvider.notifier).adopt(userId, prefs);
          }
          if (seen != null) {
            ref.read(recommendationSeenProvider.notifier).adopt(userId, seen);
          }
        },
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// Đủ dữ liệu để dịch vụ lập thông báo gợi ý.
///
/// [AsyncLoading] khi chưa có tài khoản hoặc còn nguồn đang tải / đang tải
/// lại: dịch vụ giữ nguyên gợi ý đã đặt. [AsyncError] khi một nguồn lỗi: dịch
/// vụ bỏ gợi ý, các loại khác vẫn chạy.
final recommendationSourceProvider =
    Provider<AsyncValue<RecommendationSource>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      final inputs = ref.watch(recommendationInputsProvider);
      final seen = ref.watch(recommendationSeenProvider);
      if (userId == null) return const AsyncLoading();
      final blocked = gate<RecommendationSource>([inputs, seen]);
      if (blocked != null) return blocked;
      return AsyncData(
        RecommendationSource(
          userId: userId,
          inputs: inputs.requireValue,
          seen: seen.requireValue,
        ),
      );
    });

/// Nhật ký thông báo của người đang đăng nhập; null khi chưa đăng nhập.
final notificationLogRepositoryProvider =
    Provider<NotificationLogRepository?>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      return NotificationLogRepository(
        ref.watch(appDatabaseProvider),
        userId: userId,
      );
    });

final notificationLogProvider = StreamProvider<List<NotificationLogEntry>>(
  (ref) =>
      ref.watch(notificationLogRepositoryProvider)?.watchAll() ??
      Stream.value(const []),
);

/// Cờ phiên bản đặt lịch thông báo của máy này.
final notificationScheduleVersionStoreProvider =
    Provider<NotificationScheduleVersionStore>(
      (ref) => SharedPreferencesNotificationScheduleVersionStore(),
    );

/// Dịch vụ giữ thông báo của hệ điều hành/trình duyệt khớp với kế hoạch.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    now: ref.watch(nowProvider),
    scheduleVersion: ref.watch(notificationScheduleVersionStoreProvider),
  );
  ref.listen(
    notificationPrefsProvider,
    (_, next) => service.setPrefs(next.value),
    fireImmediately: true,
  );
  ref.listen(
    recommendationSourceProvider,
    (_, next) => service.setRecommendationSource(next),
    fireImmediately: true,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Thông báo sắp tới trong 7 ngày, tính từ dữ liệu hiện có của người chơi.
/// Cùng [planNotifications] với dịch vụ, nên danh sách trên màn hình chính
/// là thứ sẽ được gửi.
final upcomingNotificationsProvider = Provider<List<PlannedNotification>>((
  ref,
) {
  final now = ref.watch(nowProvider)();
  final prefs = ref.watch(notificationPrefsProvider).value;
  // Gợi ý như dịch vụ: chỉ khi nguồn đủ và nhật ký đã nạp xong (không phải
  // giá trị cũ của người trước đang tải lại).
  final sourceAsync = ref.watch(recommendationSourceProvider);
  final source = sourceAsync.value;
  final log = ref.watch(notificationLogProvider);
  final logReady = log.hasValue && !log.isLoading;
  final ready = source != null && logReady;
  // Như dịch vụ: nguồn còn đang tải thì gợi ý đã đặt (trong nhật ký) vẫn nằm
  // trong lịch, nên vẫn hiện ở đây.
  final keep =
      !ready &&
      logReady &&
      sourceAsync is AsyncLoading &&
      (prefs ?? const NotificationPrefs()).recommendation;
  final planned = planNotifications(
    recommendation: ready ? source.inputs : null,
    lastSeenRecommendation: ready
        ? recommendationBaseline(
            shownOnHome: source.seen,
            log: log.requireValue,
            now: now,
          )
        : null,
    cues: ref.watch(cueEquipmentProvider).value ?? const [],
    slots: ref.watch(scheduleProvider).value ?? const [],
    streak: streakStateOf(
      logs: ref.watch(drillLogsProvider).value ?? const [],
      timerSessions: ref.watch(timerSessionsProvider).value ?? const [],
      today: now,
    ),
    prefs: prefs ?? const NotificationPrefs(),
    now: now,
    limit: keep ? 1 << 20 : maxPendingNotifications,
  );
  final plan = keep
      ? withLoggedRecommendations(
          planned,
          log.requireValue,
          now: now,
          limit: maxPendingNotifications,
        )
      : planned;
  final horizon = now.add(const Duration(days: scheduleReminderHorizonDays));
  return [
    for (final n in plan)
      if (n.at.isBefore(horizon)) n,
  ];
});
