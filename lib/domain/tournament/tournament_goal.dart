import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

/// Giải mà [goal] trỏ tới, chỉ khi đủ ba điều kiện: mục tiêu là Chuẩn bị giải,
/// giải còn sống, và ngày giải của mục tiêu trùng ngày bắt đầu của giải. Mọi
/// nơi dùng liên kết đều đi qua hàm này.
Tournament? linkedTournament(PlayerGoal? goal, Iterable<Tournament> live) {
  if (goal == null || goal.kind != GoalKind.chuanBiGiai) return null;
  final id = goal.tournamentId;
  final eventDate = goal.eventDate;
  if (id == null || eventDate == null) return null;
  for (final t in live) {
    if (t.id == id) {
      return dateOnly(t.startDate) == dateOnly(eventDate) ? t : null;
    }
  }
  return null;
}

/// [linkOnly]: mục tiêu hiện tại đã là Chuẩn bị giải đúng ngày giải này nhưng
/// chưa nối; chỉ cần gắn mã giải, không hỏi và không đặt lại mục tiêu.
enum TournamentGoalState { notUpcoming, linked, linkOnly, otherGoal, noGoal }

/// Trạng thái nút "Chuẩn bị cho giải này" của [t].
TournamentGoalState tournamentGoalState(
  Tournament t, {
  required PlayerGoal? goal,
  required Iterable<Tournament> live,
  required DateTime today,
}) {
  if (tournamentStatus(t, today) != TournamentStatus.sapToi) {
    return TournamentGoalState.notUpcoming;
  }
  if (linkedTournament(goal, live)?.id == t.id) {
    return TournamentGoalState.linked;
  }
  if (goal == null) return TournamentGoalState.noGoal;
  final eventDate = goal.eventDate;
  if (goal.kind == GoalKind.chuanBiGiai &&
      linkedTournament(goal, live) == null &&
      eventDate != null &&
      dateOnly(eventDate) == dateOnly(t.startDate)) {
    return TournamentGoalState.linkOnly;
  }
  return TournamentGoalState.otherGoal;
}
