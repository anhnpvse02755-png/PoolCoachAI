import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';

const _ratioDrill = Drill(
  id: 'd1',
  cat: SkillCategory.aiming,
  name: 'Đường thẳng cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.8,
);

const _targetDrill = Drill(
  id: 'd4',
  cat: SkillCategory.position,
  name: 'Đánh trô bi',
  level: 3,
  unit: 'cm',
  goal: 'g',
  steps: ['s'],
  target: 25,
);

DrillLog _log({required num score, int? attempts}) => DrillLog(
      id: 'l',
      drillId: 'd',
      date: DateTime(2026, 9, 17),
      score: score,
      attempts: attempts,
    );

void main() {
  group('PracticeConstants', () {
    test('giữ đúng giá trị của spec, không ai được tự chỉnh', () {
      expect(PracticeConstants.minSessions, 3);
      expect(PracticeConstants.recencyDecay, 0.85);
      expect(PracticeConstants.weakCutoff, 55);
      expect(PracticeConstants.strongCutoff, 75);
      expect(PracticeConstants.readyStreak, 3);
      expect(PracticeConstants.ratioCap, 1.2);
      expect(PracticeConstants.trendThreshold, 0.1);
    });

    test('ngưỡng yếu thấp hơn ngưỡng mạnh', () {
      expect(
        PracticeConstants.weakCutoff,
        lessThan(PracticeConstants.strongCutoff),
      );
    });
  });

  group('drillRatio', () {
    test('đạt đúng ngưỡng cho ratio 1.0', () {
      // 8/10 = 0.8, ngưỡng 0.8 -> vừa đủ đạt
      expect(drillRatio(_ratioDrill, _log(score: 8, attempts: 10)), 1.0);
    });

    test('vượt ngưỡng cho ratio lớn hơn 1', () {
      // 10/10 = 1.0 chia 0.8 = 1.25
      expect(drillRatio(_ratioDrill, _log(score: 10, attempts: 10)), 1.25);
    });

    test('dưới ngưỡng cho ratio nhỏ hơn 1', () {
      // 4/10 = 0.4 chia 0.8 = 0.5
      expect(drillRatio(_ratioDrill, _log(score: 4, attempts: 10)), 0.5);
    });

    test('bài đo theo mục tiêu tuyệt đối chia cho target', () {
      expect(drillRatio(_targetDrill, _log(score: 25)), 1.0);
      expect(drillRatio(_targetDrill, _log(score: 50)), 2.0);
    });

    test('trả null khi bài cần attempts mà log không có', () {
      expect(drillRatio(_ratioDrill, _log(score: 8)), isNull);
    });

    test('trả null khi attempts bằng 0 — không chia cho 0', () {
      expect(drillRatio(_ratioDrill, _log(score: 0, attempts: 0)), isNull);
    });
  });
}
