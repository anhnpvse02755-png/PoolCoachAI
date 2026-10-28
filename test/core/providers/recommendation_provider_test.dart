import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

import '../../support/match_fixtures.dart';
import '../../support/roadmap_fixtures.dart';

/// Tầng provider — mục 5 của thiết kế.
///
/// Luật đang được bảo vệ: thiếu bất kỳ nguồn nào thì giữ trạng thái tải;
/// lỗi ở một nguồn phải được chuyển tiếp thay vì để Home quay vô hạn.
void main() {
  final today = DateTime(2026, 9, 22, 10, 0);

  final drills = <Drill>[
    const Drill(
      id: 'd1',
      cat: SkillCategory.aiming,
      name: 'Đường thẳng cơ bản',
      level: 1,
      unit: 'lần trúng / 10',
      passThreshold: 0.8,
      goal: 'Mục tiêu.',
      steps: ['Bước 1'],
    ),
    const Drill(
      id: 'd8',
      cat: SkillCategory.bank,
      name: 'Cân bi một băng',
      level: 4,
      unit: 'lần trúng / 10',
      passThreshold: 0.5,
      goal: 'Mục tiêu.',
      steps: ['Bước 1'],
    ),
  ];

  final knowledge = <KnowledgeArticle>[
    const KnowledgeArticle(
      id: 'k1',
      cat: SkillCategory.aiming,
      title: 'Nguyên lý bi ảo',
      body: 'Thân bài.',
    ),
  ];

  /// Stream không bao giờ bắn — đứng mãi ở trạng thái đang tải.
  Stream<T> never<T>() => StreamController<T>().stream;

  ProviderContainer containerWith({
    Stream<List<Drill>>? drillStream,
    Stream<List<KnowledgeArticle>>? knowledgeStream,
    Stream<List<DrillLog>>? logStream,
    Stream<List<TimerSession>>? timerSessionStream,
    Stream<List<ScheduleSlot>>? scheduleStream,
    Stream<List<PoolMatch>>? matchStream,
    AsyncValue<BuResult?> latestBu = const AsyncData<BuResult?>(null),
  }) {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => today),
        drillsProvider.overrideWith(
          (ref) => drillStream ?? Stream.value(drills),
        ),
        knowledgeProvider.overrideWith(
          (ref) => knowledgeStream ?? Stream.value(knowledge),
        ),
        drillLogsProvider.overrideWith(
          (ref) => logStream ?? Stream.value(const <DrillLog>[]),
        ),
        timerSessionsProvider.overrideWith(
          (ref) => timerSessionStream ?? Stream.value(const <TimerSession>[]),
        ),
        scheduleProvider.overrideWith(
          (ref) => scheduleStream ?? Stream.value(const <ScheduleSlot>[]),
        ),
        matchesProvider.overrideWith(
          (ref) => matchStream ?? Stream.value(const <PoolMatch>[]),
        ),
        latestBuResultProvider.overrideWithValue(latestBu),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Giữ hai provider suy luận sống rồi xả hàng đợi sự kiện, để các
  /// stream nguồn kịp bắn lần đầu.
  Future<void> settle(ProviderContainer container) async {
    container.listen(todayRecommendationProvider, (_, _) {});
    container.listen(playerIntelligenceProvider, (_, _) {});
    await pumpEventQueue();
  }

  group('todayRecommendationProvider', () {
    test('chưa nguồn nào có dữ liệu thì vẫn đang tải', () {
      final container = containerWith(
        drillStream: never(),
        knowledgeStream: never(),
        logStream: never(),
      );

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('thiếu riêng danh sách bài tập thì vẫn là null', () async {
      final container = containerWith(drillStream: never());
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('thiếu riêng bài kiến thức thì vẫn là null', () async {
      final container = containerWith(knowledgeStream: never());
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('thiếu riêng log thì vẫn là null', () async {
      final container = containerWith(logStream: never());
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('thiếu riêng buổi tập tự do thì vẫn là null', () async {
      final container = containerWith(timerSessionStream: never());
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('thiếu riêng lịch tuần thì vẫn là null', () async {
      final container = containerWith(scheduleStream: never());
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('lỗi ở nguồn lịch được chuyển tiếp cho màn hình', () async {
      final container = containerWith(
        scheduleStream: Stream.error(StateError('database offline')),
      );
      await settle(container);

      final result = container.read(todayRecommendationProvider);
      expect(result, isA<AsyncError<TodayRecommendation>>());
      expect(result.error, isA<StateError>());
    });

    test('trận yếu thì gợi ý theo yếu trong trận, mang tín hiệu', () async {
      final container = containerWith(
        matchStream: Stream.value(
          matchesWeakAt(SkillCategory.position, at: today),
        ),
      );
      await settle(container);

      final rec = container.read(todayRecommendationProvider).requireValue;
      expect(rec.reason, PickReason.matchWeakness);
      expect(rec.cat, SkillCategory.position);
      expect(rec.matchSignal!.category, SkillCategory.position);
    });

    test('nhóm chỉ yếu theo BU (không mastery) được luật yếu nhất chọn',
        () async {
      final bu = buResultGraded(
        completedAt: DateTime(2026, 9, 1),
        lost: const {'F7': 20, 'F6': 10},
      );
      final container = containerWith(latestBu: AsyncData<BuResult?>(bu));
      await settle(container);

      final pi = container.read(playerIntelligenceProvider)!;
      expect(pi.categories[SkillCategory.aiming]!.mastery, isNull);
      expect(pi.buPercent[SkillCategory.aiming], lessThan(55));

      final rec = container.read(todayRecommendationProvider).requireValue;
      expect(rec.reason, PickReason.weakest);
      expect(rec.cat, SkillCategory.aiming);
      expect(rec.matchSignal, isNull);
    });

    test('trận đang tải lại với giá trị cũ: gợi ý vẫn đang tải', () async {
      final container = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(() => today),
          drillsProvider.overrideWith((ref) => Stream.value(drills)),
          knowledgeProvider.overrideWith((ref) => Stream.value(knowledge)),
          drillLogsProvider.overrideWith(
            (ref) => Stream.value(const <DrillLog>[]),
          ),
          timerSessionsProvider.overrideWith(
            (ref) => Stream.value(const <TimerSession>[]),
          ),
          scheduleProvider.overrideWith(
            (ref) => Stream.value(const <ScheduleSlot>[]),
          ),
          matchesProvider.overrideWithValue(
            // ignore: invalid_use_of_internal_member
            const AsyncLoading<List<PoolMatch>>().copyWithPrevious(
              AsyncData(
                matchesWeakAt(SkillCategory.position, at: today),
              ),
            ),
          ),
          latestBuResultProvider.overrideWithValue(
            const AsyncData<BuResult?>(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('BU đang tải thì gợi ý vẫn đang tải', () async {
      final container = containerWith(
        latestBu: const AsyncLoading<BuResult?>(),
      );
      await settle(container);

      expect(
        container.read(todayRecommendationProvider),
        isA<AsyncLoading<TodayRecommendation>>(),
      );
    });

    test('lỗi ở trận thì chuyển lỗi', () async {
      final container = containerWith(
        matchStream: Stream.error(StateError('matches offline')),
      );
      await settle(container);

      final result = container.read(todayRecommendationProvider);
      expect(result, isA<AsyncError<TodayRecommendation>>());
      expect(result.error, isA<StateError>());
    });

    test('lỗi ở BU chỉ mất phần bổ sung: gợi ý vẫn tính, không báo lỗi', () async {
      final container = containerWith(
        latestBu: AsyncError<BuResult?>(StateError('bu offline'), StackTrace.empty),
      );
      await settle(container);

      final result = container.read(todayRecommendationProvider);
      expect(result, isA<AsyncData<TodayRecommendation>>());
    });

    test('BU đang tải lại mà còn lỗi cũ vẫn tính là đang tải', () async {
      // ignore: invalid_use_of_internal_member
      final stale = const AsyncLoading<BuResult?>().copyWithPrevious(
        AsyncError<BuResult?>(StateError('bu cũ'), StackTrace.empty),
      );
      final container = containerWith(latestBu: stale);
      await settle(container);

      expect(container.read(todayRecommendationProvider), isA<AsyncLoading<TodayRecommendation>>());
    });

    test('đủ năm nguồn thì tính ra gợi ý của người mới', () async {
      final container = containerWith();
      await settle(container);

      final rec = container.read(todayRecommendationProvider).requireValue;

      expect(rec.reason, PickReason.newcomer);
      expect(rec.cat, SkillCategory.aiming);
    });

    test('tính theo ngày được tiêm, không theo đồng hồ máy', () async {
      final controller = StreamController<List<DrillLog>>();
      addTearDown(controller.close);
      final container = containerWith(logStream: controller.stream);

      // Buổi tập đúng hôm nay theo đồng hồ tiêm vào → streak tính được 1.
      controller.add([
        DrillLog(id: 'l1', drillId: 'd1', date: today, score: 9, attempts: 10),
      ]);
      await settle(container);

      expect(
        container.read(todayRecommendationProvider).requireValue.streak,
        1,
      );
    });

    test('log đổi thì gợi ý tính lại, không giữ kết quả cũ', () async {
      final controller = StreamController<List<DrillLog>>();
      addTearDown(controller.close);
      final container = containerWith(logStream: controller.stream);

      controller.add(const <DrillLog>[]);
      await settle(container);
      expect(
        container.read(todayRecommendationProvider).requireValue.reason,
        PickReason.newcomer,
      );

      controller.add([
        for (var i = 0; i < 3; i++)
          DrillLog(
            id: 'kem-$i',
            drillId: 'd8',
            date: today.subtract(Duration(hours: 3 - i)),
            score: 1,
            attempts: 10,
          ),
      ]);
      await settle(container);

      final rec = container.read(todayRecommendationProvider).requireValue;
      expect(rec.reason, PickReason.weakest);
      expect(rec.cat, SkillCategory.bank);
    });
  });

  group('playerIntelligenceProvider', () {
    test('thiếu nguồn thì là null', () {
      final container = containerWith(drillStream: never(), logStream: never());

      expect(container.read(playerIntelligenceProvider), isNull);
    });

    test('đủ nguồn thì mọi nhóm kỹ năng đều có mặt', () async {
      final container = containerWith();
      await settle(container);

      final pi = container.read(playerIntelligenceProvider);

      expect(pi, isNotNull);
      expect(pi!.categories.keys.toSet(), SkillCategory.values.toSet());
      expect(pi.hasAnyData, isFalse);
    });
  });
}
