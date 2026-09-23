import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/player_intelligence.dart' show computePlayerIntelligence, PlayerIntelligence;

/// Player intelligence computed from drills and logs.
///
/// Waits for both streams to have loaded — returns null during loading.
final playerIntelligenceProvider = Provider<PlayerIntelligence?>((ref) {
  final drillsAsync = ref.watch(drillsProvider);
  final logsAsync = ref.watch(drillLogsProvider);

  final drills = drillsAsync.hasValue ? drillsAsync.value : null;
  final logs = logsAsync.hasValue ? logsAsync.value : null;

  // Not ready until both streams have loaded at least once
  if (drills == null || logs == null) return null;

  return computePlayerIntelligence(drills: drills, logs: logs);
});
