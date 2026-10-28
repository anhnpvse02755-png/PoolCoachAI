import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

typedef TournamentGroups = ({
  List<Tournament> dangDienRa,
  List<Tournament> sapToi,
  List<Tournament> daXong,
});

int _byId(Tournament a, Tournament b) => a.id.compareTo(b.id);

int _startAsc(Tournament a, Tournament b) {
  final c = dateOnly(a.startDate).compareTo(dateOnly(b.startDate));
  return c != 0 ? c : _byId(a, b);
}

int _startDesc(Tournament a, Tournament b) {
  final c = dateOnly(b.startDate).compareTo(dateOnly(a.startDate));
  return c != 0 ? c : _byId(a, b);
}

int _finishedOrder(Tournament a, Tournament b) {
  final c = dateOnly(b.lastDay).compareTo(dateOnly(a.lastDay));
  return c != 0 ? c : _startDesc(a, b);
}

/// Chia giải thành ba nhóm: đang diễn ra và sắp tới theo ngày bắt đầu tăng
/// dần; đã xong theo ngày cuối giảm dần.
TournamentGroups groupTournaments(Iterable<Tournament> ts, DateTime today) {
  final on = <Tournament>[];
  final up = <Tournament>[];
  final done = <Tournament>[];
  for (final t in ts) {
    switch (tournamentStatus(t, today)) {
      case TournamentStatus.dangDienRa:
        on.add(t);
      case TournamentStatus.sapToi:
        up.add(t);
      case TournamentStatus.daXong:
        done.add(t);
    }
  }
  return (
    dangDienRa: on..sort(_startAsc),
    sapToi: up..sort(_startAsc),
    daXong: done..sort(_finishedOrder),
  );
}

/// Giải nổi bật: giải đang diễn ra đầu tiên, không thì giải sắp tới đầu tiên.
Tournament? featuredTournament(Iterable<Tournament> ts, DateTime today) {
  final g = groupTournaments(ts, today);
  if (g.dangDienRa.isNotEmpty) return g.dangDienRa.first;
  if (g.sapToi.isNotEmpty) return g.sapToi.first;
  return null;
}

/// Giải được chọn khi bắt đầu trận mới: đã bắt đầu và ngày cuối chưa quá
/// [TournamentConstants.recentDays] ngày, cộng thêm giải [include] nếu có.
List<Tournament> pickableForNewMatch(
  Iterable<Tournament> ts,
  DateTime today, {
  String? include,
}) {
  final day = dateOnly(today);
  final oldest = DateTime(
    day.year,
    day.month,
    day.day - TournamentConstants.recentDays,
  );
  final picked = ts.where((t) {
    if (t.id == include) return true;
    return !dateOnly(t.startDate).isAfter(day) &&
        !dateOnly(t.lastDay).isBefore(oldest);
  }).toList();
  return picked..sort(_startDesc);
}

/// Giải được chọn khi sửa trận: tất cả, mới bắt đầu nhất trước.
List<Tournament> pickableForEdit(Iterable<Tournament> ts) =>
    ts.toList()..sort(_startDesc);
