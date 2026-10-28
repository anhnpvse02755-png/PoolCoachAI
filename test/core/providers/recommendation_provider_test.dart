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
        matchesProvider.overrideWith((ref) => Stream.value(const <PoolMatch>[])),
        latestBuResultProvider.overrideWithValue(const AsyncData<BuResult?>(null)),
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
