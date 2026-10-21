import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';

/// Nhóm lỗi của thẻ gợi ý (spec mục 10.2 bước 3). Thứ tự enum là thứ tự hoà.
enum CoachFaultGroup { pocketChoice, scratch, blockedPath, cuePosition, extraSpin, potOrSafety }

/// Nhóm của một lỗi. `objectMissed` (bi không vào lỗ) và `spinWorse` không có
/// trong bảng của spec: bi không vào thuộc *chọn lỗ*, đổi kiểu áp phê thuộc
/// *vị trí bi cái* (áp phê đổi chỗ bi cái dừng).
CoachFaultGroup faultGroupOf(CoachFault fault) => switch (fault) {
      CoachFault.pocketUnmakeable || CoachFault.pocketWorse || CoachFault.objectMissed =>
        CoachFaultGroup.pocketChoice,
      CoachFault.scratch => CoachFaultGroup.scratch,
      CoachFault.blocked => CoachFaultGroup.blockedPath,
      CoachFault.noNextShot ||
      CoachFault.strokeWorse ||
      CoachFault.powerWorse ||
      CoachFault.spinWorse =>
        CoachFaultGroup.cuePosition,
      CoachFault.spinUnneeded => CoachFaultGroup.extraSpin,
      CoachFault.shouldPot || CoachFault.shouldSafety => CoachFaultGroup.potOrSafety,
    };

/// Số liệu Coach của một nhóm tình huống (spec mục 10.2 bước 2–3).
final class CoachTopicStats {
  const CoachTopicStats({
    required this.topic,
    required this.total,
    required this.solved,
    this.recurring,
    this.recurringCount = 0,
  });

  final CoachTopic topic;

  /// Số lần làm được xét: tối đa [coachStatsWindow] lần gần nhất, bỏ lần
  /// chưa đủ dữ liệu.
  final int total;

  /// Số lần đạt mà không xem đáp án.
  final int solved;

  /// Nhóm lỗi lặp lại; null khi không nhóm nào đủ [coachRecurringMin] lần.
  final CoachFaultGroup? recurring;
  final int recurringCount;

  /// Đủ [coachStatsMin] lần để nhận xét.
  bool get enough => total >= coachStatsMin;
}

/// Số liệu từng nhóm từ các lần làm Coach. Mỗi nhóm xét [coachStatsWindow]
/// lần gần nhất (theo lúc xong), sau khi bỏ các lần chưa đủ dữ liệu — lần
/// đó không phải lỗi của người chơi.
Map<CoachTopic, CoachTopicStats> summarizeCoachAttempts(List<CoachAttempt> attempts) {
  final out = <CoachTopic, CoachTopicStats>{};
  for (final topic in CoachTopic.values) {
    final window = ([
      for (final a in attempts)
        if (a.topic == topic && a.outcome != CoachAttemptOutcome.undecided) a,
    ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt)))
        .take(coachStatsWindow)
        .toList();
    final counts = <CoachFaultGroup, int>{};
    for (final a in window) {
      final f = a.firstFault;
      if (f != null) counts.update(faultGroupOf(f), (n) => n + 1, ifAbsent: () => 1);
    }
    CoachFaultGroup? recurring;
    var recurringCount = 0;
    for (final g in CoachFaultGroup.values) {
      final n = counts[g] ?? 0;
      if (n >= coachRecurringMin && n > recurringCount) {
        recurring = g;
        recurringCount = n;
      }
    }
    out[topic] = CoachTopicStats(
      topic: topic,
      total: window.length,
      solved: window.where((a) => a.outcome.solved).length,
      recurring: recurring,
      recurringCount: recurringCount,
    );
  }
  return out;
}
