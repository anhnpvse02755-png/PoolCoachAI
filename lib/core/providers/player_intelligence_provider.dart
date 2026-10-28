import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/player_intelligence.dart' show computePlayerIntelligence, PlayerIntelligence;

/// Player intelligence computed from drills, logs, matches and the latest BU.
///
/// Returns null until every source is loaded and is not the previous
/// account's stale value (hasValue && !isLoading).
final playerIntelligenceProvider = Provider<PlayerIntelligence?>((ref) {
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final matches = ref.watch(matchesProvider);
  final bu = ref.watch(latestBuResultProvider);

  if (gate<PlayerIntelligence>([drills, logs, matches, bu]) != null) return null;

  return computePlayerIntelligence(
    drills: drills.value!,
    logs: logs.value!,
    matches: matches.value!,
    latestBu: bu.value,
  );
});
