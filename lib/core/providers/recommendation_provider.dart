import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/recommendation.dart';

bool _ready(AsyncValue<Object?> value) => value.hasValue && !value.isLoading;

/// Today's recommendation computed from all data streams.
///
/// Waits for all recommendation inputs and surfaces source errors to Home.
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

  if (drillsAsync.hasError) {
    return AsyncError(drillsAsync.error!, drillsAsync.stackTrace!);
  }
  if (knowledgeAsync.hasError) {
    return AsyncError(knowledgeAsync.error!, knowledgeAsync.stackTrace!);
  }
  if (logsAsync.hasError) {
    return AsyncError(logsAsync.error!, logsAsync.stackTrace!);
  }
  if (timerSessionsAsync.hasError) {
    return AsyncError(
      timerSessionsAsync.error!,
      timerSessionsAsync.stackTrace!,
    );
  }
  if (scheduleAsync.hasError) {
    return AsyncError(scheduleAsync.error!, scheduleAsync.stackTrace!);
  }
  if (matchesAsync.hasError) {
    return AsyncError(matchesAsync.error!, matchesAsync.stackTrace!);
  }
  if (buAsync.hasError) {
    return AsyncError(buAsync.error!, buAsync.stackTrace!);
  }
  if (!drillsAsync.hasValue ||
      !knowledgeAsync.hasValue ||
      !logsAsync.hasValue ||
      !timerSessionsAsync.hasValue ||
      !scheduleAsync.hasValue ||
      !_ready(matchesAsync) ||
      !_ready(buAsync)) {
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
      latestBu: buAsync.value,
    ),
  );
});
