import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Ba loại mục tiêu của Lộ trình (spec 2026-10-15 mục 3).
enum GoalKind { lenHang, thuanThucKyNang, chuanBiGiai }

/// Mục tiêu đang chạy của một tài khoản.
///
/// Lên hạng không lưu hạng đích: đích luôn là hạng ngay trên hạng hiện tại,
/// nên lên được hạng thì đích tự chuyển (spec mục 3).
final class PlayerGoal {
  const PlayerGoal({
    required this.goalId,
    required this.kind,
    required this.createdAt,
    this.category,
    this.eventDate,
  })  : assert(kind != GoalKind.thuanThucKyNang || category != null,
            'thuần thục kỹ năng cần một nhóm'),
        assert(kind != GoalKind.chuanBiGiai || eventDate != null,
            'chuẩn bị giải cần ngày giải');

  /// Đổi mục tiêu là ra id mới: thành tích "xong bước" gắn với id này.
  final String goalId;
  final GoalKind kind;
  final SkillCategory? category;
  final DateTime? eventDate;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is PlayerGoal &&
      other.goalId == goalId &&
      other.kind == kind &&
      other.category == category &&
      other.eventDate == eventDate &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(goalId, kind, category, eventDate, createdAt);

  @override
  String toString() => 'PlayerGoal($goalId, $kind, $category, $eventDate, $createdAt)';
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

/// Vì sao chưa đặt được mục tiêu Lên hạng.
enum LenHangBlock { noRank, topRank }

LenHangBlock? lenHangBlock(PlayerRank? rank) {
  final r = rank?.rank;
  if (r == null) return LenHangBlock.noRank;
  return nextRank(r) == null ? LenHangBlock.topRank : null;
}
