import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/rank_check.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/roadmap_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  final at = DateTime(2026, 9, 20, 9);

  List<DrillLog> passes(String drillId) => [
        for (var i = 0; i < 3; i++)
          DrillLog(
            id: '$drillId-$i',
            drillId: drillId,
            date: DateTime(2026, 9, 19 + i, 9),
            score: 9,
            attempts: 10,
          ),
      ];

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  test('không có mục tiêu: lộ trình là null, không phải đang tải', () async {
    final container = testContainer();
    addTearDown(container.dispose);
    container.listen(roadmapProvider, (_, _) {});
    await settle();
    expect(container.read(roadmapProvider), const AsyncData<Roadmap?>(null));
  });

  test('có mục tiêu thuần thục: lộ trình đi theo dữ liệu tập', () async {
    final container = testContainer(
      goal: GoalRecord(
        updatedAt: at,
        goal: PlayerGoal(
          goalId: 'g',
          kind: GoalKind.thuanThucKyNang,
          category: SkillCategory.aiming,
          createdAt: at,
        ),
      ),
      logs: passes('d1'),
    );
    addTearDown(container.dispose);
    container.listen(roadmapProvider, (_, _) {});
    await settle();
    final roadmap = container.read(roadmapProvider).value!;
    expect(roadmap.steps.first.drillId, 'd1');
    expect(roadmap.steps.first.status, StepStatus.xong);
  });

  GoalRecord lenHangGoal() => GoalRecord(
        updatedAt: at,
        goal: PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at),
      );
  PlayerRank rankH() => PlayerRank(
        rank: Rank.h,
        source: RankSource.estimated,
        onboardingState: OnboardingState.done,
        updatedAt: at,
      );

  test('lộ trình còn đang tải khi danh sách trận chưa về, có dữ liệu khi về', () async {
    final matches = StreamController<List<PoolMatch>>();
    addTearDown(matches.close);
    final container = testContainer(
      goal: lenHangGoal(),
      rank: rankH(),
      matchesStream: matches.stream,
    );
    addTearDown(container.dispose);
    container.listen(roadmapProvider, (_, _) {});
    await settle();
    expect(container.read(roadmapProvider).isLoading, isTrue);
    expect(container.read(roadmapProvider).hasValue, isFalse);
    matches.add(const <PoolMatch>[]);
    await settle();
    expect(container.read(roadmapProvider).value!.target, Rank.g);
  });

  test('danh sách trận rỗng vẫn cho ra lộ trình', () async {
    final container = testContainer(
      goal: lenHangGoal(),
      rank: rankH(),
      matches: const <PoolMatch>[],
    );
    addTearDown(container.dispose);
    container.listen(roadmapProvider, (_, _) {});
    await settle();
    final state = container.read(roadmapProvider);
    expect(state.isLoading, isFalse);
    expect(state.value!.steps, isNotEmpty);
  });

  test('Lên hạng đọc hạng hiện tại', () async {
    final container = testContainer(
      goal: GoalRecord(
        updatedAt: at,
        goal: PlayerGoal(
          goalId: 'g',
          kind: GoalKind.lenHang,
          createdAt: at,
        ),
      ),
      rank: PlayerRank(
        rank: Rank.h,
        source: RankSource.estimated,
        onboardingState: OnboardingState.done,
        updatedAt: at,
      ),
    );
    addTearDown(container.dispose);
    container.listen(roadmapProvider, (_, _) {});
    await settle();
    expect(container.read(roadmapProvider).value!.target, Rank.g);
  });

  test('bộ ghi thành tích ghi sự kiện thật theo ngày buổi đạt thứ ba', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db, logs: passes('d1'));
    addTearDown(container.dispose);
    container.listen(achievementRecorderProvider, (_, _) {});
    await settle();
    final rows = await db.select(db.achievementRows).get();
    final ready = rows
        .where((row) => row.kind == AchievementKind.duDieuKienLenCap.name)
        .single;
    expect(ready.refId, 'd1');
    expect(ready.achievedAt, DateTime(2026, 9, 21, 9));
  });

  test('đang đổi người: bộ ghi thành tích không ghi gì', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(
      db,
      logs: passes('d1'),
      auth: FakeAuthRepository(const SignedOut()),
    );
    addTearDown(container.dispose);
    container.listen(achievementRecorderProvider, (_, _) {});
    await settle();
    expect(await db.select(db.achievementRows).get(), isEmpty);
  });

  group('rankCheckSignalProvider', () {
    final verifiedD = PlayerRank(
      rank: Rank.d,
      source: RankSource.verified,
      buScore: 120,
      testId: 't',
      onboardingState: OnboardingState.done,
      updatedAt: at,
    );
    final oldBu = buResultGraded(completedAt: at.subtract(const Duration(days: 30)));

    test('đủ nguồn: có gợi ý kiểm tra hạng hiện tại', () async {
      final container = testContainer(
        rank: verifiedD,
        buResult: oldBu,
        drills: roadmapDrills,
        logs: decliningLogs(at.subtract(const Duration(days: 10))),
        now: at,
      );
      addTearDown(container.dispose);
      container.listen(rankCheckSignalProvider, (_, _) {});
      await settle();
      final signal = container.read(rankCheckSignalProvider)!;
      expect(signal.direction, RankCheckDirection.down);
      expect(signal.rank, Rank.d);
    });

    test('trận đang tải lại với giá trị cũ: rankCheckSignalProvider là null', () async {
      final container = testContainer(
        rank: verifiedD,
        buResult: oldBu,
        drills: roadmapDrills,
        logs: decliningLogs(at.subtract(const Duration(days: 10))),
        now: at,
      );
      addTearDown(container.dispose);
      container.listen(rankCheckSignalProvider, (_, _) {});
      await settle();
      expect(container.read(rankCheckSignalProvider), isNotNull);

      final stale = ProviderContainer(
        overrides: [
          drillsProvider.overrideWith((ref) => Stream.value(roadmapDrills)),
          drillLogsProvider.overrideWith(
            (ref) => Stream.value(decliningLogs(at.subtract(const Duration(days: 10)))),
          ),
          // copyWithPrevious là API nội bộ của riverpod; chỉ dùng trong test.
          matchesProvider.overrideWithValue(
            // ignore: invalid_use_of_internal_member
            const AsyncLoading<List<PoolMatch>>().copyWithPrevious(
              const AsyncData<List<PoolMatch>>([]),
            ),
          ),
          latestBuResultProvider.overrideWithValue(AsyncData<BuResult?>(oldBu)),
          playerRankProvider.overrideWith((ref) => Stream.value(verifiedD)),
          nowProvider.overrideWithValue(() => at),
        ],
      );
      addTearDown(stale.dispose);
      stale.listen(rankCheckSignalProvider, (_, _) {});
      await settle();
      expect(stale.read(rankCheckSignalProvider), isNull);
    });

    test('hạng đang tải lại với giá trị cũ: null', () async {
      final container = ProviderContainer(
        overrides: [
          drillsProvider.overrideWith((ref) => Stream.value(roadmapDrills)),
          drillLogsProvider.overrideWith(
            (ref) => Stream.value(decliningLogs(at.subtract(const Duration(days: 10)))),
          ),
          matchesProvider.overrideWith((ref) => Stream.value(const <PoolMatch>[])),
          latestBuResultProvider.overrideWithValue(AsyncData<BuResult?>(oldBu)),
          playerRankProvider.overrideWithValue(
            // ignore: invalid_use_of_internal_member
            const AsyncLoading<PlayerRank?>().copyWithPrevious(AsyncData<PlayerRank?>(verifiedD)),
          ),
          nowProvider.overrideWithValue(() => at),
        ],
      );
      addTearDown(container.dispose);
      container.listen(rankCheckSignalProvider, (_, _) {});
      await settle();
      expect(container.read(rankCheckSignalProvider), isNull);
    });
  });

  group('latestBuResultProvider với bài BU hỏng', () {
    test('hoàn tất nhưng thiếu bản Đề II: không có kết quả dùng được, không ném lỗi', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 'hong', userId: 'u1', startedAt: at, tableSize: 'nineFootPlus',
          completedAt: Value(at), totalScore: const Value(80), resultRank: const Value('g')));
      final container = dbContainer(db);
      addTearDown(container.dispose);
      container.listen(latestBuResultProvider, (_, _) {});
      await settle();
      expect(container.read(latestBuResultProvider), const AsyncData<BuResult?>(null));
    });

    test('lỗi khác khi chấm: thành AsyncError, không ném ra ngoài', () async {
      final bad = TestSnapshot(
        test: BuTest(
          id: 'sai', startedAt: at, tableSize: TableSize.nineFootPlus, completedAt: at,
          examIScore: 60, examIIVersion: ExamIIVersion.masters, totalScore: 80,
        ),
        // F1 chấm theo cú; đưa kết quả kiểu số bi để buộc chấm điểm ném lỗi.
        attempts: {'F1': CountAttempts(const [1])},
      );
      final container = ProviderContainer(
        overrides: [
          buTestsProvider.overrideWith((ref) => Stream.value([bad.test])),
          testSnapshotProvider.overrideWith((ref, id) => Stream.value(bad)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(latestBuResultProvider, (_, _) {});
      await settle();
      expect(container.read(latestBuResultProvider).hasError, isTrue);
    });
  });
}
