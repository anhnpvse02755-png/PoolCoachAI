import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

/// Tám cú vào liền: thang đã chắc 10, bài xong sớm.
ShotAttempts ladderPerfect() => ShotAttempts(List.filled(8, true));

/// Đề I với F1–F6 trọn điểm (60). [wagonAndTargetMade] = true thì F7, F8
/// cũng trọn (100); false thì trượt hết (60 → Masters trên bàn 9 feet).
Map<String, DrillAttempts> examIAttempts({required bool wagonAndTargetMade}) => {
      for (final id in ['F1', 'F2', 'F3', 'F4', 'F5']) id: ladderPerfect(),
      'F6': ShotAttempts(List.filled(10, true)),
      'F7': ShotAttempts(List.filled(20, wagonAndTargetMade)),
      'F8': ShotAttempts(List.filled(20, wagonAndTargetMade)),
    };

/// Đề II trọn điểm của bản [v].
Map<String, DrillAttempts> examIIPerfect(ExamIIVersion v) {
  const fullBreak = BreakCriteria(a: true, b: true, c: true, d: true, e: true);
  return {
    for (final d in examIIDrills(v))
      d.id: switch (d.kind) {
        ScoringKind.bestOfTwo => CountAttempts([d.perAttemptMax!]),
        ScoringKind.sumOfLowestTwo => CountAttempts(List.filled(3, d.perAttemptMax!)),
        ScoringKind.successCount => ShotAttempts(List.filled(d.attemptCount, true)),
        ScoringKind.medianBreak => BreakAttempts(List.filled(3, fullBreak)),
        ScoringKind.positionLadder => throw StateError('Đề II không có thang vị trí'),
      },
  };
}
