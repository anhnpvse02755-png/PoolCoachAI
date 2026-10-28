import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis_constants.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

/// Người chơi thắng trận: trận đã hoàn tất và điểm đạt đích.
bool playerWon(PoolMatch m) => m.isComplete && m.playerScore >= m.targetRacks;

/// Tổng kết các trận hoàn tất: số trận và số ván thắng, thua.
final class TournamentSummary {
  const TournamentSummary({
    required this.matchesWon,
    required this.matchesLost,
    required this.racksWon,
    required this.racksLost,
  });

  static const empty = TournamentSummary(
    matchesWon: 0,
    matchesLost: 0,
    racksWon: 0,
    racksLost: 0,
  );

  final int matchesWon;
  final int matchesLost;
  final int racksWon;
  final int racksLost;

  int get completedMatches => matchesWon + matchesLost;

  /// Tỉ lệ ván thắng làm tròn; null khi chưa có ván nào.
  int? get rackWinPercent => percentOf(racksWon, racksWon + racksLost);

  @override
  bool operator ==(Object other) =>
      other is TournamentSummary &&
      other.matchesWon == matchesWon &&
      other.matchesLost == matchesLost &&
      other.racksWon == racksWon &&
      other.racksLost == racksLost;

  @override
  int get hashCode => Object.hash(matchesWon, matchesLost, racksWon, racksLost);

  @override
  String toString() =>
      'TournamentSummary(matchesWon: $matchesWon, matchesLost: $matchesLost, '
      'racksWon: $racksWon, racksLost: $racksLost)';
}

/// Chỉ tính trận hoàn tất và ván của chúng.
TournamentSummary summarizeMatches(Iterable<PoolMatch> matches) {
  var won = 0, lost = 0, racksWon = 0, racksLost = 0;
  for (final m in matches) {
    if (!m.isComplete) continue;
    if (playerWon(m)) {
      won++;
    } else {
      lost++;
    }
    racksWon += m.playerScore;
    racksLost += m.opponentScore;
  }
  return TournamentSummary(
    matchesWon: won,
    matchesLost: lost,
    racksWon: racksWon,
    racksLost: racksLost,
  );
}

/// Trận của giải [tournamentId], theo giờ bắt đầu tăng dần rồi theo id.
List<PoolMatch> matchesOfTournament(
  String tournamentId,
  Iterable<PoolMatch> matches,
) =>
    matches.where((m) => m.tournamentId == tournamentId).toList()..sort((a, b) {
      final c = a.startedAt.compareTo(b.startedAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

/// Giải còn sống của trận; null khi trận thường hoặc giải đã bị xóa.
Tournament? tournamentOf(PoolMatch m, Map<String, Tournament> liveById) {
  final id = m.tournamentId;
  return id == null ? null : liveById[id];
}

/// Mỗi giải còn sống một tổng kết ([TournamentSummary.empty] khi chưa có trận).
Map<String, TournamentSummary> summariesByTournament(
  Iterable<Tournament> live,
  Iterable<PoolMatch> matches,
) {
  final byId = <String, List<PoolMatch>>{};
  for (final m in matches) {
    final id = m.tournamentId;
    if (id != null) (byId[id] ??= []).add(m);
  }
  return {for (final t in live) t.id: summarizeMatches(byId[t.id] ?? const [])};
}

/// So sánh chơi ở giải với chơi thường.
final class TournamentComparison {
  const TournamentComparison({
    required this.inTournaments,
    required this.regular,
  });

  final TournamentSummary inTournaments;
  final TournamentSummary regular;

  /// Mỗi bên đủ [MatchAnalysisConstants.minMatches] trận hoàn tất.
  bool get enough => _enough(inTournaments) && _enough(regular);

  static bool _enough(TournamentSummary s) =>
      s.completedMatches >= MatchAnalysisConstants.minMatches &&
      s.rackWinPercent != null;
}

/// Trận thuộc giải đã xóa tính là trận thường.
TournamentComparison compareTournamentPlay(
  Iterable<PoolMatch> matches,
  Iterable<Tournament> live,
) {
  final liveById = {for (final t in live) t.id: t};
  final inT = <PoolMatch>[];
  final regular = <PoolMatch>[];
  for (final m in matches) {
    (tournamentOf(m, liveById) != null ? inT : regular).add(m);
  }
  return TournamentComparison(
    inTournaments: summarizeMatches(inT),
    regular: summarizeMatches(regular),
  );
}

typedef TournamentView = ({
  Tournament tournament,
  List<PoolMatch> matches,
  TournamentSummary summary,
});

/// Giải [id] cùng trận và tổng kết; null khi giải không còn.
TournamentView? tournamentView(
  String id,
  Iterable<Tournament> live,
  Iterable<PoolMatch> matches,
) {
  for (final t in live) {
    if (t.id == id) {
      final ms = matchesOfTournament(id, matches);
      return (tournament: t, matches: ms, summary: summarizeMatches(ms));
    }
  }
  return null;
}
