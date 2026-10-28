import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/repositories/skill_test_repository.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_test/certification.dart';
import 'package:poolcoachai/domain/skill_test/certification_summary.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';
import 'package:uuid/uuid.dart';

/// Lần kiểm tra kỹ năng của người đang đăng nhập; null khi chưa đăng nhập.
final skillTestRepositoryProvider = Provider<SkillTestRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return SkillTestRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
    newId: const Uuid().v4,
  );
});

final skillTestsProvider = StreamProvider<List<SkillTest>>((ref) {
  final repo = ref.watch(skillTestRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchTests();
});

/// Mọi thứ màn kiểm tra và thẻ chi tiết bài cần về một bài, đã qua cổng:
/// giao diện không đọc provider nguồn chưa qua cổng.
final class SkillTestDrillState {
  const SkillTestDrillState({
    required this.drill,
    required this.gate,
    required this.formSlipped,
    required this.drills,
    required this.logs,
  });

  final Drill drill;
  final SkillTestGate gate;

  /// "Phong độ gần đây chưa đạt": chỉ có thể đúng khi bài đã chứng nhận.
  final bool formSlipped;

  /// Cả thư viện, để gọi tên bài còn thiếu ("Cần chứng nhận {bài} trước") và
  /// cho `completeTest`.
  final List<Drill> drills;

  /// Buổi tập của đúng bài này.
  final List<DrillLog> logs;

  /// Tên các bài cấp thấp hơn còn thiếu chứng nhận; rỗng khi cổng không phải
  /// [NeedLowerLevel]. Bài không còn trong thư viện bị bỏ.
  List<Drill> get missingLowerDrills {
    final g = gate;
    if (g is! NeedLowerLevel) return const [];
    final byId = {for (final d in drills) d.id: d};
    return [for (final id in g.drillIds) ?byId[id]];
  }
}

final certificationsProvider =
    Provider<AsyncValue<Map<String, Certification>>>((ref) {
  final tests = ref.watch(skillTestsProvider);
  final blocked = gate<Map<String, Certification>>([tests]);
  if (blocked != null) return blocked;
  return AsyncData(certificationsOf(tests.value!));
});

/// Null khi mã bài không có trong thư viện.
final skillTestGateProvider =
    Provider.family<AsyncValue<SkillTestDrillState?>, String>((ref, drillId) {
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final tests = ref.watch(skillTestsProvider);
  final blocked = gate<SkillTestDrillState?>([drills, logs, tests]);
  if (blocked != null) return blocked;

  final drill = drills.value!.where((d) => d.id == drillId).firstOrNull;
  if (drill == null) return const AsyncData(null);
  final own = [
    for (final l in logs.value!)
      if (l.drillId == drillId) l,
  ];
  final result = skillTestGate(
    drill: drill,
    drills: drills.value!,
    logs: logs.value!,
    tests: tests.value!,
  );
  return AsyncData(
    SkillTestDrillState(
      drill: drill,
      gate: result,
      formSlipped: result is AlreadyCertified && recentFormSlipped(drill, own),
      drills: drills.value!,
      logs: own,
    ),
  );
});

final certificationSummaryProvider =
    Provider<AsyncValue<CertificationSummary>>((ref) {
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final tests = ref.watch(skillTestsProvider);
  final blocked = gate<CertificationSummary>([drills, logs, tests]);
  if (blocked != null) return blocked;
  return AsyncData(
    certificationSummary(
      drills: drills.value!,
      logs: logs.value!,
      tests: tests.value!,
    ),
  );
});

final testableDrillIdsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final tests = ref.watch(skillTestsProvider);
  final blocked = gate<List<String>>([drills, logs, tests]);
  if (blocked != null) return blocked;
  return AsyncData(
    testableDrillIds(
      drills: drills.value!,
      logs: logs.value!,
      tests: tests.value!,
    ),
  );
});
