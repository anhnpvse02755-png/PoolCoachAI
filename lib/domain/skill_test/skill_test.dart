import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Hằng số của Skill Test.
abstract final class SkillTestConstants {
  /// Số buổi tập phải qua trước khi được kiểm tra lại sau một lần trượt.
  static const retakeSessions = 1;

  /// Số buổi gần nhất dùng để xét phong độ.
  static const recentFormWindow = 5;
}

/// Một lần kiểm tra kỹ năng (Skill Test).
///
/// Lần hoàn tất mang theo **ảnh chụp tiêu chí đạt** của bài tại lúc hoàn
/// tất: đúng một trong [passThreshold] (bài đếm cú) hoặc [target] (bài đo
/// bằng đơn vị khác), theo cùng quy ước với `Drill`. Chấm đạt luôn dùng
/// ảnh chụp này, không dùng bài hiện tại, để nếu ngưỡng của bài đổi sau
/// đó thì giấy chứng nhận cũ vẫn phản ánh tiêu chí mà nó đã đạt.
///
/// Lần huỷ, hoặc lần hoàn tất hỏng thiếu kết quả (dữ liệu từ đồng bộ),
/// có thể không có trường tiêu chí nào.
final class SkillTest {
  const SkillTest({
    required this.id,
    required this.drillId,
    required this.drillLevel,
    required this.tableSize,
    required this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.score,
    this.attempts,
    this.passed,
    this.notes,
    this.passThreshold,
    this.target,
  })  : assert(
          passThreshold == null || target == null,
          'SkillTest takes passThreshold or target, never both',
        ),
        assert(
          completedAt == null ||
              cancelledAt != null ||
              score == null ||
              passThreshold != null ||
              target != null,
          'A completed SkillTest with a result needs passThreshold or target',
        );

  final String id;
  final String drillId;
  final int drillLevel;
  final TableSize tableSize;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final num? score;
  final int? attempts;
  final bool? passed;
  final String? notes;

  /// Ảnh chụp ngưỡng tỉ lệ của bài đếm cú lúc hoàn tất.
  final double? passThreshold;

  /// Ảnh chụp mục tiêu tuyệt đối của bài lúc hoàn tất.
  final num? target;

  bool get isCancelled => cancelledAt != null;
  bool get isCompleted => completedAt != null && !isCancelled;

  /// Chỉ lần hoàn tất có `passed == true` mới chứng nhận.
  bool get certifies => isCompleted && passed == true;

  /// Trượt phải là `passed == false` rõ ràng; thiếu `passed` không phải trượt.
  bool get failed => isCompleted && passed == false;

  @override
  bool operator ==(Object other) =>
      other is SkillTest &&
      other.id == id &&
      other.drillId == drillId &&
      other.drillLevel == drillLevel &&
      other.tableSize == tableSize &&
      other.startedAt == startedAt &&
      other.completedAt == completedAt &&
      other.cancelledAt == cancelledAt &&
      other.score == score &&
      other.attempts == attempts &&
      other.passed == passed &&
      other.notes == notes &&
      other.passThreshold == passThreshold &&
      other.target == target;

  @override
  int get hashCode => Object.hash(
        id,
        drillId,
        drillLevel,
        tableSize,
        startedAt,
        completedAt,
        cancelledAt,
        score,
        attempts,
        passed,
        notes,
        passThreshold,
        target,
      );
}

enum SkillTestInputError {
  scoreInvalid,
  scoreNotWhole,
  scoreAboveAttempts,
  attemptsRequired,
  attemptsInvalid,
  attemptsNotAllowed,
}

/// Đạt hay không theo đúng tiêu chí của buổi tập: `drillRatio >= 1`.
/// `null` khi không chấm được (thiếu số lần thử), không quy về trượt.
bool? skillTestPassed(Drill drill, {required num score, int? attempts}) {
  final ratio = drillRatio(
    drill,
    DrillLog(
      id: 'skill-test',
      drillId: drill.id,
      date: DateTime.fromMillisecondsSinceEpoch(0),
      score: score,
      attempts: attempts,
    ),
  );
  if (ratio == null) return null;
  return ratio >= 1;
}

/// Mức điểm nhỏ nhất để đạt. Bài mục tiêu trả `target`; bài đếm cú trả
/// số lần trúng nhỏ nhất trong `0..attempts` mà vẫn đạt.
num? passMark(Drill drill, {int? attempts}) {
  if (!drill.usesAttempts) return drill.target;
  if (attempts == null || attempts <= 0) return null;
  for (var k = 0; k <= attempts; k++) {
    if (skillTestPassed(drill, score: k, attempts: attempts) == true) return k;
  }
  return null;
}

/// Bài giả dựng từ ảnh chụp tiêu chí, để dùng lại đúng logic chấm.
/// `null` khi lần kiểm tra không có ảnh chụp.
Drill? _snapshotDrill(SkillTest test) {
  final threshold = test.passThreshold;
  final target = test.target;
  if ((threshold == null) == (target == null)) return null;
  return Drill(
    id: test.drillId,
    cat: SkillCategory.aiming,
    name: test.drillId,
    level: test.drillLevel,
    unit: '',
    goal: '',
    steps: const [],
    passThreshold: threshold,
    target: target,
  );
}

/// Mức điểm đạt theo ảnh chụp tiêu chí của lần kiểm tra, không theo bài
/// hiện tại. `null` khi không có ảnh chụp hoặc không tính được.
num? skillTestPassMark(SkillTest test) {
  final drill = _snapshotDrill(test);
  if (drill == null) return null;
  return passMark(drill, attempts: test.attempts);
}

/// Chấm lại kết quả của lần kiểm tra theo ảnh chụp tiêu chí của nó.
/// `null` khi thiếu kết quả, thiếu ảnh chụp hoặc không chấm được.
bool? skillTestVerdict(SkillTest test) {
  final drill = _snapshotDrill(test);
  final score = test.score;
  if (drill == null || score == null) return null;
  return skillTestPassed(drill, score: score, attempts: test.attempts);
}

/// Kiểm tra kết quả nhập trước khi chấm; trả lỗi có tên hoặc `null`.
SkillTestInputError? checkSkillTestInput(
  Drill drill, {
  required num score,
  int? attempts,
}) {
  if (!score.isFinite || score < 0) return SkillTestInputError.scoreInvalid;
  if (drill.usesAttempts) {
    if (attempts == null) return SkillTestInputError.attemptsRequired;
    if (attempts <= 0) return SkillTestInputError.attemptsInvalid;
    if (score != score.truncate()) return SkillTestInputError.scoreNotWhole;
    if (score > attempts) return SkillTestInputError.scoreAboveAttempts;
  } else if (attempts != null) {
    return SkillTestInputError.attemptsNotAllowed;
  }
  return null;
}
