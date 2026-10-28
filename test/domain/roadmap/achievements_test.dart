import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

import '../../support/roadmap_fixtures.dart';
import '../../support/skill_test_fixtures.dart';

void main() {
  List<Achievement> run({PlayerGoal? goal, List<DrillLog> logs = const [], Set<String> existing = const {}}) =>
      newAchievements(goal: goal, drills: roadmapDrills, logs: logs, existing: existing, today: roadmapToday);

  group('chứng nhận (Skill Test)', () {
    List<Achievement> certs(List<SkillTest> tests, {Set<String> existing = const {}}) => newAchievements(
            goal: null, drills: stDrills, logs: const [], existing: existing, today: stToday, skillTests: tests)
        .where((a) => a.kind == AchievementKind.chungNhan)
        .toList();
    final at = stToday.subtract(const Duration(days: 1));

    test('lần đạt ra đúng một chứng nhận, ngày là ngày hoàn tất; trượt và huỷ không', () {
      expect(certs([passedTest('a1', 1, at), failedTest('p2a', 2, at), cancelledTest('p2b', 2, at)]),
          [Achievement(kind: AchievementKind.chungNhan, refId: 'a1', achievedAt: at)]);
    });
    test('đã có thì không ghi lại', () => expect(certs([passedTest('a1', 1, stToday)], existing: {'chungNhan|a1'}), isEmpty));
    test('đạt nhiều lần: ngày là lần đạt sớm nhất', () {
      final early = stToday.subtract(const Duration(days: 3));
      expect(certs([passedTest('a1', 1, stToday), passedTest('a1', 1, early)]),
          [Achievement(kind: AchievementKind.chungNhan, refId: 'a1', achievedAt: early)]);
    });
    test('lần đạt sau lần trượt vẫn ra chứng nhận, ngày là lần đạt', () {
      expect(certs([failedTest('a1', 1, at), passedTest('a1', 1, stToday)]),
          [Achievement(kind: AchievementKind.chungNhan, refId: 'a1', achievedAt: stToday)]);
    });
    test('dòng lệch (passed=true mà điểm không đạt) không ra chứng nhận', () {
      final ok = passedTest('a1', 1, at);
      final mismatch = SkillTest(
        id: ok.id, drillId: 'a1', drillLevel: 1, tableSize: ok.tableSize, startedAt: ok.startedAt,
        completedAt: at, score: 2, attempts: 10, passed: true, passThreshold: 0.8,
      );
      expect(certs([mismatch]), isEmpty);
    });
    test('không có lần kiểm tra thì không có chứng nhận', () => expect(certs(const []), isEmpty));
  });

  test('mốc chuỗi ngày đúng 7 / 14 / 30 / 60 / 100 (chủ sản phẩm chọn 15/10)', () {
    expect(streakMilestones, [7, 14, 30, 60, 100]);
  });

  group('đủ điều kiện lên cấp', () {
    test('đủ điều kiện lên cấp ghi đúng ngày buổi đạt thứ ba', () {
      final a = run(logs: sessions('a1', 9, [on(10, 1), on(10, 3), on(10, 5)]));
      final ready = a.where((x) => x.kind == AchievementKind.duDieuKienLenCap).single;
      expect(ready.refId, 'a1');
      expect(ready.achievedAt, on(10, 5));
    });

    test('đã ghi rồi thì không ghi lại', () {
      final a = run(
        logs: sessions('a1', 9, [on(10, 1), on(10, 3), on(10, 5)]),
        existing: {'duDieuKienLenCap|a1'},
      );
      expect(a.where((x) => x.kind == AchievementKind.duDieuKienLenCap), isEmpty);
    });

    test('chưa đủ ba buổi đạt thì không có', () {
      expect(run(logs: sessions('a1', 9, [on(10, 1), on(10, 3)])), isEmpty);
    });
  });

  group('chuỗi ngày tập', () {
    test('chuỗi 15 ngày tới hôm nay ghi mốc 7 và 14, ngày hôm nay', () {
      final days = [for (var d = 1; d <= 15; d++) on(10, d)];
      final streak = run(logs: sessions('p1', 2, days)).where((x) => x.kind == AchievementKind.chuoiNgay).toList();
      expect(streak.map((x) => x.refId), ['7', '14']);
      expect(streak.first.achievedAt, DateTime(2026, 10, 15));
    });

    test('mốc đã có thì không ghi lại kể cả khi chuỗi đứt rồi chạm lại', () {
      final days = [for (var d = 1; d <= 8; d++) on(10, d + 7)];
      final streak = run(logs: sessions('p1', 2, days), existing: {'chuoiNgay|7'})
          .where((x) => x.kind == AchievementKind.chuoiNgay);
      expect(streak, isEmpty);
    });
  });

  group('xong bước (R7)', () {
    final lenHang = PlayerGoal(goalId: 'g1', kind: GoalKind.lenHang, createdAt: on(10, 4));

    test('nhóm xong bằng buổi tập từ khi đặt mục tiêu: ghi một lần, gắn mục tiêu', () {
      final logs = [
        ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
        ...sessions('a2', 9, [on(10, 6), on(10, 7), on(10, 8)]),
      ];
      final done = run(goal: lenHang, logs: logs).where((x) => x.kind == AchievementKind.xongBuoc).single;
      expect(done.refId, 'g1:${SkillCategory.aiming.name}');
      expect(done.achievedAt, on(10, 8));
      expect(
        run(goal: lenHang, logs: logs, existing: {done.key}).where((x) => x.kind == AchievementKind.xongBuoc),
        isEmpty,
      );
    });

    test('nhóm đã xong từ trước khi đặt mục tiêu: không phải sự kiện mới, không ghi', () {
      final logs = [
        ...sessions('a1', 9, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a2', 9, [on(9, 6), on(9, 7), on(9, 8)]),
      ];
      expect(run(goal: lenHang, logs: logs).where((x) => x.kind == AchievementKind.xongBuoc), isEmpty);
    });

    test('thuần thục: mỗi bài một lần, nhóm một lần', () {
      final goal = PlayerGoal(
          goalId: 'g2', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: on(10, 1));
      final logs = [
        ...sessions('a1', 9, [on(10, 2), on(10, 3), on(10, 4)]),
        ...sessions('a2', 9, [on(10, 6), on(10, 7), on(10, 8)]),
      ];
      final refs = run(goal: goal, logs: logs)
          .where((x) => x.kind == AchievementKind.xongBuoc)
          .map((x) => x.refId)
          .toList();
      expect(refs, ['g2:a1', 'g2:a2', 'g2:aiming']);
    });

    test('không có mục tiêu: không có thành tích xong bước', () {
      final logs = sessions('a1', 9, [on(10, 6), on(10, 7), on(10, 8)]);
      expect(run(logs: logs).where((x) => x.kind == AchievementKind.xongBuoc), isEmpty);
    });
  });
}
