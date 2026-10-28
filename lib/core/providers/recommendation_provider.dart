import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/recommendation.dart';

/// Today's recommendation computed from all data streams.
///
/// Waits for all recommendation inputs and surfaces source errors to Home.
/// The latest BU result only enriches the recommendation: when it errored the
/// recommendation is computed without it (Roadmap and Rank still show that
/// error). A BU that is reloading still counts as loading.
final todayRecommendationProvider = Provider<AsyncValue<TodayRecommendation>>((
  ref,
) {
  final drillsAsync = ref.watch(drillsProvider);
  final knowledgeAsync = ref.watch(knowledgeProvider);
  final logsAsync = ref.watch(drillLogsProvider);
  final timerSessionsAsync = ref.watch(timerSessionsProvider);
  final scheduleAsync = ref.watch(scheduleProvider);
  final matchesAsync = ref.watch(matchesProvider);
  final buAsync = ref.watch(latestBuResultProvider);

  final blocked = gate<TodayRecommendation>([
    drillsAsync,
    knowledgeAsync,
    logsAsync,
    timerSessionsAsync,
    scheduleAsync,
    matchesAsync,
  ]);
  if (blocked != null) return blocked;
  final buFailed = buAsync.hasError && !buAsync.isLoading;
  if (!buFailed && gate<TodayRecommendation>([buAsync]) != null) {
    return const AsyncLoading();
  }

  final nowFn = ref.watch(nowProvider);
  final today = nowFn();

  return AsyncData(
    computeRecommendation(
      drills: drillsAsync.requireValue,
      logs: logsAsync.requireValue,
      knowledge: knowledgeAsync.requireValue,
      timerSessions: timerSessionsAsync.requireValue,
      schedule: scheduleAsync.requireValue,
      today: today,
      matches: matchesAsync.requireValue,
      latestBu: buFailed ? null : buAsync.value,
    ),
  );
});
