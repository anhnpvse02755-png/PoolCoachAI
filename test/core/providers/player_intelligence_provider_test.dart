import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/match_fixtures.dart';
import '../../support/roadmap_fixtures.dart';

void main() {
  final bu = buResultGraded(
    completedAt: DateTime(2026, 10, 10),
    lost: const {'F7': 20, 'F6': 10},
  );

  // Không gõ kiểu cho danh sách override (trình biên dịch sập).
  ProviderContainer containerWith({
    required Stream<List<PoolMatch>> matches,
    required AsyncValue<BuResult?> latestBu,
  }) {
    final container = ProviderContainer(
      overrides: [
        drillsProvider.overrideWith((ref) => Stream.value(roadmapDrills)),
        drillLogsProvider.overrideWith((ref) => Stream.value(const <DrillLog>[])),
        matchesProvider.overrideWith((ref) => matches),
        latestBuResultProvider.overrideWithValue(latestBu),
      ],
    );
    addTearDown(container.dispose);
    container.listen(playerIntelligenceProvider, (_, _) {});
    return container;
  }

  test('đủ nguồn: PI mang matchWeak và buPercent', () async {
    final container = containerWith(
      matches: Stream.value(
          matchesWeakAt(SkillCategory.position, at: DateTime(2026, 10, 20))),
      latestBu: AsyncData<BuResult?>(bu),
    );
    await pumpEventQueue();
    final pi = container.read(playerIntelligenceProvider);
    expect(pi, isNotNull);
    expect(pi!.matchWeak.first.category, SkillCategory.position);
    expect(pi.buPercent[SkillCategory.aiming], 48);
    expect(pi.weak, [SkillCategory.aiming]);
  });

  test('trận chưa bắn giá trị đầu: PI là null', () async {
    final container = containerWith(
      matches: StreamController<List<PoolMatch>>().stream,
      latestBu: const AsyncData<BuResult?>(null),
    );
    await pumpEventQueue();
    expect(container.read(playerIntelligenceProvider), isNull);
  });

  test('BU đang tải: PI là null', () async {
    final container = containerWith(
      matches: Stream.value(const <PoolMatch>[]),
      latestBu: const AsyncLoading<BuResult?>(),
    );
    await pumpEventQueue();
    expect(container.read(playerIntelligenceProvider), isNull);
  });

  test('trận đang tải lại với giá trị cũ (đổi tài khoản): PI là null', () async {
    final old = matchesWeakAt(SkillCategory.aiming, at: DateTime(2026, 10, 20));
    final container = ProviderContainer(
      overrides: [
        drillsProvider.overrideWith((ref) => Stream.value(roadmapDrills)),
        drillLogsProvider.overrideWith((ref) => Stream.value(const <DrillLog>[])),
        // copyWithPrevious là API nội bộ của riverpod; chỉ dùng trong test.
        matchesProvider.overrideWithValue(
          // ignore: invalid_use_of_internal_member
          const AsyncLoading<List<PoolMatch>>().copyWithPrevious(AsyncData(old)),
        ),
        latestBuResultProvider.overrideWithValue(const AsyncData<BuResult?>(null)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(playerIntelligenceProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(playerIntelligenceProvider), isNull);
  });
}
