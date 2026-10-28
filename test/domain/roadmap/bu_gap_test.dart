import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_category_map.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/assessment_fixtures.dart';
import '../../support/roadmap_fixtures.dart';

void main() {
  group('bảng nối 18 bài BU vào 6 nhóm (spec mục 5, chủ sản phẩm duyệt 15/10)', () {
    test('đúng từng dòng của spec', () {
      expect(buDrillCategory, {
        'F1': SkillCategory.aiming,
        'F2': SkillCategory.position,
        'F3': SkillCategory.position,
        'F4': SkillCategory.position,
        'F5': SkillCategory.position,
        'F6': SkillCategory.aiming,
        'F7': SkillCategory.aiming,
        'F8': SkillCategory.position,
        'S1': SkillCategory.aiming,
        'S2': SkillCategory.aiming,
        'S3': SkillCategory.position,
        'S4': SkillCategory.position,
        'S5': SkillCategory.safety,
        'S6': SkillCategory.kick,
        'S7': SkillCategory.bank,
        'S8': null,
        'S9': null,
        'S10': SkillCategory.breakShot,
      });
      expect(buDrillCategory.keys.toList(),
          ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10']);
    });
  });

  test('sàn BU của từng hạng theo bảng đã duyệt', () {
    expect(buFloor(Rank.c), 140);
    expect(buFloor(Rank.d), 125);
    expect(buFloor(Rank.a), 175);
    expect(buFloor(Rank.k), 0);
  });

  group('lần hoàn chỉnh gần nhất', () {
    BuTest buTest(String id, {DateTime? done, DateTime? cancelled}) => BuTest(
        id: id,
        startedAt: DateTime(2026, 10, 1),
        tableSize: TableSize.nineFootPlus,
        completedAt: done,
        cancelledAt: cancelled);

    test('bỏ qua lần đang làm và lần đã hủy', () {
      expect(latestCompletedTestId([
        buTest('cu', done: DateTime(2026, 10, 2)),
        buTest('moi', done: DateTime(2026, 10, 9)),
        buTest('dang-lam'),
        buTest('huy', cancelled: DateTime(2026, 10, 12)),
      ]), 'moi');
      expect(latestCompletedTestId([buTest('dang-lam')]), isNull);
      expect(latestCompletedTestId(const []), isNull);
    });
  });

  group('điểm mất theo bài và theo nhóm', () {
    final snapshot = TestSnapshot(
      test: BuTest(
        id: 't1',
        startedAt: DateTime(2026, 10, 14, 8),
        tableSize: TableSize.nineFootPlus,
        completedAt: DateTime(2026, 10, 14, 11),
        examIScore: 60,
        examIIVersion: ExamIIVersion.masters,
        examIIScore: 77,
        totalScore: 137,
        resultRank: Rank.d,
      ),
      attempts: {
        ...examIAttempts(wagonAndTargetMade: false),
        ...examIIPerfect(ExamIIVersion.masters),
      },
    );

    test('điểm mất = tối đa của bản đã làm − điểm đạt', () {
      final r = buResultFrom(snapshot);
      expect(r.testId, 't1');
      expect(r.total, 137);
      expect(r.lost['F7'], 20);
      expect(r.lost['F8'], 20);
      expect(r.lost['F1'], 0);
      expect(r.lost['S1'], 0);
      expect(r.lost.length, 18);
    });

    test('buResultFrom điền max của từng bài', () {
      final r = buResultFrom(snapshot);
      expect(r.max['F7'], 20);
      expect(r.max['F1'], 10);
      expect(r.max['S1'], 7);
      expect(r.max['S10'], 5);
      expect(r.max.length, 18);
    });

    test('cộng dồn theo nhóm; S8, S9 tính riêng', () {
      final r = BuResult(
        testId: 't',
        completedAt: DateTime(2026, 10, 14),
        total: 120,
        lost: const {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1, 'S10': 0},
      );
      final lost = lostByCategory(r);
      expect(lost.byCategory, {
        SkillCategory.aiming: 5,
        SkillCategory.position: 7,
        SkillCategory.safety: 6,
      });
      expect(lost.unmapped, 3);
      expect(lost.unmappedIds, ['S8', 'S9']);
      expect(lostDrillsIn(r, SkillCategory.position), ['F3', 'F5']);
      expect(lostDrillsIn(r, SkillCategory.breakShot), isEmpty);
    });

    test('tổng điểm theo nhóm cộng S8/S9 bằng tổng điểm mất', () {
      final r = buResultFrom(snapshot);
      final lost = lostByCategory(r);
      final sum = lost.byCategory.values.fold(0, (s, v) => s + v) + lost.unmapped;
      expect(sum, r.lost.values.fold(0, (s, v) => s + v));
    });
  });

  group('điểm BU theo nhóm', () {
    test('buCategoryPercent theo bản đã làm, S8/S9 không tính', () {
      final r = buResultGraded(
        completedAt: DateTime(2026, 10, 1),
        // aiming: F1 10 + F6 10 + F7 20 + S1 7 + S2 11 = 58; mất 30 -> 28
        // position: F2-F5 40 + F8 20 + S3 12 + S4 12 = 84; mất 21 -> 63
        // safety: S5 10; mất 0 -> 100. S8/S9 mất hết nhưng bị bỏ qua.
        lost: const {
          'F7': 20, 'F6': 10, 'F2': 10, 'F8': 11, 'S8': 5, 'S9': 5,
        },
      );
      final p = buCategoryPercent(r);
      expect(p[SkillCategory.aiming], 48);
      expect(p[SkillCategory.position], 75);
      expect(p[SkillCategory.safety], 100);
      expect(p[SkillCategory.kick], 100);
      expect(p[SkillCategory.bank], 100);
      expect(p[SkillCategory.breakShot], 100);
    });

    test('kết quả không có max: không nhóm nào có phần trăm', () {
      final r = BuResult(
          testId: 't', completedAt: DateTime(2026, 10, 1), total: 100, lost: const {'F7': 20});
      expect(buCategoryPercent(r), isEmpty);
    });
  });
}
