import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_scoring.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

enum BuExam { fundamentals, skills }

/// Năm kiểu chấm của spec mục 5.3.
enum ScoringKind { positionLadder, successCount, bestOfTwo, sumOfLowestTwo, medianBreak }

/// Một bài của đề BU, đúng như phiếu điểm.
final class BuDrill {
  const BuDrill({
    required this.id,
    required this.kind,
    required this.maxScore,
    required this.attemptCount,
    this.perAttemptMax,
    this.groups = 1,
  });

  /// 'F1'…'F8', 'S1'…'S10'.
  final String id;
  final ScoringKind kind;
  final int maxScore;

  /// Số lượt phải nhập đủ: 10 cú của thang, số ô của bài đếm, 2 lượt, 3 thế,
  /// 3 lần phá. Thang và S1/S2 có thể xong sớm hơn (xem [isDrillComplete]).
  final int attemptCount;

  /// Số bi tối đa một lượt — chỉ bài nhập số bi.
  final int? perAttemptMax;

  /// Bài đếm lượt chia nhóm: F7 10 bi đích × 2, F8 5 đích × 4, S5 n vị trí
  /// bi cái × 2. Bài khác là 1 nhóm.
  final int groups;

  BuExam get exam => id.startsWith('F') ? BuExam.fundamentals : BuExam.skills;
  int get attemptsPerGroup => attemptCount ~/ groups;
}

const _ladder = ScoringKind.positionLadder;

/// Đề I — BU_Exam-I_Score_Sheet.pdf.
const examIDrills = <BuDrill>[
  BuDrill(id: 'F1', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F2', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F3', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F4', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F5', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F6', kind: ScoringKind.successCount, maxScore: 10, attemptCount: 10),
  BuDrill(id: 'F7', kind: ScoringKind.successCount, maxScore: 20, attemptCount: 20, groups: 10),
  BuDrill(id: 'F8', kind: ScoringKind.successCount, maxScore: 20, attemptCount: 20, groups: 5),
];

int _by(ExamIIVersion v, int bachelors, int masters, int doctorate) => switch (v) {
      ExamIIVersion.bachelors => bachelors,
      ExamIIVersion.masters => masters,
      ExamIIVersion.doctorate => doctorate,
    };

/// Đề II — BU_Exam-II_Score_Sheet-{Bachelors,Masters,Doctorate}.pdf.
List<BuDrill> examIIDrills(ExamIIVersion v) {
  final line = _by(v, 4, 7, 10);
  final rail = _by(v, 7, 11, 15);
  final pattern = _by(v, 5, 6, 7);
  final positions = _by(v, 3, 5, 7);
  final shots = _by(v, 3, 5, 7);
  return [
    BuDrill(id: 'S1', kind: ScoringKind.bestOfTwo, maxScore: line, attemptCount: 2, perAttemptMax: line),
    BuDrill(id: 'S2', kind: ScoringKind.bestOfTwo, maxScore: rail, attemptCount: 2, perAttemptMax: rail),
    BuDrill(id: 'S3', kind: ScoringKind.sumOfLowestTwo, maxScore: 2 * pattern, attemptCount: 3, perAttemptMax: pattern),
    BuDrill(id: 'S4', kind: ScoringKind.sumOfLowestTwo, maxScore: 2 * pattern, attemptCount: 3, perAttemptMax: pattern),
    BuDrill(id: 'S5', kind: ScoringKind.successCount, maxScore: 2 * positions, attemptCount: 2 * positions, groups: positions),
    for (final id in const ['S6', 'S7', 'S8', 'S9'])
      BuDrill(id: id, kind: ScoringKind.successCount, maxScore: shots, attemptCount: shots, groups: shots),
    const BuDrill(id: 'S10', kind: ScoringKind.medianBreak, maxScore: 5, attemptCount: 3),
  ];
}

int examIIMax(ExamIIVersion v) => examIIDrills(v).fold(0, (s, d) => s + d.maxScore);

/// Bài theo mã. Bài Đề II cần biết bản.
BuDrill drillFor(String id, ExamIIVersion? version) {
  for (final d in examIDrills) {
    if (d.id == id) return d;
  }
  if (version == null) throw ArgumentError.value(id, 'id', 'bài Đề II cần biết bản');
  for (final d in examIIDrills(version)) {
    if (d.id == id) return d;
  }
  throw ArgumentError.value(id, 'id', 'không có bài này');
}

DrillAttempts emptyAttemptsFor(BuDrill d) => switch (d.kind) {
      ScoringKind.positionLadder || ScoringKind.successCount => ShotAttempts(const []),
      ScoringKind.bestOfTwo || ScoringKind.sumOfLowestTwo => CountAttempts(const []),
      ScoringKind.medianBreak => BreakAttempts(const []),
    };

bool _kindMatches(BuDrill d, DrillAttempts a) => switch (a) {
      ShotAttempts() => d.kind == ScoringKind.positionLadder || d.kind == ScoringKind.successCount,
      CountAttempts() => d.kind == ScoringKind.bestOfTwo || d.kind == ScoringKind.sumOfLowestTwo,
      BreakAttempts() => d.kind == ScoringKind.medianBreak,
    };

/// Bài đã đủ lượt để chấm chưa (spec mục 7.3: không chấm khi chưa đủ lượt).
bool isDrillComplete(BuDrill d, DrillAttempts a) {
  if (!_kindMatches(d, a)) {
    throw ArgumentError('Kết quả thô không đúng kiểu chấm của ${d.id}');
  }
  return switch (a) {
    ShotAttempts(:final shots) => d.kind == ScoringKind.positionLadder
        ? ladderSettled(shots)
        : shots.length >= d.attemptCount,
    CountAttempts(:final counts) => d.kind == ScoringKind.bestOfTwo
        ? counts.length >= 2 || (counts.length == 1 && counts.first == d.perAttemptMax)
        : counts.length >= d.attemptCount,
    BreakAttempts(:final breaks) => breaks.length >= d.attemptCount,
  };
}

/// Điểm bài; null khi chưa xong.
int? drillScore(BuDrill d, DrillAttempts a) {
  if (!isDrillComplete(d, a)) return null;
  return switch (a) {
    ShotAttempts(:final shots) =>
      d.kind == ScoringKind.positionLadder ? ladderScore(shots) : successCount(shots),
    CountAttempts(:final counts) =>
      d.kind == ScoringKind.bestOfTwo ? bestOfTwo(counts) : sumOfLowestTwo(counts),
    BreakAttempts(:final breaks) => medianOfThreeBreaks(breaks),
  };
}

/// Kết quả thô này ghi xuống được không: đúng kiểu, số bi trong khoảng,
/// lần phá chết cái không có b–e, và không lượt nào nằm sau lúc bài đã xong.
bool attemptsValid(BuDrill d, DrillAttempts a) {
  if (!_kindMatches(d, a)) return false;
  if (a.length > d.attemptCount) return false;
  switch (a) {
    case CountAttempts(:final counts):
      if (counts.any((c) => c < 0 || c > d.perAttemptMax!)) return false;
    case BreakAttempts(:final breaks):
      if (breaks.any((b) => !b.a && (b.b || b.c || b.d || b.e))) return false;
    case ShotAttempts():
      break;
  }
  var prefix = a;
  final prefixes = <DrillAttempts>[];
  while (!prefix.isEmpty) {
    prefix = prefix.withoutLast();
    prefixes.add(prefix);
  }
  return !prefixes.any((p) => isDrillComplete(d, p));
}
