import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

import '../../support/skill_test_fixtures.dart';

void main() {
  SkillTestGate g(
    String id, {
    List<DrillLog> logs = const [],
    List<SkillTest> tests = const [],
  }) => skillTestGate(
    drill: stById(id),
    drills: stDrills,
    logs: logs,
    tests: tests,
  );
  Matcher needStreak(int n) =>
      isA<NeedStreak>().having((x) => x.missing, 'missing', n);
  Matcher needLower(List<String> ids) =>
      isA<NeedLowerLevel>().having((x) => x.drillIds, 'drillIds', ids);

  test(
    'bài thấp nhất nhóm, chưa có buổi: cần thêm 3 buổi đạt liên tiếp',
    () => expect(g('a1'), needStreak(3)),
  );
  test(
    'hai buổi đạt: còn thiếu 1',
    () => expect(
      g('a1', logs: threePasses('a1').skip(1).toList()),
      needStreak(1),
    ),
  );
  test(
    'đủ 3 buổi đạt ở bài thấp nhất nhóm: mở',
    () => expect(g('a1', logs: threePasses('a1')), isA<SkillTestOpen>()),
  );
  test('cấp không liên tục: a3 cần chứng nhận a1 trước, dù đủ chuỗi', () {
    expect(g('a3', logs: threePasses('a3')), needLower(['a1']));
    expect(
      g(
        'a3',
        logs: threePasses('a3'),
        tests: [passedTest('a1', 1, stToday.subtract(const Duration(days: 5)))],
      ),
      isA<SkillTestOpen>(),
    );
  });
  test(
    'cổng cấp đứng trước chuỗi buổi: a3 chưa tập vẫn báo cần a1',
    () => expect(g('a3'), needLower(['a1'])),
  );
  test(
    'cùng cấp không chặn nhau: p2a mở khi p2b chưa chứng nhận',
    () => expect(g('p2a', logs: threePasses('p2a')), isA<SkillTestOpen>()),
  );
  test('cấp trùng: p3 cần cả hai bài cấp 2, liệt kê theo (cấp, id)', () {
    expect(g('p3', logs: threePasses('p3')), needLower(['p2a', 'p2b']));
    expect(
      g('p3', logs: threePasses('p3'), tests: [passedTest('p2a', 2, stToday)]),
      needLower(['p2b']),
    );
    expect(
      g(
        'p3',
        logs: threePasses('p3'),
        tests: [passedTest('p2a', 2, stToday), passedTest('p2b', 2, stToday)],
      ),
      isA<SkillTestOpen>(),
    );
  });
  test('đã chứng nhận: ngày lần đạt sớm nhất, kể cả khi chuỗi đã đứt', () {
    final early = stToday.subtract(const Duration(days: 9));
    final late = stToday.subtract(const Duration(days: 2));
    expect(
      g(
        'a1',
        logs: [stLog('a1', 2, stToday.subtract(const Duration(hours: 1)))],
        tests: [passedTest('a1', 1, late), passedTest('a1', 1, early)],
      ),
      isA<AlreadyCertified>().having((x) => x.at, 'at', early),
    );
  });
  test('vừa trượt, chưa tập thêm: phải tập ít nhất 1 buổi', () {
    final failedAt = stToday.subtract(const Duration(hours: 2));
    expect(
      g('a1', logs: threePasses('a1'), tests: [failedTest('a1', 1, failedAt)]),
      isA<NeedPracticeAfterFail>().having(
        (x) => x.failedAt,
        'failedAt',
        failedAt,
      ),
    );
  });
  test('lần trượt mới nhất quyết định, không phải lần trượt cũ', () {
    final older = stToday.subtract(const Duration(days: 2, hours: 5));
    final newer = stToday.subtract(const Duration(hours: 2));
    expect(
      g(
        'a1',
        logs: threePasses('a1'),
        tests: [failedTest('a1', 1, newer), failedTest('a1', 1, older)],
      ),
      isA<NeedPracticeAfterFail>().having((x) => x.failedAt, 'failedAt', newer),
    );
  });
  test('trượt rồi tập thêm một buổi đạt: mở lại', () {
    final logs = [
      ...threePasses('a1'),
      stLog('a1', 9, stToday.subtract(const Duration(hours: 1))),
    ];
    expect(
      g(
        'a1',
        logs: logs,
        tests: [
          failedTest('a1', 1, stToday.subtract(const Duration(hours: 2))),
        ],
      ),
      isA<SkillTestOpen>(),
    );
  });
  test('trượt rồi tập thêm một buổi trượt: chuỗi về 0, cần 3 buổi', () {
    final logs = [
      ...threePasses('a1'),
      stLog('a1', 5, stToday.subtract(const Duration(hours: 1))),
    ];
    expect(
      g(
        'a1',
        logs: logs,
        tests: [
          failedTest('a1', 1, stToday.subtract(const Duration(hours: 2))),
        ],
      ),
      needStreak(3),
    );
  });
  test('lần huỷ không tính là trượt', () {
    expect(
      g(
        'a1',
        logs: threePasses('a1'),
        tests: [
          cancelledTest('a1', 1, stToday.subtract(const Duration(hours: 2))),
        ],
      ),
      isA<SkillTestOpen>(),
    );
  });
  test('buổi của bài khác không làm chuỗi sai', () {
    expect(g('a1', logs: threePasses('p2a')), needStreak(3));
  });
  test('bài mục tiêu: 3 buổi đạt mục tiêu 25 thì mở', () {
    final logs = [
      for (var i = 3; i >= 1; i--)
        stLog('t2', 25, stToday.subtract(Duration(days: i)), attempts: null),
    ];
    expect(g('t2', logs: logs), isA<SkillTestOpen>());
  });

  group('testableDrillIds', () {
    List<DrillLog> targetPasses(String id) => [
      for (var i = 3; i >= 1; i--)
        stLog(id, 25, stToday.subtract(Duration(days: i)), attempts: null),
    ];
    final fixtures =
        <
          String,
          ({List<DrillLog> logs, List<SkillTest> tests, List<String> testable})
        >{
          'a1, a3, p2a': (
            logs: [
              ...threePasses('a1'),
              ...threePasses('a3'),
              ...threePasses('p2a'),
            ],
            tests: const <SkillTest>[],
            testable: ['a1', 'p2a'],
          ),
          'p2a, p2b, p3 (p3 chờ cấp 2)': (
            logs: [
              ...threePasses('p2a'),
              ...threePasses('p2b'),
              ...threePasses('p3'),
            ],
            tests: const <SkillTest>[],
            testable: ['p2a', 'p2b'],
          ),
          'a1 đã chứng nhận, a3 và t2 mở': (
            logs: [
              ...threePasses('a1'),
              ...threePasses('a3'),
              ...targetPasses('t2'),
            ],
            tests: [
              passedTest('a1', 1, stToday.subtract(const Duration(days: 5))),
            ],
            testable: ['t2', 'a3'],
          ),
        };
    for (final e in fixtures.entries) {
      test(
        '${e.key}: đúng danh sách (cấp, id), là tập con của readyDrillIds',
        () {
          final testable = testableDrillIds(
            drills: stDrills,
            logs: e.value.logs,
            tests: e.value.tests,
          );
          expect(testable, e.value.testable);
          final ready = computePlayerIntelligence(
            drills: stDrills,
            logs: e.value.logs,
          ).readyDrillIds;
          expect(ready.toSet().containsAll(testable), isTrue);
        },
      );
    }
    test('bộ 1: readyDrillIds gồm a1, a3, p2a còn testable không có a3', () {
      final logs = fixtures.values.first.logs;
      expect(
        computePlayerIntelligence(drills: stDrills, logs: logs).readyDrillIds,
        ['a1', 'a3', 'p2a'],
      );
    });
  });
}
