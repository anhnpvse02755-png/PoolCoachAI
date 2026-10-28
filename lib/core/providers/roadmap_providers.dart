import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/rank_check.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:uuid/uuid.dart';

/// Mục tiêu và thành tích của người đang đăng nhập; null khi chưa đăng nhập.
final roadmapRepositoryProvider = Provider<RoadmapRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return RoadmapRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
    newId: const Uuid().v4,
  );
});

final goalProvider = StreamProvider<GoalRecord?>((ref) {
  final repo = ref.watch(roadmapRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchGoal();
});

final achievementsProvider = StreamProvider<List<Achievement>>((ref) {
  final repo = ref.watch(roadmapRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchAchievements();
});

bool _ready(AsyncValue<Object?> value) => value.hasValue && !value.isLoading;

/// Đã tải xong và không phải giá trị cũ của người trước (đang tải lại).
///
/// Bài hoàn tất mà thiếu bản Đề II (dữ liệu đồng bộ hỏng) không có điểm mất
/// từng bài: coi như chưa có kết quả dùng được. Lỗi khác khi chấm thành
/// [AsyncError] để màn hình báo lỗi thay vì Provider ném ra và treo vòng tải.
final latestBuResultProvider = Provider<AsyncValue<BuResult?>>((ref) {
  final tests = ref.watch(buTestsProvider);
  final testsGate = gate<BuResult?>([tests]);
  if (testsGate != null) return testsGate;
  final id = latestCompletedTestId(tests.value!);
  if (id == null) return const AsyncData(null);
  final snapshot = ref.watch(testSnapshotProvider(id));
  final snapshotGate = gate<BuResult?>([snapshot]);
  if (snapshotGate != null) return snapshotGate;
  final value = snapshot.value;
  if (value == null ||
      !value.test.isCompleted ||
      value.test.examIIVersion == null) {
    return const AsyncData(null);
  }
  try {
    return AsyncData(buResultFrom(value));
  } catch (e, st) {
    return AsyncError(e, st);
  }
});

/// Tính lại khi mục tiêu, hạng, bài BU hoặc dữ liệu tập thay đổi.
final roadmapProvider = Provider<AsyncValue<Roadmap?>>((ref) {
  final goal = ref.watch(goalProvider);
  final rank = ref.watch(playerRankProvider);
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final tests = ref.watch(buTestsProvider);
  final result = ref.watch(latestBuResultProvider);
  final matches = ref.watch(matchesProvider);
  final blocked = gate<Roadmap?>([
    goal,
    rank,
    drills,
    logs,
    tests,
    result,
    matches,
  ]);
  if (blocked != null) return blocked;

  final currentGoal = goal.value?.goal;
  if (currentGoal == null) return const AsyncData(null);
  return AsyncData(
    buildRoadmap(
      goal: currentGoal,
      rank: rank.value,
      drills: drills.value!,
      logs: logs.value!,
      tests: tests.value!,
      latestResult: result.value,
      matches: matches.value!,
      today: ref.watch(nowProvider)(),
    ),
  );
});

/// Ghi thành tích từ sự kiện thật. App phải nghe provider để Riverpod 3 chạy.
final achievementRecorderProvider = Provider<void>((ref) {
  final repo = ref.watch(roadmapRepositoryProvider);
  final goal = ref.watch(goalProvider);
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final existing = ref.watch(achievementsProvider);
  final skillTests = ref.watch(skillTestsProvider);
  if (repo == null ||
      gate<void>([goal, drills, logs, existing, skillTests]) != null) {
    return;
  }

  final fresh = newAchievements(
    goal: goal.value?.goal,
    drills: drills.value!,
    logs: logs.value!,
    skillTests: skillTests.value!,
    existing: {for (final achievement in existing.value!) achievement.key},
    today: ref.watch(nowProvider)(),
  );
  if (fresh.isNotEmpty) unawaited(repo.recordAchievements(fresh));
});

/// Service đã chạy sẵn, như [assessmentSyncProvider].
final roadmapSyncProvider = Provider<RoadmapSyncService>((ref) {
  final service = RoadmapSyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
  )..start();
  ref.onDispose(service.dispose);
  return service;
});

/// Gợi ý làm lại bài BU (spec 2026-10-28 mục 6.5). Null khi một nguồn chưa
/// tải xong hoặc là giá trị cũ của người trước. Không bao giờ đổi hạng.
final rankCheckSignalProvider = Provider<RankCheckSignal?>((ref) {
  final rank = ref.watch(playerRankProvider);
  final bu = ref.watch(latestBuResultProvider);
  final pi = ref.watch(playerIntelligenceProvider);
  if (!_ready(rank) || !_ready(bu) || pi == null) return null;
  return rankCheckSignal(
    rank: rank.value,
    latestBu: bu.value,
    pi: pi,
    today: ref.watch(nowProvider)(),
  );
});
