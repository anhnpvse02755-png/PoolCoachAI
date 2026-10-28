import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament_results.dart';

import '../../support/tournament_fixtures.dart';

void main() {
  test('tổng kết chỉ tính trận hoàn tất và ván của chúng', () {
    final s = summarizeMatches([
      tMatch('w', won: 3, lost: 1),
      tMatch('l', won: 2, lost: 3),
      tMatch('live', won: 1, lost: 0, target: 3),
    ]);
    expect(
      [
        s.matchesWon,
        s.matchesLost,
        s.racksWon,
        s.racksLost,
        s.completedMatches,
        s.rackWinPercent,
      ],
      [1, 1, 5, 4, 2, 56],
    );
    expect(summarizeMatches(const []), TournamentSummary.empty);
    expect(TournamentSummary.empty.rackWinPercent, isNull);
  });
  test('trận của một giải, theo giờ bắt đầu', () {
    final ms = [
      tMatch('b', tournamentId: 't1', at: tDay(0)),
      tMatch('a', tournamentId: 't1', at: tDay(-1)),
      tMatch('x', tournamentId: 't2'),
    ];
    expect(matchesOfTournament('t1', ms).map((m) => m.id), ['a', 'b']);
  });
  test('giải đã xóa thì trận hiện như trận thường', () {
    final live = {'t1': tour('t1', start: tDay(-1))};
    expect(tournamentOf(tMatch('a', tournamentId: 't1'), live)!.id, 't1');
    expect(tournamentOf(tMatch('b', tournamentId: 'gone'), live), isNull);
    expect(tournamentOf(tMatch('c'), live), isNull);
  });
  group('so sánh giải với trận thường — ngưỡng 3 trận mỗi bên', () {
    final live = [tour('t1', start: tDay(-3))];
    List<PoolMatch> inT(int n) => [
      for (var i = 0; i < n; i++)
        tMatch('t$i', tournamentId: 't1', won: 3, lost: 0),
    ];
    List<PoolMatch> regular(int n) => [
      for (var i = 0; i < n; i++) tMatch('r$i', won: 1, lost: 3),
    ];
    test('đủ mỗi bên: hai tỷ lệ ván thắng; trận của giải đã xóa tính là trận thường, trận dở không tính', () {
      final c = compareTournamentPlay([
        ...inT(3),
        ...regular(2),
        tMatch('g', tournamentId: 'gone', won: 1, lost: 3),
        tMatch('live', tournamentId: 't1', won: 0, lost: 2, target: 3),
      ], live);
      expect(
        [
          c.enough,
          c.inTournaments.completedMatches,
          c.inTournaments.rackWinPercent,
          c.regular.completedMatches,
          c.regular.rackWinPercent,
        ],
        [true, 3, 100, 3, 25],
      );
    });
    test('một bên chỉ có 2 trận: chưa đủ', () {
      expect(
        compareTournamentPlay([...inT(3), ...regular(2)], live).enough,
        isFalse,
      );
      expect(
        compareTournamentPlay([...inT(2), ...regular(3)], live).enough,
        isFalse,
      );
    });
  });
  test(
    'tournamentView: null khi giải không còn; trận theo thứ tự; tổng kết khớp',
    () {
      final live = [tour('t1', start: tDay(-1))];
      final v = tournamentView('t1', live, [
        tMatch('a', tournamentId: 't1'),
        tMatch('b'),
      ])!;
      expect(
        [
          v.tournament.id,
          v.matches.map((m) => m.id).toList(),
          v.summary.matchesWon,
        ],
        [
          't1',
          ['a'],
          1,
        ],
      );
      expect(tournamentView('gone', live, const []), isNull);
      expect(summariesByTournament(live, const []), {
        't1': TournamentSummary.empty,
      });
    },
  );
  test('playerWon cần trận hoàn tất và đạt đích', () {
    expect(playerWon(tMatch('a', won: 3, lost: 1)), isTrue);
    expect(playerWon(tMatch('b', won: 2, lost: 3)), isFalse);
    expect(playerWon(tMatch('c', won: 2, lost: 0, target: 3)), isFalse);
  });
}
