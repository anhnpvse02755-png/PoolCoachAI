import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/skill_category.dart';

const _d1 = Drill(
  id: 'd1',
  cat: SkillCategory.aiming,
  name: 'Đường thẳng cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.8,
);

const _d7 = Drill(
  id: 'd7',
  cat: SkillCategory.safety,
  name: 'Đẩy sát băng',
  level: 2,
  unit: 'lần thành công / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.7,
);

DrillLog _log(String drillId, int day, num score, int attempts) => DrillLog(
      id: '$drillId-$day',
      drillId: drillId,
      date: DateTime(2026, 9, day),
      score: score,
      attempts: attempts,
    );

void main() {
  group('computePlayerIntelligence — case bắt buộc của spec', () {
    test('d1 với 8,9,9,10 trên 10 cho điểm cao, xu hướng lên, là điểm mạnh',
        () {
      final pi = computePlayerIntelligence(
        drills: const [_d1],
        logs: [
          _log('d1', 1, 8, 10),
          _log('d1', 2, 9, 10),
          _log('d1', 3, 9, 10),
          _log('d1', 4, 10, 10),
        ],
      );

      final insight = pi.categories[SkillCategory.aiming]!;
      expect(insight.mastery, isNotNull);
      expect(insight.mastery!, greaterThanOrEqualTo(75));
      expect(insight.trend, SkillTrend.up);
      expect(pi.strong, contains(SkillCategory.aiming));
      expect(pi.weak, isNot(contains(SkillCategory.aiming)));
    });

    test('d7 với 3,4,4 trên 10 cho điểm quanh 53, là điểm yếu', () {
      final pi = computePlayerIntelligence(
        drills: const [_d7],
        logs: [
          _log('d7', 1, 3, 10),
          _log('d7', 2, 4, 10),
          _log('d7', 3, 4, 10),
        ],
      );

      final insight = pi.categories[SkillCategory.safety]!;
      expect(insight.mastery, inInclusiveRange(48, 58));
      expect(pi.weak, contains(SkillCategory.safety));
    });

    test('d1 đạt 3 buổi cuối liên tiếp nên nằm trong readyDrillIds', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1],
        logs: [
          _log('d1', 1, 5, 10),
          _log('d1', 2, 8, 10),
          _log('d1', 3, 9, 10),
          _log('d1', 4, 10, 10),
        ],
      );

      expect(pi.readyDrillIds, contains('d1'));
    });

    test('nhóm chưa đủ dữ liệu thì mastery null và trend notEnoughData', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1],
        logs: [_log('d1', 1, 8, 10)],
      );

      final insight = pi.categories[SkillCategory.aiming]!;
      expect(insight.mastery, isNull);
      expect(insight.trend, SkillTrend.notEnoughData);
      expect(insight.sessionCount, 1);
      expect(pi.weak, isEmpty);
      expect(pi.strong, isEmpty);
    });

    test('không có log nào thì hasAnyData là false', () {
      final pi = computePlayerIntelligence(drills: const [_d1], logs: const []);
      expect(pi.hasAnyData, isFalse);
    });

    test('mọi nhóm kỹ năng đều có mặt trong kết quả, kể cả khi chưa tập', () {
      final pi = computePlayerIntelligence(drills: const [_d1], logs: const []);
      expect(pi.categories.keys.toSet(), SkillCategory.values.toSet());
    });

    test('weak sắp xếp tăng dần theo mastery', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1, _d7],
        logs: [
          _log('d1', 1, 4, 10),
          _log('d1', 2, 4, 10),
          _log('d1', 3, 4, 10),
          _log('d7', 1, 2, 10),
          _log('d7', 2, 2, 10),
          _log('d7', 3, 2, 10),
        ],
      );

      expect(pi.weak.length, 2);
      final first = pi.categories[pi.weak.first]!.mastery!;
      final second = pi.categories[pi.weak.last]!.mastery!;
      expect(first, lessThanOrEqualTo(second));
    });
  });

  group('isReadyForLevelUp', () {
    test('chưa đủ số buổi liên tiếp thì chưa sẵn sàng', () {
      expect(
        isReadyForLevelUp(_d1, [_log('d1', 1, 10, 10), _log('d1', 2, 10, 10)]),
        isFalse,
      );
    });

    test('ba buổi cuối đều đạt thì sẵn sàng', () {
      expect(
        isReadyForLevelUp(_d1, [
          _log('d1', 1, 2, 10),
          _log('d1', 2, 8, 10),
          _log('d1', 3, 9, 10),
          _log('d1', 4, 10, 10),
        ]),
        isTrue,
      );
    });

    test('một buổi trong ba buổi cuối chưa đạt thì chưa sẵn sàng', () {
      expect(
        isReadyForLevelUp(_d1, [
          _log('d1', 1, 10, 10),
          _log('d1', 2, 5, 10),
          _log('d1', 3, 10, 10),
        ]),
        isFalse,
      );
    });
  });
}
