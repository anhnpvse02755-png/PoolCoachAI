import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';

import '../../support/coach_fixtures.dart';

void main() {
  test('ít hơn coachStatsMin lần thì chưa đủ dữ liệu', () {
    final few = [
      for (var i = 0; i < coachStatsMin - 1; i++) attempt(CoachAttemptOutcome.solved1, minute: i),
    ];
    final s = summarizeCoachAttempts(few)[CoachTopic.position]!;
    expect(s.total, coachStatsMin - 1);
    expect(s.enough, isFalse);
    final enough = summarizeCoachAttempts([...few, attempt(CoachAttemptOutcome.revealed, minute: 99)]);
    expect(enough[CoachTopic.position]!.enough, isTrue);
  });

  test('cửa sổ coachStatsWindow lần gần nhất; lần chưa đủ dữ liệu không tính', () {
    final old = [
      for (var i = 0; i < coachStatsWindow; i++) attempt(CoachAttemptOutcome.revealed, minute: i),
    ];
    final recent = [
      for (var i = 0; i < coachStatsWindow; i++)
        attempt(CoachAttemptOutcome.solved2, minute: 100 + i),
    ];
    final undecided = attempt(CoachAttemptOutcome.undecided, minute: 999);
    final s = summarizeCoachAttempts([...recent, ...old, undecided])[CoachTopic.position]!;
    expect(s.total, coachStatsWindow);
    expect(s.solved, coachStatsWindow);
  });

  test('đạt mà không xem đáp án mới là giải được', () {
    final s = summarizeCoachAttempts([
      attempt(CoachAttemptOutcome.solved1),
      attempt(CoachAttemptOutcome.solved3),
      attempt(CoachAttemptOutcome.revealed),
      attempt(CoachAttemptOutcome.revealedEarly),
    ])[CoachTopic.position]!;
    expect(s.solved, 2);
    expect(s.total, 4);
  });

  test('lỗi lặp lại: ≥ coachRecurringMin lần cùng nhóm lỗi; hoà theo thứ tự nhóm', () {
    List<CoachAttempt> of(CoachFault f, int k, int from) => [
          for (var i = 0; i < k; i++) attempt(CoachAttemptOutcome.revealed, fault: f, minute: from + i),
        ];
    final below = summarizeCoachAttempts(of(CoachFault.scratch, coachRecurringMin - 1, 0));
    expect(below[CoachTopic.position]!.recurring, isNull);

    final s = summarizeCoachAttempts([
      ...of(CoachFault.powerWorse, coachRecurringMin, 0),
      ...of(CoachFault.pocketWorse, coachRecurringMin, 10),
    ])[CoachTopic.position]!;
    // Hoà: chọn lỗ đứng trước vị trí bi cái.
    expect(s.recurring, CoachFaultGroup.pocketChoice);
    expect(s.recurringCount, coachRecurringMin);

    // Gom theo nhóm lỗi: trô + lực + không còn cú sau đều là vị trí bi cái.
    final grouped = summarizeCoachAttempts([
      attempt(CoachAttemptOutcome.revealed, fault: CoachFault.strokeWorse, minute: 1),
      attempt(CoachAttemptOutcome.revealed, fault: CoachFault.powerWorse, minute: 2),
      attempt(CoachAttemptOutcome.revealed, fault: CoachFault.noNextShot, minute: 3),
    ])[CoachTopic.position]!;
    expect(grouped.recurring, CoachFaultGroup.cuePosition);
  });

  test('mỗi lỗi thuộc đúng một nhóm', () {
    expect(faultGroupOf(CoachFault.pocketUnmakeable), CoachFaultGroup.pocketChoice);
    expect(faultGroupOf(CoachFault.scratch), CoachFaultGroup.scratch);
    expect(faultGroupOf(CoachFault.blocked), CoachFaultGroup.blockedPath);
    expect(faultGroupOf(CoachFault.spinUnneeded), CoachFaultGroup.extraSpin);
    expect(faultGroupOf(CoachFault.shouldSafety), CoachFaultGroup.potOrSafety);
    expect(faultGroupOf(CoachFault.shouldPot), CoachFaultGroup.potOrSafety);
  });

  test('nhóm khác không lẫn vào', () {
    final s = summarizeCoachAttempts([attempt(CoachAttemptOutcome.solved1, topic: CoachTopic.kick)]);
    expect(s[CoachTopic.kick]!.total, 1);
    expect(s[CoachTopic.position]!.total, 0);
  });
}
