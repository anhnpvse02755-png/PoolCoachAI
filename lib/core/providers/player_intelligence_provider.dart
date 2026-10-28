import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/player_intelligence.dart' show computePlayerIntelligence, PlayerIntelligence;

bool _ready(AsyncValue<Object?> value) => value.hasValue && !value.isLoading;

/// Player intelligence computed from drills, logs, matches and the latest BU.
///
/// Returns null until every source is loaded and is not the previous
/// account's stale value (hasValue && !isLoading).
final playerIntelligenceProvider = Provider<PlayerIntelligence?>((ref) {
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final matches = ref.watch(matchesProvider);
  final bu = ref.watch(latestBuResultProvider);

  if (![drills, logs, matches, bu].every(_ready)) return null;

  return computePlayerIntelligence(
    drills: drills.value!,
    logs: logs.value!,
    matches: matches.value!,
    latestBu: bu.value,
  );
});
