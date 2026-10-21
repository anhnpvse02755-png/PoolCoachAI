import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/session.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/planner_tables.dart';

void main() {
  final situation = CoachSituation(
    key: 'lib:pos-rail-1',
    topic: CoachTopic.position,
    source: CoachSource.library,
    difficulty: CoachDifficulty.easy,
    setup: railTable(),
    libraryId: 'pos-rail-1',
  );
  final t0 = DateTime(2026, 10, 21, 9);
  PotAnswer a(double power) =>
      PotAnswer(ball: 1, pocket: Pocket.bottomMiddle, stroke: Stroke.stun, power: power);
  const wrong = CoachVerdict(outcome: CoachOutcome.wrong, fault: CoachFault.powerWorse);
  const best = CoachVerdict(outcome: CoachOutcome.best);
  const timeout = CoachVerdict(outcome: CoachOutcome.undecided, undecided: CoachUndecidedReason.timeout);
  const potVsSafety =
      CoachVerdict(outcome: CoachOutcome.undecided, undecided: CoachUndecidedReason.potVsSafety);

  test('sai 1 → gợi ý 1 → sai 2 → gợi ý 2 → sai 3 → đáp án', () {
    final s = CoachSession(situation, startedAt: t0);
    expect(s.hintLevel, 0);
    expect(s.nextTry, 1);
    s.record(a(30), wrong);
    expect(s.hintLevel, 1);
    expect(s.revealed, isFalse);
    expect(s.nextTry, 2);
    s.record(a(60), wrong);
    expect(s.hintLevel, 2);
    s.record(a(75), wrong);
    expect(s.wrongs, coachMaxAnswers);
    expect(s.revealed, isTrue);
    expect(s.ended, isTrue);
    expect(s.outcome, CoachAttemptOutcome.revealed);
    final at = s.toAttempt(id: 'x', userId: 'u1', finishedAt: t0)!;
    expect(at.answers, hasLength(3));
    expect(at.firstFault, CoachFault.powerWorse);
    expect(at.situationKey, 'lib:pos-rail-1');
    expect(at.scoringVersion, coachScoringVersion);
  });

  test('đạt ở lần thứ k → solvedk; đã kết thúc thì không nhận thêm', () {
    final s = CoachSession(situation, startedAt: t0)
      ..record(a(30), wrong)
      ..record(a(45), best);
    expect(s.outcome, CoachAttemptOutcome.solved2);
    expect(s.check(a(60)), SubmitCheck.ended);
    expect(CoachSession(situation, startedAt: t0).toAttempt(id: 'x', userId: 'u', finishedAt: t0), isNull);
  });

  test('Xem đáp án sớm → revealedEarly', () {
    final s = CoachSession(situation, startedAt: t0)..record(a(30), wrong);
    s.revealEarly();
    expect(s.revealed, isTrue);
    expect(s.outcome, CoachAttemptOutcome.revealedEarly);
  });

  test('chọn lại đúng cú vừa sai thì không chấm, không tính lần thử', () {
    final s = CoachSession(situation, startedAt: t0)..record(a(30), wrong);
    expect(s.check(a(30)), SubmitCheck.sameAsLast);
    expect(s.check(a(45)), SubmitCheck.ok);
    expect(s.tries, 1);
  });

  test('chưa đủ dữ liệu (quá giờ) không tính lần thử, chưa kết thúc', () {
    final s = CoachSession(situation, startedAt: t0)..record(a(30), timeout);
    expect(s.tries, 0);
    expect(s.ended, isFalse);
    expect(s.nextTry, 1);
  });

  test('chưa đủ dữ liệu ăn hay thủ: kết thúc với kết quả undecided, không tính lần thử', () {
    final s = CoachSession(situation, startedAt: t0)..record(const SafetyAnswer(), potVsSafety);
    expect(s.tries, 0);
    expect(s.ended, isTrue);
    expect(s.outcome, CoachAttemptOutcome.undecided);
    final at = s.toAttempt(id: 'x', userId: 'u1', finishedAt: t0)!;
    expect(at.answers.single.kind, CoachAnswerKind.safety);
    expect(at.firstFault, isNull);
  });
}
