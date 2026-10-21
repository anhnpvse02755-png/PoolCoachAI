import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

/// Kết luận của một câu trả lời (spec mục 6.5–6.6).
enum CoachOutcome {
  /// Đúng cú Planner chọn.
  best,

  /// Điểm trong [coachScoreTolerance] của cú tốt nhất.
  equivalent,

  /// Lỗ khác lỗ Planner mà điểm thấp hơn, hoặc Planner không có cú ăn mà cú
  /// người chơi vào lỗ theo mô phỏng.
  better,
  wrong,

  /// Chưa đủ dữ liệu để chấm: không tính lần thử.
  undecided,
}

enum CoachUndecidedReason {
  /// Lõi quá giờ ở cú người chơi chọn.
  timeout,

  /// Planner không bao giờ so cú ăn với cú thủ (spec Planner mục 5.5).
  potVsSafety,
}

/// Lỗi chính của một câu trả lời sai (spec mục 6.7).
enum CoachFault {
  // Hỏng cú.
  pocketUnmakeable,
  scratch,
  objectMissed,
  blocked,
  noNextShot,
  // Ăn hay thủ.
  shouldPot,
  shouldSafety,
  // Kém hơn.
  pocketWorse,
  spinUnneeded,
  strokeWorse,
  powerWorse,

  /// Có áp phê, nhưng khác kiểu áp phê của cú gần nhất trong tập đạt (chỉ
  /// gặp khi Planner phải dùng tầng áp phê). Không có trong bảng mục 6.7
  /// của spec: thêm lúc làm T1 để không gán nhầm sang lỗi khác.
  spinWorse,
}

/// Năm lỗi "hỏng cú" — cú không vào, chết cái hay giết cú sau.
const coachBreakFaults = {
  CoachFault.pocketUnmakeable,
  CoachFault.scratch,
  CoachFault.objectMissed,
  CoachFault.blocked,
  CoachFault.noNextShot,
};

/// Kết luận kèm dữ liệu để dựng gợi ý và đáp án. Không có chữ nào ở đây.
final class CoachVerdict {
  const CoachVerdict({
    required this.outcome,
    this.fault,
    this.breakage,
    this.undecided,
    this.pocket,
    this.unmakeable,
    this.scratchPocket,
    this.blocker,
    this.nextBall,
    this.playerAimed,
    this.playerScore,
    this.nearest,
    this.noPlannerPot = false,
  });

  final CoachOutcome outcome;
  final CoachFault? fault;

  /// Lỗi hỏng cụ thể khi [fault] là [CoachFault.shouldSafety], để gợi ý 1
  /// nói đúng hậu quả. Các lỗi khác: bằng [fault] nếu là lỗi hỏng.
  final CoachFault? breakage;
  final CoachUndecidedReason? undecided;

  /// Lỗ người chơi chọn; null khi chọn Phòng thủ.
  final Pocket? pocket;
  final UnmakeableReason? unmakeable;

  /// Lỗ bi cái rơi khi chết cái.
  final Pocket? scratchPocket;

  /// Số bi chắn đầu tiên trên đường đi.
  final int? blocker;

  /// Bi kế tiếp sau bi phải chạm; null khi là bi cuối.
  final int? nextBall;

  /// Cú đã mô phỏng của người chơi — bàn vẽ đường đi của nó.
  final AimedShot? playerAimed;
  final OptionScore? playerScore;

  /// Cú trong tập đạt cần đổi ít thông số nhất ([nearestAccepted]).
  final ScoredOption? nearest;

  /// Đạt vì Planner không có cú ăn ở lỗ dễ nhất (bước 0 là dự phòng hay
  /// phòng thủ), không phải vì điểm thấp hơn.
  final bool noPlannerPot;

  bool get passed =>
      outcome == CoachOutcome.best ||
      outcome == CoachOutcome.equivalent ||
      outcome == CoachOutcome.better;

  /// Có tính là một lần thử không: chưa đủ dữ liệu thì không.
  bool get counts => outcome != CoachOutcome.undecided;

  /// Lỗi để dựng gợi ý 1: [CoachFault.shouldSafety] thì lấy lỗi hỏng cụ thể.
  CoachFault? get consequence => fault == CoachFault.shouldSafety ? breakage : fault;
}
