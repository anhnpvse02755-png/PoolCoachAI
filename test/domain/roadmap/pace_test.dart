import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  const aiming = SkillCategory.aiming;

  test('cửa sổ là 28 ngày (chủ sản phẩm duyệt 15/10)', () {
    expect(PracticeConstants.paceWindowDays, 28);
  });

  group('tốc độ tiến bộ của một nhóm', () {
    test('đủ buổi trước cửa sổ: mốc là đầu cửa sổ (17/9)', () {
      final logs = [
        ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a1', 8, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final now = categoryMastery([0.5, 0.5, 0.5, 1, 1, 1])!;
      final pace = categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday);
      expect(pace, closeTo((now - 50) / 28, 1e-9));
    });

    test('chưa đủ buổi trước cửa sổ: mốc là ngày đầu tiên đo được', () {
      final logs = [
        ...sessions('a1', 4, [on(10, 1), on(10, 2), on(10, 3)]),
        ...sessions('a1', 8, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final now = categoryMastery([0.5, 0.5, 0.5, 1, 1, 1])!;
      final pace = categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday);
      expect(pace, closeTo((now - 50) / 12, 1e-9));
    });

    test('dưới 3 buổi thì không có tốc độ', () {
      final logs = sessions('a1', 8, [on(10, 10), on(10, 11)]);
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), isNull);
    });

    test('vừa đo được hôm nay thì chưa có tốc độ (0 ngày)', () {
      final logs = sessions('a1', 8, [on(10, 13), on(10, 14), on(10, 15)]);
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), isNull);
    });

    test('không tập trong 28 ngày: tốc độ 0, không đoán ngày', () {
      final logs = sessions('a1', 4, [on(8, 1), on(8, 2), on(8, 3)]);
      final pace = categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday);
      expect(pace, 0);
      expect(daysToStrong(50, pace), isNull);
    });

    test('đang đi xuống thì tốc độ âm', () {
      final logs = [
        ...sessions('a1', 8, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a1', 4, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), lessThan(0));
    });

    test('chỉ tính bài của đúng nhóm', () {
      final logs = sessions('s1', 8, [on(10, 1), on(10, 2), on(10, 3)]);
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), isNull);
    });
  });

  group('số ngày tới 75', () {
    test('làm tròn lên; đã đạt 75 là 0 ngày', () {
      expect(daysToStrong(60, 1.5), 10);
      expect(daysToStrong(74, 0.3), 4);
      expect(daysToStrong(75, null), 0);
      expect(daysToStrong(90, -1), 0);
    });

    test('chưa đo hoặc tốc độ không dương thì không có số ngày', () {
      expect(daysToStrong(null, 2), isNull);
      expect(daysToStrong(60, 0), isNull);
      expect(daysToStrong(60, -0.5), isNull);
      expect(daysToStrong(60, null), isNull);
    });
  });
}
