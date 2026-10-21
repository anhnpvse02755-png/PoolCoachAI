import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/recommendation.dart';

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
  if (!drillsAsync.hasValue ||
      !knowledgeAsync.hasValue ||
      !logsAsync.hasValue ||
      !timerSessionsAsync.hasValue ||
      !scheduleAsync.hasValue) {
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
    ),
  );
});
