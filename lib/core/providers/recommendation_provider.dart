import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/recommendation.dart';

/// Today's recommendation computed from all data streams.
///
/// Waits for all three streams to have loaded — returns null during loading.
final todayRecommendationProvider = Provider<TodayRecommendation?>((ref) {
  final drillsAsync = ref.watch(drillsProvider);
  final knowledgeAsync = ref.watch(knowledgeProvider);
  final logsAsync = ref.watch(drillLogsProvider);

  final drills = drillsAsync.hasValue ? drillsAsync.value : null;
  final knowledge = knowledgeAsync.hasValue ? knowledgeAsync.value : null;
  final logs = logsAsync.hasValue ? logsAsync.value : null;

  // Not ready until all three streams have loaded at least once
  if (drills == null || knowledge == null || logs == null) return null;

  final nowFn = ref.watch(nowProvider);
  final today = nowFn();

  return computeRecommendation(
    drills: drills,
    logs: logs,
    knowledge: knowledge,
    timerSessions: const [], // Timer sessions not persisted yet
    schedule: const [], // Schedule not persisted yet
    today: today,
  );
});
