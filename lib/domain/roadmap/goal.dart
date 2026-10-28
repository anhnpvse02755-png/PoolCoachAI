import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Ba loại mục tiêu của Lộ trình (spec 2026-10-15 mục 3).
enum GoalKind { lenHang, thuanThucKyNang, chuanBiGiai }

/// Mục tiêu đang chạy của một tài khoản.
///
/// Lên hạng mặc định nhắm hạng ngay trên hạng hiện tại (targetRank null),
/// nên lên được hạng thì đích tự chuyển; người chơi có thể chọn hạng xa hơn.
final class PlayerGoal {
  const PlayerGoal({
    required this.goalId,
    required this.kind,
    required this.createdAt,
    this.category,
    this.eventDate,
    this.targetRank,
    this.tournamentId,
  })  : assert(kind != GoalKind.thuanThucKyNang || category != null,
            'thuần thục kỹ năng cần một nhóm'),
        assert(kind != GoalKind.chuanBiGiai || eventDate != null,
            'chuẩn bị giải cần ngày giải'),
        assert(targetRank == null || kind == GoalKind.lenHang,
            'hạng đích chỉ dành cho Lên hạng');

  /// Đổi mục tiêu là ra id mới: thành tích "xong bước" gắn với id này.
  final String goalId;
  final GoalKind kind;
  final SkillCategory? category;
  final DateTime? eventDate;
  final DateTime createdAt;

  /// Hạng đích của Lên hạng; null = hạng kế tiếp (hành vi cũ).
  final Rank? targetRank;

  /// Giải đấu mà mục tiêu Chuẩn bị giải trỏ tới. Lưu nguyên văn, không assert:
  /// bản cũ có thể để sót giá trị; chỉ dùng qua `linkedTournament`.
  final String? tournamentId;

  @override
  bool operator ==(Object other) =>
      other is PlayerGoal &&
      other.goalId == goalId &&
      other.kind == kind &&
      other.category == category &&
      other.eventDate == eventDate &&
      other.createdAt == createdAt &&
      other.targetRank == targetRank &&
      other.tournamentId == tournamentId;

  @override
  int get hashCode => Object.hash(goalId, kind, category, eventDate, createdAt, targetRank, tournamentId);

  @override
  String toString() => 'PlayerGoal($goalId, $kind, $category, $eventDate, $createdAt, $targetRank, $tournamentId)';
}

/// Dòng mục tiêu của một tài khoản. [goal] null nghĩa là người chơi đã bỏ
/// mục tiêu: dòng vẫn còn, để máy khác biết "đã bỏ" là bản mới hơn (R2).
final class GoalRecord {
  const GoalRecord({required this.updatedAt, this.goal});

  final PlayerGoal? goal;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is GoalRecord && other.goal == goal && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(goal, updatedAt);

  @override
  String toString() => 'GoalRecord($goal, $updatedAt)';
}

/// Bản sửa mới nhất thắng (spec mục 6). Bằng giờ thì giữ bản máy chủ: hai máy
/// cùng chọn một bản thì mới hội tụ được.
GoalRecord? mergeGoal(GoalRecord? local, GoalRecord? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
}

/// Ngày giải phải sau hôm nay, tính theo ngày lịch (spec mục 3).
bool goalDateValid(DateTime eventDate, DateTime today) =>
    DateTime(eventDate.year, eventDate.month, eventDate.day)
        .isAfter(DateTime(today.year, today.month, today.day));

/// Hạng ngay trên. A là trần của bài BU, PRO chỉ tự khai: cả hai không có
/// hạng kế tiếp để nhắm.
Rank? nextRank(Rank rank) => switch (rank) {
      Rank.a || Rank.pro => null,
      _ => Rank.values[rank.index + 1],
    };

/// Hạng đích thật của mục tiêu Lên hạng từ hạng [from]: hạng đích đã chọn khi
/// nó còn cao hơn [from] (tối đa hạng A), không thì hạng kế tiếp. Null khi
/// [from] không có hạng kế tiếp.
Rank? effectiveTarget(PlayerGoal goal, Rank from) {
  final chosen = goal.targetRank;
  if (chosen != null && chosen.index > from.index && chosen.index <= Rank.a.index) {
    return chosen;
  }
  return nextRank(from);
}

/// Các hạng đích chọn được từ hạng [from]: hạng ngay trên tới hạng A.
List<Rank> targetRankChoices(Rank from) {
  final next = nextRank(from);
  if (next == null) return const [];
  return [for (var i = next.index; i <= Rank.a.index; i++) Rank.values[i]];
}

/// Vì sao chưa đặt được mục tiêu Lên hạng.
enum LenHangBlock { noRank, topRank }

LenHangBlock? lenHangBlock(PlayerRank? rank) {
  final r = rank?.rank;
  if (r == null) return LenHangBlock.noRank;
  return nextRank(r) == null ? LenHangBlock.topRank : null;
}
