import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/recommendation.dart';

/// Đầu vào của gợi ý hôm nay, gom từ mọi nguồn dữ liệu.
///
/// Chờ mọi nguồn và chuyển tiếp lỗi nguồn. Kết quả BU mới nhất chỉ bổ sung
/// cho gợi ý: khi nó lỗi thì tính không có nó (Roadmap và Rank vẫn hiện lỗi
/// đó). BU đang tải lại vẫn tính là đang tải. Trang chủ và dịch vụ thông báo
/// dùng chung provider này, nên cùng một gợi ý.
final recommendationInputsProvider = Provider<AsyncValue<RecommendationInputs>>(
  (ref) {
    final drillsAsync = ref.watch(drillsProvider);
    final knowledgeAsync = ref.watch(knowledgeProvider);
    final logsAsync = ref.watch(drillLogsProvider);
    final timerSessionsAsync = ref.watch(timerSessionsProvider);
    final scheduleAsync = ref.watch(scheduleProvider);
    final matchesAsync = ref.watch(matchesProvider);
    final buAsync = ref.watch(latestBuResultProvider);

    final blocked = gate<RecommendationInputs>([
      drillsAsync,
      knowledgeAsync,
      logsAsync,
      timerSessionsAsync,
      scheduleAsync,
      matchesAsync,
    ]);
    if (blocked != null) return blocked;
    final buFailed = buAsync.hasError && !buAsync.isLoading;
    if (!buFailed && gate<RecommendationInputs>([buAsync]) != null) {
      return const AsyncLoading();
    }

    return AsyncData(
      RecommendationInputs(
        drills: drillsAsync.requireValue,
        logs: logsAsync.requireValue,
        knowledge: knowledgeAsync.requireValue,
        timerSessions: timerSessionsAsync.requireValue,
        schedule: scheduleAsync.requireValue,
        matches: matchesAsync.requireValue,
        latestBu: buFailed ? null : buAsync.value,
      ),
    );
  },
);

/// Gợi ý hôm nay: [recommendationInputsProvider] tính tại [nowProvider].
final todayRecommendationProvider = Provider<AsyncValue<TodayRecommendation>>((
  ref,
) {
  final inputs = ref.watch(recommendationInputsProvider);
  final nowFn = ref.watch(nowProvider);
  return switch (inputs) {
    AsyncData(:final value) => AsyncData(value.recommendFor(nowFn())),
    AsyncError(:final error, :final stackTrace) => AsyncError(
      error,
      stackTrace,
    ),
    _ => const AsyncLoading(),
  };
});
