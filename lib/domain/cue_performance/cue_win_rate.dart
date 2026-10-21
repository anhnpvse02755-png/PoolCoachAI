import 'package:poolcoachai/domain/pool_match.dart';

/// Số trận hoàn tất tối thiểu của một cây cơ trước khi tỉ lệ thắng của nó
/// được đem so với cơ khác.
const minMatchesForCueVerdict = 10;

/// Kết quả các trận hoàn tất đánh bằng một cây cơ.
class CueMatchStats {
  const CueMatchStats({
    required this.cueId,
    required this.completedMatches,
    required this.wins,
  });

  final String cueId;
  final int completedMatches;
  final int wins;

  /// `wins / completedMatches`; null khi chưa có trận hoàn tất nào.
  double? get winRate => completedMatches == 0 ? null : wins / completedMatches;

  bool get isQualified => completedMatches >= minMatchesForCueVerdict;

  /// Số trận hoàn tất còn thiếu để đủ điều kiện so sánh; 0 khi đã đủ.
  int get matchesNeeded => isQualified
      ? 0
      : minMatchesForCueVerdict - completedMatches;
}

class CueWinRateReport {
  const CueWinRateReport({
    required this.byCue,
    required this.unknownCues,
    required this.bestCueId,
  });

  /// Cơ còn trong hồ sơ, kể cả cơ chưa có trận nào.
  final Map<String, CueMatchStats> byCue;

  /// Cơ đã xóa nhưng vẫn còn trận ghi cơ đó. Chỉ để xem số liệu.
  final List<CueMatchStats> unknownCues;

  /// Cơ "hợp bạn nhất", hoặc null khi chưa đủ căn cứ.
  final String? bestCueId;

  CueMatchStats statsFor(String cueId) =>
      byCue[cueId] ??
      CueMatchStats(cueId: cueId, completedMatches: 0, wins: 0);
}

/// Tỉ lệ thắng theo từng cây cơ từ các trận **hoàn tất**.
///
/// Trận không ghi cơ không tính cho cơ nào. Cơ đã xóa ([knownCueIds] không
/// có) vẫn có số liệu trong [CueWinRateReport.unknownCues] nhưng không tham
/// gia kết luận, vì người chơi không còn chọn nó được nữa.
///
/// Kết luận [CueWinRateReport.bestCueId] chỉ có khi **ít nhất hai** cơ đủ
/// [minMatchesForCueVerdict] trận hoàn tất và một cơ trong số đó có tỉ lệ
/// thắng cao hơn hẳn mọi cơ đủ trận còn lại. Hòa ở đầu bảng thì không kết
/// luận. Chỉ một cơ đủ trận thì không có gì để so sánh nên cũng không.
CueWinRateReport computeCueWinRates({
  required List<PoolMatch> matches,
  required Set<String> knownCueIds,
}) {
  final completed = <String, int>{};
  final wins = <String, int>{};
  for (final match in matches) {
    final cueId = match.cueId;
    if (cueId == null || !match.isComplete) continue;
    completed[cueId] = (completed[cueId] ?? 0) + 1;
    if (match.playerScore > match.opponentScore) {
      wins[cueId] = (wins[cueId] ?? 0) + 1;
    }
  }

  CueMatchStats statsOf(String id) => CueMatchStats(
    cueId: id,
    completedMatches: completed[id] ?? 0,
    wins: wins[id] ?? 0,
  );

  final byCue = {for (final id in knownCueIds) id: statsOf(id)};
  final unknown =
      [
        for (final id in completed.keys)
          if (!knownCueIds.contains(id)) statsOf(id),
      ]..sort((a, b) => a.cueId.compareTo(b.cueId));

  final qualified = byCue.values.where((stats) => stats.isQualified).toList();
  String? best;
  if (qualified.length >= 2) {
    qualified.sort((a, b) => b.winRate!.compareTo(a.winRate!));
    if (qualified[0].winRate! > qualified[1].winRate!) {
      best = qualified[0].cueId;
    }
  }

  return CueWinRateReport(
    byCue: byCue,
    unknownCues: unknown,
    bestCueId: best,
  );
}

/// Cơ được chọn sẵn khi bắt đầu trận mới: cơ của trận gần nhất, nếu trận
/// đó có ghi cơ và cơ đó còn trong hồ sơ. Ngược lại là không chọn cơ nào.
String? defaultMatchCueId({
  required List<PoolMatch> matches,
  required Set<String> knownCueIds,
}) {
  if (matches.isEmpty) return null;
  final latest = matches.reduce(
    (a, b) => b.startedAt.isAfter(a.startedAt) ? b : a,
  );
  final cueId = latest.cueId;
  return cueId != null && knownCueIds.contains(cueId) ? cueId : null;
}
