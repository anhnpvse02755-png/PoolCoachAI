import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Loại bước của Lộ trình (spec 2026-10-15 mục 4).
enum StepKind {
  /// Chưa có hạng: làm bộ câu hỏi hoặc bài BU trước.
  xacDinhHang,

  /// Tập một nhóm kỹ năng tới khi xong (mục 4.4).
  nhom,

  /// Điểm mất ở S9 — không nối nhóm nào, không có bài tập đo được (R5).
  buLe,

  /// Một bài tập của mục tiêu Thuần thục kỹ năng (R6).
  baiTap,

  /// Làm lại bài kiểm tra BU — bước cuối của Lên hạng.
  lamBaiBu,

  /// Chuẩn bị giải: ghi thêm trận có ghi cú để biết nhóm yếu.
  dauTap,
}

enum StepStatus { dangLam, xong, chuaToi, khongKip }

/// Vì sao có bước này — **dữ liệu**, câu chữ dựng ở `Vi.stepReason`.
sealed class StepReason {
  const StepReason();
}

final class LostBuPoints extends StepReason {
  const LostBuPoints(this.points, this.drillIds);
  final int points;
  final List<String> drillIds;
}

final class Unmeasured extends StepReason {
  const Unmeasured(this.sessions);
  final int sessions;
}

final class BelowStrong extends StepReason {
  const BelowStrong(this.mastery);
  final int mastery;
}

/// Đã đạt 75, còn thiếu chuỗi buổi đạt liên tiếp.
final class NeedStreak extends StepReason {
  const NeedStreak();
}

final class DrillLevel extends StepReason {
  const DrillLevel(this.level);
  final int level;
}

/// Ngày được làm bài BU tiếp; null là làm được ngay.
final class RetestFrom extends StepReason {
  const RetestFrom(this.from);
  final DateTime? from;
}

/// Mốc hạng [rank] trên đường lên hạng đích xa hơn một bậc: làm lại bài BU
/// khi điểm đã đủ để lên hạng này.
///
/// [from] là ngày được làm bài BU tiếp (null là làm được ngay), cùng cổng với
/// bước BU cuối. [retake] đúng khi người chơi đã có kết quả BU để làm lại.
final class RankMilestone extends StepReason {
  const RankMilestone(this.rank, {this.from, this.retake = true});
  final Rank rank;
  final DateTime? from;
  final bool retake;
}

/// Nhóm hỏng [failures]/[attempts] lần trong các trận gần đây.
final class MatchWeakness extends StepReason {
  const MatchWeakness(this.failures, this.attempts);
  final int failures;
  final int attempts;
}

/// Mới có [have] trận có ghi cú trong cửa sổ, cần [need].
final class NotEnoughMatches extends StepReason {
  const NotEnoughMatches(this.have, this.need);
  final int have;
  final int need;
}

final class NeedRank extends StepReason {
  const NeedRank();
}

/// Ngày dự kiến xong một bước, hoặc "chưa đủ dữ liệu" — không đoán (mục 4.5).
final class Estimate {
  const Estimate.on(DateTime this.date);
  const Estimate.notEnoughData() : date = null;

  final DateTime? date;
}

final class RoadmapStep {
  const RoadmapStep({
    required this.kind,
    required this.status,
    required this.reason,
    this.category,
    this.drillId,
    this.buDrillIds = const [],
    this.mastery,
    this.passStreak = 0,
    this.estimate,
  });

  final StepKind kind;
  final StepStatus status;
  final StepReason reason;
  final SkillCategory? category;

  /// Bài tập của bước (`pickDrillInCategory`, R3) hoặc bài của bước baiTap.
  final String? drillId;
  final List<String> buDrillIds;

  /// Độ thuần thục của nhóm lúc tính; null là chưa đủ 3 buổi.
  final int? mastery;

  /// Số buổi đạt liên tiếp gần nhất của [drillId], tối đa 3.
  final int passStreak;

  /// null: bước không có dòng ngày (đã xong, S9, bài của mục tiêu thuần thục).
  final Estimate? estimate;

  RoadmapStep withStatus(StepStatus s) => _copy(status: s);
  RoadmapStep withEstimate(Estimate e) => _copy(estimate: e);

  RoadmapStep _copy({StepStatus? status, Estimate? estimate}) => RoadmapStep(
        kind: kind,
        status: status ?? this.status,
        reason: reason,
        category: category,
        drillId: drillId,
        buDrillIds: buDrillIds,
        mastery: mastery,
        passStreak: passStreak,
        estimate: estimate ?? this.estimate,
      );
}

final class Roadmap {
  const Roadmap({
    required this.goal,
    required this.steps,
    this.blocked,
    this.from,
    this.target,
    this.pointsNeeded,
  });

  final PlayerGoal goal;
  final List<RoadmapStep> steps;
  final LenHangBlock? blocked;

  /// Lên hạng: hạng hiện tại và hạng đích.
  final Rank? from;
  final Rank? target;

  /// Lên hạng: điểm BU còn thiếu; null khi chưa có bài BU hoàn chỉnh.
  final int? pointsNeeded;

  static bool _progression(RoadmapStep s) => s.kind != StepKind.buLe;

  /// Bước người chơi nên làm bây giờ — Trang chủ hiện bước này.
  RoadmapStep? get currentStep => steps
      .where((s) => _progression(s) && s.status == StepStatus.dangLam)
      .firstOrNull;

  List<RoadmapStep> get missed =>
      steps.where((s) => s.status == StepStatus.khongKip).toList();

  /// Ngày dự kiến của bước cuối còn phải làm và còn kịp; null khi không còn bước nào.
  Estimate? get finish => steps
      .where((s) =>
          _progression(s) &&
          s.status != StepStatus.xong &&
          s.status != StepStatus.khongKip &&
          s.estimate != null)
      .lastOrNull
      ?.estimate;

  /// Mọi bước đã xong. Lên hạng không bao giờ "xong": lên hạng thì đích chuyển.
  bool get achieved =>
      goal.kind != GoalKind.lenHang &&
      steps.where(_progression).every((s) => s.status == StepStatus.xong);
}
