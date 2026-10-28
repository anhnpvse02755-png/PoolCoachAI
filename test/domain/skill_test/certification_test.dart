import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/certification.dart';
import 'package:poolcoachai/domain/skill_test/certification_summary.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

import '../../support/skill_test_fixtures.dart';

void main() {
  test(
    'certificationsOf: mỗi bài một chứng nhận, lấy lần đạt sớm nhất; trượt, huỷ, hỏng không tính',
    () {
      final early = stToday.subtract(const Duration(days: 9));
      final certs = certificationsOf([
        passedTest('a1', 1, stToday),
        passedTest('a1', 1, early),
        failedTest('p2a', 2, stToday),
        cancelledTest('p2b', 2, stToday),
        SkillTest(
          id: 'broken',
          drillId: 'p3',
          drillLevel: 3,
          tableSize: TableSize.eightFoot,
          startedAt: stToday,
          completedAt: stToday,
        ),
      ]);
      expect(certs.keys, ['a1']);
      expect(
        [
          certs['a1']!.certifiedAt,
          certs['a1']!.drillLevel,
          certs['a1']!.testId,
        ],
        [early, 1, 'pass-a1-${early.toIso8601String()}'],
      );
    },
  );
  test(
    'certificationsOf: cùng thời điểm thì id nhỏ hơn thắng; thứ tự theo thời điểm chứng nhận',
    () {
      final certs = certificationsOf([
        passedTest('p2a', 2, stToday, id: 'z'),
        passedTest('p2a', 2, stToday, id: 'b'),
        passedTest('a1', 1, stToday.subtract(const Duration(days: 1))),
      ]);
      expect(certs.keys, ['a1', 'p2a']);
      expect(certs['p2a']!.testId, 'b');
    },
  );
  test(
    'nextLevelDrills: cấp nhỏ nhất lớn hơn, bỏ qua khoảng trống; bài cao nhất nhóm không có cấp tiếp',
    () {
      expect(nextLevelDrills(stById('a1'), stDrills).map((d) => d.id), ['a3']);
      expect(nextLevelDrills(stById('p2b'), stDrills).map((d) => d.id), ['p3']);
      expect(nextLevelDrills(stById('a3'), stDrills), isEmpty);
      expect(nextLevelDrills(stById('t2'), stDrills), isEmpty);
    },
  );
  group('recentFormSlipped', () {
    List<DrillLog> after(List<int> made) => [
      for (final (i, m) in made.indexed)
        stLog('a1', m, stToday.add(Duration(hours: i + 1))),
    ];
    test(
      '5 buổi gần nhất đều trượt',
      () => expect(
        recentFormSlipped(stById('a1'), [
          ...threePasses('a1'),
          ...after([5, 5, 5, 5, 5]),
        ]),
        isTrue,
      ),
    );
    test(
      '4 buổi trượt, cửa sổ 5 còn một buổi đạt',
      () => expect(
        recentFormSlipped(stById('a1'), [
          ...threePasses('a1'),
          ...after([5, 5, 5, 5]),
        ]),
        isFalse,
      ),
    );
    test(
      'buổi mới nhất đạt',
      () => expect(
        recentFormSlipped(stById('a1'), [
          ...threePasses('a1'),
          ...after([5, 5, 5, 5, 5, 9]),
        ]),
        isFalse,
      ),
    );
    test(
      'chưa đủ 5 buổi thì không kết luận',
      () => expect(recentFormSlipped(stById('a1'), after([5, 5])), isFalse),
    );
    test('buổi không chấm được (thiếu số lần thử) không tính là đạt', () {
      final logs = [
        for (var i = 0; i < 5; i++)
          stLog('a1', 9, stToday.add(Duration(hours: i + 1)), attempts: null),
      ];
      expect(recentFormSlipped(stById('a1'), logs), isTrue);
    });
    test('thứ tự đầu vào không quan trọng', () {
      final logs = [
        ...threePasses('a1'),
        ...after([5, 5, 5, 5, 5]),
      ].reversed.toList();
      expect(recentFormSlipped(stById('a1'), logs), isTrue);
    });
  });
  group('certificationSummary', () {
    test('nhóm theo thứ tự SkillCategory; nhóm đủ bài là thuần thục', () {
      final s = certificationSummary(
        drills: stDrills,
        logs: const [],
        tests: [
          passedTest('p3', 3, stToday),
          passedTest('p2b', 2, stToday),
          passedTest('p2a', 2, stToday),
          passedTest('a1', 1, stToday),
        ],
      );
      expect(s.groups.map((g) => g.cat), [
        SkillCategory.aiming,
        SkillCategory.position,
      ]);
      expect(s.groups[0].complete, isFalse);
      expect(s.groups[1].entries.map((e) => e.drill.id), ['p2a', 'p2b', 'p3']);
      expect(s.groups[1].complete, isTrue);
    });
    test(
      'chưa có chứng nhận: gợi ý bài nhiều buổi đạt liên tiếp nhất mà cổng cấp đã qua',
      () {
        final logs = [
          ...threePasses('a1').skip(1),
          ...threePasses('a3'),
          stLog('p2a', 9, stToday),
        ];
        final s = certificationSummary(
          drills: stDrills,
          logs: logs,
          tests: const [],
        );
        expect(s.groups, isEmpty);
        expect([s.closest!.drill.id, s.closest!.passCount], ['a1', 2]);
      },
    );
    test('hoà số buổi: bài cấp thấp hơn trước', () {
      final s = certificationSummary(
        drills: stDrills,
        tests: const [],
        logs: [
          stLog('p2b', 9, stToday),
          stLog('a1', 9, stToday),
          stLog('p2a', 9, stToday),
        ],
      );
      expect(s.closest!.drill.id, 'a1');
    });
    test('hoà số buổi và cấp: id nhỏ hơn trước', () {
      final s = certificationSummary(
        drills: stDrills,
        tests: const [],
        logs: [stLog('p2b', 9, stToday), stLog('p2a', 9, stToday)],
      );
      expect(s.closest!.drill.id, 'p2a');
    });
    test('bài đã chứng nhận không được gợi ý', () {
      final s = certificationSummary(
        drills: stDrills,
        tests: [passedTest('a1', 1, stToday)],
        logs: [...threePasses('a1'), stLog('p2a', 9, stToday)],
      );
      expect(s.closest!.drill.id, 'p2a');
    });
    test('không bài nào có buổi đạt: không gợi ý', () {
      expect(
        certificationSummary(
          drills: stDrills,
          logs: [stLog('a1', 2, stToday)],
          tests: const [],
        ).closest,
        isNull,
      );
    });
    test('chứng nhận của bài không còn trong thư viện thì bỏ qua, không ném', () {
      expect(
        certificationSummary(
          drills: stDrills,
          logs: const [],
          // passedTest dựa vào thư viện giả nên dựng tay lần đạt của bài đã bị gỡ.
          tests: [
            SkillTest(
              id: 'zz-pass',
              drillId: 'zz',
              drillLevel: 2,
              tableSize: TableSize.nineFootPlus,
              startedAt: stToday.subtract(const Duration(minutes: 20)),
              completedAt: stToday,
              score: 9,
              attempts: 10,
              passed: true,
              passThreshold: 0.8,
            ),
          ],
        ).groups,
        isEmpty,
      );
    });
  });
}
