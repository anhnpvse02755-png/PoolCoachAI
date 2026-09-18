import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('Drill', () {
    test('bài chấm theo tỉ lệ thì usesAttempts là true', () {
      const drill = Drill(
        id: 'd1',
        cat: SkillCategory.aiming,
        name: 'Đường thẳng cơ bản',
        level: 1,
        unit: 'lần trúng / 10',
        goal: 'Đánh thẳng bi cái vào bi mục tiêu.',
        steps: ['Đặt bi.'],
        passThreshold: 0.8,
      );

      expect(drill.usesAttempts, isTrue);
    });

    test('bài chấm theo mục tiêu tuyệt đối thì usesAttempts là false', () {
      const drill = Drill(
        id: 'd4',
        cat: SkillCategory.position,
        name: 'Đánh trô bi',
        level: 3,
        unit: 'khoảng cách kéo (cm)',
        goal: 'Kéo bi cái lùi lại.',
        steps: ['Đánh 1/3 dưới bi cái.'],
        target: 25,
      );

      expect(drill.usesAttempts, isFalse);
    });

    test('không được đặt đồng thời passThreshold và target', () {
      expect(
        () => Drill(
          id: 'x',
          cat: SkillCategory.aiming,
          name: 'Sai',
          level: 1,
          unit: 'u',
          goal: 'g',
          steps: const [],
          passThreshold: 0.8,
          target: 10,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('phải đặt một trong hai', () {
      expect(
        () => Drill(
          id: 'x',
          cat: SkillCategory.aiming,
          name: 'Sai',
          level: 1,
          unit: 'u',
          goal: 'g',
          steps: const [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('DrillLog', () {
    test('bài đếm cú ghi kèm số lượt thử', () {
      final log = DrillLog(
        id: 'l1',
        drillId: 'd1',
        date: DateTime(2026, 9, 18),
        score: 7,
        attempts: 10,
      );

      expect(log.drillId, 'd1');
      expect(log.score, 7);
      expect(log.attempts, 10);
      expect(log.notes, isNull);
    });

    test('bài đo bằng đơn vị khác thì không có số lượt thử', () {
      final log = DrillLog(
        id: 'l2',
        drillId: 'd4',
        date: DateTime(2026, 9, 18),
        score: 28,
        notes: 'bàn trơn hơn mọi khi',
      );

      expect(log.attempts, isNull);
      expect(log.notes, 'bàn trơn hơn mọi khi');
    });
  });
}
