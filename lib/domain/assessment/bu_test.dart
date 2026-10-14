import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Một lần kiểm tra BU = Đề I + Đề II (spec mục 5.4, 6.1).
final class BuTest {
  const BuTest({
    required this.id,
    required this.startedAt,
    required this.tableSize,
    this.completedAt,
    this.cancelledAt,
    this.examIScore,
    this.examIIVersion,
    this.examIIScore,
    this.totalScore,
    this.resultRank,
  });

  final String id;
  final DateTime startedAt;
  final TableSize tableSize;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// Có điểm Đề I nghĩa là Đề I đã chốt và bản Đề II đã được xếp.
  final int? examIScore;
  final ExamIIVersion? examIIVersion;
  final int? examIIScore;
  final int? totalScore;
  final Rank? resultRank;

  bool get isCompleted => completedAt != null;
  bool get isCancelled => cancelledAt != null;
  bool get isActive => !isCompleted && !isCancelled;

  @override
  bool operator ==(Object other) =>
      other is BuTest &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.tableSize == tableSize &&
      other.completedAt == completedAt &&
      other.cancelledAt == cancelledAt &&
      other.examIScore == examIScore &&
      other.examIIVersion == examIIVersion &&
      other.examIIScore == examIIScore &&
      other.totalScore == totalScore &&
      other.resultRank == resultRank;

  @override
  int get hashCode => Object.hash(id, startedAt, tableSize, completedAt, cancelledAt,
      examIScore, examIIVersion, examIIScore, totalScore, resultRank);
}

/// Một lần kiểm tra cùng kết quả thô của từng bài — đủ để màn làm bài biết
/// đang ở đâu sau khi mở lại app (spec mục 6.1).
final class TestSnapshot {
  TestSnapshot({
    required this.test,
    required Map<String, DrillAttempts> attempts,
    Map<String, DateTime> touched = const {},
  })  : attempts = Map.unmodifiable(attempts),
        touched = Map.unmodifiable(touched);

  final BuTest test;
  final Map<String, DrillAttempts> attempts;

  /// Lúc ghi gần nhất của từng bài — để *Hoàn tác* biết cú nào vừa nhập.
  final Map<String, DateTime> touched;

  BuExam get currentExam =>
      test.examIScore == null ? BuExam.fundamentals : BuExam.skills;

  List<BuDrill> get currentDrills => currentExam == BuExam.fundamentals
      ? examIDrills
      : examIIDrills(test.examIIVersion!);

  DrillAttempts attemptsOf(BuDrill d) => attempts[d.id] ?? emptyAttemptsFor(d);

  bool _complete(BuDrill d) => isDrillComplete(d, attemptsOf(d));

  /// Bài đầu tiên chưa xong của đề đang làm; null khi đề đã đủ.
  BuDrill? get nextDrill {
    if (!test.isActive) return null;
    for (final d in currentDrills) {
      if (!_complete(d)) return d;
    }
    return null;
  }

  bool get examIReady =>
      test.isActive && test.examIScore == null && examIDrills.every(_complete);

  bool get examIIReady =>
      test.isActive &&
      test.examIIVersion != null &&
      examIIDrills(test.examIIVersion!).every(_complete);

  /// Bài này còn nhập được không: lần còn đang làm, và đề của bài chưa khoá
  /// (Đề I khoá khi đã có điểm Đề I, để bản Đề II đã xếp không đổi theo).
  bool isEditable(String drillId) {
    if (!test.isActive) return false;
    return drillId.startsWith('F')
        ? test.examIScore == null
        : test.examIIVersion != null;
  }

  /// Đề II đã bắt đầu: có dòng kết quả của một bài S, kể cả dòng đã hoàn
  /// tác về rỗng. Màn làm bài dựa vào đây để thôi hỏi "làm ngay hay để sau".
  bool get examIIStarted => attempts.keys.any((k) => k.startsWith('S'));

  /// Tổng điểm các bài đã xong trong [drills].
  int scoreOf(List<BuDrill> drills) =>
      drills.fold(0, (s, d) => s + (drillScore(d, attemptsOf(d)) ?? 0));

  /// "Điểm hiện tại" của đề đang làm (spec mục 7.3).
  int get runningScore => scoreOf(currentDrills);
}
