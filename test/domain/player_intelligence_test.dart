import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../support/match_fixtures.dart';
import '../support/roadmap_fixtures.dart';

void main() {
  group('categoryMastery', () {
    test('trả null khi chưa đủ số buổi tối thiểu', () {
      expect(categoryMastery([1.0, 1.0]), isNull);
    });

    test('toàn buổi đạt đúng mục tiêu cho 100', () {
      expect(categoryMastery([1.0, 1.0, 1.0]), 100);
    });

    test('bị chặn trên ở 100 dù có buổi vượt mục tiêu', () {
      expect(categoryMastery([1.2, 1.2, 1.2]), 100);
    });

    test('buổi mới có trọng số cao hơn buổi cũ', () {
      // Cùng bộ số, đảo thứ tự: bản có buổi tốt ở cuối phải cao hơn.
      final improving = categoryMastery([0.4, 0.6, 1.0])!;
      final declining = categoryMastery([1.0, 0.6, 0.4])!;
      expect(improving, greaterThan(declining));
    });

    test('một buổi ăn may bị chặn ở trần 1.2', () {
      final capped = categoryMastery([0.5, 0.5, 5.0])!;
      final atCap = categoryMastery([0.5, 0.5, 1.2])!;
      expect(capped, atCap);
    });
  });

  group('categoryTrend', () {
    test('cần ít nhất 4 buổi mới dám kết luận xu hướng', () {
      expect(categoryTrend([0.2, 0.5, 0.9]), SkillTrend.notEnoughData);
    });

    test('nửa sau tốt hơn hẳn nửa trước là đi lên', () {
      expect(categoryTrend([0.3, 0.3, 0.9, 0.9]), SkillTrend.up);
    });

    test('nửa sau kém hơn hẳn nửa trước là đi xuống', () {
      expect(categoryTrend([0.9, 0.9, 0.3, 0.3]), SkillTrend.down);
    });

    test('chênh lệch nhỏ hơn ngưỡng là đi ngang', () {
      expect(categoryTrend([0.5, 0.5, 0.55, 0.55]), SkillTrend.flat);
    });

    // Ví dụ chuẩn của spec (8,9,9,10) cho chênh lệch đúng bằng ngưỡng.
    // Nó chỉ đọc ra "đi lên" nhờ nhiễu làm tròn, nên hai test dưới khoá
    // hành vi tại mép bằng cặp số cho chênh lệch đúng 0.1 tuyệt đối.
    test('chênh lệch đúng bằng ngưỡng vẫn tính là đi lên', () {
      expect(categoryTrend([0.0, 0.0, 0.1, 0.1]), SkillTrend.up);
    });

    test('chênh lệch âm đúng bằng ngưỡng vẫn tính là đi xuống', () {
      expect(categoryTrend([0.1, 0.1, 0.0, 0.0]), SkillTrend.down);
    });
  });

  group('trận và BU trong Player Intelligence', () {
    final bu = buResultGraded(
      completedAt: DateTime(2026, 10, 10),
      lost: const {'F7': 20, 'F6': 10},
    );

    test('matchWeak đến từ phân tích trận và không đổi mastery', () {
      final pi = computePlayerIntelligence(
        drills: roadmapDrills,
        logs: const [],
        matches: matchesWeakAt(SkillCategory.position, at: DateTime(2026, 10, 20)),
      );
      expect(pi.matchWeak.first.category, SkillCategory.position);
      expect(pi.categories[SkillCategory.position]!.mastery, isNull);
      expect(pi.weak, isEmpty);
    });

    test('nhóm chưa có mastery mà BU < 55 thì vào weak, nguồn bu', () {
      final pi = computePlayerIntelligence(
          drills: roadmapDrills, logs: const [], latestBu: bu);
      expect(pi.buPercent[SkillCategory.aiming], 48);
      expect(pi.weak, [SkillCategory.aiming]);
      expect(pi.weakSources[SkillCategory.aiming], WeakSource.bu);
    });

    test('nhóm đã có mastery giữ mastery làm nguồn; BU không kéo nó vào weak', () {
      final logs = sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]);
      final pi = computePlayerIntelligence(
          drills: roadmapDrills, logs: logs, latestBu: bu);
      expect(pi.categories[SkillCategory.aiming]!.mastery, isNotNull);
      expect(pi.buPercent[SkillCategory.aiming], 48);
      expect(pi.weak, isNot(contains(SkillCategory.aiming)));
      expect(pi.weakSources.containsKey(SkillCategory.aiming), isFalse);
    });

    test('nhóm yếu theo bài tập đứng trước nhóm yếu theo BU; nguồn từng nhóm', () {
      final logs = sessions('p1', 3, [on(10, 1), on(10, 2), on(10, 3)]);
      final pi = computePlayerIntelligence(
          drills: roadmapDrills, logs: logs, latestBu: bu);
      expect(pi.categories[SkillCategory.position]!.mastery!,
          lessThan(PracticeConstants.weakCutoff));
      expect(pi.weak, [SkillCategory.position, SkillCategory.aiming]);
      expect(pi.weakSources[SkillCategory.position], WeakSource.drills);
      expect(pi.weakSources[SkillCategory.aiming], WeakSource.bu);
    });

    test('các nhóm yếu theo BU bằng điểm nhau xếp theo thứ tự nhóm', () {
      final base = buResultGraded(completedAt: DateTime(2026, 10, 10));
      final allLost = BuResult(
        testId: base.testId,
        completedAt: base.completedAt,
        total: base.total,
        lost: base.max,
        max: base.max,
      );
      final pi = computePlayerIntelligence(
          drills: roadmapDrills, logs: const [], latestBu: allLost);
      expect(pi.buPercent.values.toSet(), {0});
      expect(pi.weak, SkillCategory.values.where((c) => !c.isAdvanced));
    });

    test('nhóm nâng cao chưa có buổi: không trong phạm vi, không yếu', () {
      final pi = computePlayerIntelligence(drills: roadmapDrills, logs: const []);
      expect(pi.inScope(SkillCategory.dungCo), isFalse);
      expect(pi.inScope(SkillCategory.aiming), isTrue);
      expect(pi.weak, isEmpty);
    });

    test('BU yếu S8, chưa có buổi Dựng cơ: không yếu; có một buổi: yếu theo BU', () {
      final s8Lost = buResultGraded(
        completedAt: DateTime(2026, 10, 10),
        lost: const {'S8': 5},
      );
      final drills = [...roadmapDrills, ...advancedDrills];
      final none = computePlayerIntelligence(drills: drills, logs: const [], latestBu: s8Lost);
      expect(none.buPercent[SkillCategory.dungCo], 0);
      expect(none.weak, isNot(contains(SkillCategory.dungCo)));
      expect(none.weakSources.containsKey(SkillCategory.dungCo), isFalse);

      final one = computePlayerIntelligence(
          drills: drills, logs: sessions('c1', 5, [on(10, 1)]), latestBu: s8Lost);
      expect(one.categories[SkillCategory.dungCo]!.mastery, isNull);
      expect(one.weak, contains(SkillCategory.dungCo));
      expect(one.weakSources[SkillCategory.dungCo], WeakSource.bu);
    });

    test('S8 không mất điểm: Dựng cơ có buổi vẫn không yếu theo BU', () {
      final full = buResultGraded(completedAt: DateTime(2026, 10, 10));
      final pi = computePlayerIntelligence(
          drills: [...roadmapDrills, ...advancedDrills],
          logs: sessions('c1', 5, [on(10, 1)]),
          latestBu: full);
      expect(pi.buPercent[SkillCategory.dungCo], 100);
      expect(pi.weak, isNot(contains(SkillCategory.dungCo)));
    });

    test('ba buổi Nhảy bi kém: Nhảy bi vào danh sách yếu như mọi nhóm', () {
      final pi = computePlayerIntelligence(
        drills: [...roadmapDrills, ...advancedDrills],
        logs: sessions('j1', 0, [on(10, 1), on(10, 2), on(10, 3)]),
      );
      expect(pi.inScope(SkillCategory.nhayBi), isTrue);
      expect(pi.weak, contains(SkillCategory.nhayBi));
      expect(pi.weakSources[SkillCategory.nhayBi], WeakSource.drills);
    });

    test('không truyền trận, không truyền BU: kết quả như cũ', () {
      final pi = computePlayerIntelligence(drills: roadmapDrills, logs: const []);
      expect(pi.matchWeak, isEmpty);
      expect(pi.buPercent, isEmpty);
      expect(pi.weakSources, isEmpty);
      expect(pi.weak, isEmpty);
    });
  });
}
