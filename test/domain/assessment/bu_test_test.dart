import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';

import '../../support/assessment_fixtures.dart';

void main() {
  final start = DateTime(2026, 10, 14, 9);
  BuTest test0({int? examI, ExamIIVersion? v, DateTime? completed, DateTime? cancelled, String id = 't1'}) =>
      BuTest(
        id: id,
        startedAt: start,
        tableSize: TableSize.nineFootPlus,
        examIScore: examI,
        examIIVersion: v,
        completedAt: completed,
        cancelledAt: cancelled,
      );

  group('TestSnapshot', () {
    test('lần mới: đang ở Đề I, bài kế là F1', () {
      final s = TestSnapshot(test: test0(), attempts: const {});
      expect(s.currentExam, BuExam.fundamentals);
      expect(s.nextDrill!.id, 'F1');
      expect(s.examIReady, isFalse);
      expect(s.runningScore, 0);
    });

    test('đang dở F1 thì bài kế vẫn là F1; F1 xong thì sang F2', () {
      final mid = TestSnapshot(test: test0(), attempts: {'F1': ShotAttempts([true, false])});
      expect(mid.nextDrill!.id, 'F1');
      final done = TestSnapshot(test: test0(), attempts: {'F1': ladderPerfect()});
      expect(done.nextDrill!.id, 'F2');
      expect(done.runningScore, 10);
    });

    test('đủ 8 bài Đề I thì sẵn sàng chấm Đề I, chưa có bài kế', () {
      final s = TestSnapshot(test: test0(), attempts: examIAttempts(wagonAndTargetMade: false));
      expect(s.examIReady, isTrue);
      expect(s.nextDrill, isNull);
      expect(s.scoreOf(examIDrills), 60);
    });

    test('đã có điểm Đề I: sang Đề II đúng bản, Đề I bị khoá', () {
      final s = TestSnapshot(
        test: test0(examI: 60, v: ExamIIVersion.masters),
        attempts: examIAttempts(wagonAndTargetMade: false),
      );
      expect(s.currentExam, BuExam.skills);
      expect(s.nextDrill!.id, 'S1');
      expect(s.isEditable('F8'), isFalse);
      expect(s.isEditable('S1'), isTrue);
      expect(s.examIIStarted, isFalse);
    });

    test('đủ Đề II thì sẵn sàng hoàn tất', () {
      final s = TestSnapshot(
        test: test0(examI: 60, v: ExamIIVersion.masters),
        attempts: {
          ...examIAttempts(wagonAndTargetMade: false),
          ...examIIPerfect(ExamIIVersion.masters),
        },
      );
      expect(s.examIIReady, isTrue);
      expect(s.scoreOf(examIIDrills(ExamIIVersion.masters)), 77);
    });

    test('lần đã hoàn tất hay đã hủy thì không sửa được bài nào', () {
      final done = TestSnapshot(test: test0(completed: start), attempts: const {});
      final gone = TestSnapshot(test: test0(cancelled: start), attempts: const {});
      expect(done.isEditable('F1'), isFalse);
      expect(gone.isEditable('F1'), isFalse);
    });
  });

  group('giãn cách 14 ngày (Q12, D6 của kế hoạch)', () {
    test('chưa hoàn tất lần nào thì làm được ngay', () {
      expect(retestAvailableFrom(const []), isNull);
      expect(retestAllowed(const [], start), isTrue);
    });

    test('ngày kiểm tra lại tính từ ngày hoàn tất, theo nửa đêm', () {
      final done = test0(completed: DateTime(2026, 10, 1, 21));
      expect(retestAvailableFrom([done]), DateTime(2026, 10, 15));
      expect(retestAllowed([done], DateTime(2026, 10, 14, 23, 59)), isFalse);
      expect(retestAllowed([done], DateTime(2026, 10, 15)), isTrue);
    });

    test('lấy lần hoàn tất gần nhất', () {
      final older = test0(id: 'a', completed: DateTime(2026, 9, 1));
      final newer = test0(id: 'b', completed: DateTime(2026, 10, 1));
      expect(retestAvailableFrom([newer, older]), DateTime(2026, 10, 15));
    });

    test('lần bị hủy không tính vào giãn cách', () {
      final cancelled = test0(id: 'c', cancelled: DateTime(2026, 10, 10));
      expect(retestAvailableFrom([cancelled]), isNull);
    });

    test('lần đang làm dở không tính', () {
      expect(retestAvailableFrom([test0()]), isNull);
    });

    test('bỏ qua chính lần đang xét khi hoàn tất', () {
      final self = test0(id: 'me', completed: DateTime(2026, 10, 1));
      expect(retestAvailableFrom([self], exceptTestId: 'me'), isNull);
    });
  });
}
