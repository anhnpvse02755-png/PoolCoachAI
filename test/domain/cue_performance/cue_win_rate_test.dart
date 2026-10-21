import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/cue_performance/cue_win_rate.dart';
import 'package:poolcoachai/domain/pool_match.dart';

int _n = 0;

/// Trận đua tới 5; [win] quyết định ai thắng khi [complete].
PoolMatch _match({
  String? cueId,
  bool win = true,
  bool complete = true,
  DateTime? startedAt,
}) {
  _n++;
  final winners = complete
      ? [
          for (var i = 0; i < 5; i++)
            win ? RackWinner.player : RackWinner.opponent,
        ]
      : [RackWinner.player];
  return PoolMatch(
    id: 'm$_n',
    gameType: PoolGameType.nineBall,
    playerName: 'An',
    opponentName: 'Bình',
    targetRacks: 5,
    rackWinners: winners,
    startedAt: startedAt ?? DateTime(2026, 10, 1).add(Duration(hours: _n)),
    cueId: cueId,
  );
}

List<PoolMatch> _many(String cue, {required int wins, required int losses}) => [
  for (var i = 0; i < wins; i++) _match(cueId: cue),
  for (var i = 0; i < losses; i++) _match(cueId: cue, win: false),
];

void main() {
  group('computeCueWinRates', () {
    test('counts only completed matches and wins per cue', () {
      final report = computeCueWinRates(
        matches: [
          _match(cueId: 'a'),
          _match(cueId: 'a', win: false),
          _match(cueId: 'a', complete: false),
          _match(cueId: 'b'),
        ],
        knownCueIds: {'a', 'b'},
      );

      final a = report.statsFor('a');
      expect(a.completedMatches, 2);
      expect(a.wins, 1);
      expect(a.winRate, 0.5);
      expect(report.statsFor('b').winRate, 1.0);
    });

    test('a cue with no matches has zero stats and a null win rate', () {
      final report = computeCueWinRates(matches: const [], knownCueIds: {'a'});

      final a = report.statsFor('a');
      expect(a.completedMatches, 0);
      expect(a.winRate, isNull);
      expect(a.matchesNeeded, 10);
      expect(report.bestCueId, isNull);
    });

    test('matches without a cue are ignored', () {
      final report = computeCueWinRates(
        matches: [_match(), _match(), ..._many('a', wins: 10, losses: 0)],
        knownCueIds: {'a', 'b'},
      );

      expect(report.statsFor('a').completedMatches, 10);
      expect(report.unknownCues, isEmpty);
    });

    test('no verdict below ten completed matches, with matches still needed', () {
      final report = computeCueWinRates(
        matches: [
          ..._many('a', wins: 6, losses: 3),
          ..._many('b', wins: 1, losses: 8),
        ],
        knownCueIds: {'a', 'b'},
      );

      expect(report.bestCueId, isNull);
      expect(report.statsFor('a').matchesNeeded, 1);
      expect(report.statsFor('b').matchesNeeded, 1);
      expect(report.statsFor('a').isQualified, isFalse);
    });

    test('verdict goes to the strictly higher cue when two qualify', () {
      final report = computeCueWinRates(
        matches: [
          ..._many('a', wins: 7, losses: 3),
          ..._many('b', wins: 6, losses: 4),
        ],
        knownCueIds: {'a', 'b'},
      );

      expect(report.bestCueId, 'a');
      expect(report.statsFor('a').matchesNeeded, 0);
    });

    test('a tie at the top gives no verdict', () {
      final report = computeCueWinRates(
        matches: [
          ..._many('a', wins: 6, losses: 4),
          ..._many('b', wins: 12, losses: 8),
          ..._many('c', wins: 2, losses: 8),
        ],
        knownCueIds: {'a', 'b', 'c'},
      );

      expect(report.bestCueId, isNull);
    });

    test('a cue under ten matches does not count as a rival or a winner', () {
      final report = computeCueWinRates(
        matches: [
          ..._many('a', wins: 6, losses: 4),
          ..._many('b', wins: 5, losses: 0),
        ],
        knownCueIds: {'a', 'b'},
      );

      // Chỉ một cơ đủ 10 trận: chưa có gì để so sánh.
      expect(report.bestCueId, isNull);
    });

    test('a single qualified cue has nothing to be compared with', () {
      final report = computeCueWinRates(
        matches: _many('a', wins: 10, losses: 0),
        knownCueIds: {'a'},
      );

      expect(report.bestCueId, isNull);
    });

    test('a deleted cue keeps its numbers but never takes part in the verdict', () {
      final report = computeCueWinRates(
        matches: [
          ..._many('gone', wins: 10, losses: 0),
          ..._many('a', wins: 6, losses: 4),
          ..._many('b', wins: 5, losses: 5),
        ],
        knownCueIds: {'a', 'b'},
      );

      expect(report.unknownCues.single.cueId, 'gone');
      expect(report.unknownCues.single.winRate, 1.0);
      expect(report.bestCueId, 'a');
    });

    test('exactly ten completed matches qualifies', () {
      final report = computeCueWinRates(
        matches: [
          ..._many('a', wins: 5, losses: 5),
          ..._many('b', wins: 4, losses: 6),
        ],
        knownCueIds: {'a', 'b'},
      );

      expect(report.bestCueId, 'a');
    });
  });

  group('defaultMatchCueId', () {
    test('is the cue of the most recent match', () {
      final id = defaultMatchCueId(
        matches: [
          _match(cueId: 'old', startedAt: DateTime(2026, 9, 1)),
          _match(cueId: 'new', startedAt: DateTime(2026, 10, 5)),
        ],
        knownCueIds: {'old', 'new'},
      );

      expect(id, 'new');
    });

    test('is null when the most recent match used no cue', () {
      final id = defaultMatchCueId(
        matches: [
          _match(cueId: 'old', startedAt: DateTime(2026, 9, 1)),
          _match(startedAt: DateTime(2026, 10, 5)),
        ],
        knownCueIds: {'old'},
      );

      expect(id, isNull);
    });

    test('is null when that cue was deleted, and with no matches', () {
      expect(
        defaultMatchCueId(matches: [_match(cueId: 'gone')], knownCueIds: {'a'}),
        isNull,
      );
      expect(defaultMatchCueId(matches: const [], knownCueIds: {'a'}), isNull);
    });
  });
}
