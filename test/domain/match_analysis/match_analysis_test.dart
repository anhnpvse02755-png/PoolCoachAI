import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/match_fixtures.dart';
import '../../support/roadmap_fixtures.dart';

const p = RackWinner.player;
const o = RackWinner.opponent;
const B = MatchShotType.breakShot;
const N = MatchShotType.normal;
const S = MatchShotType.safety;
const made = MatchShotOutcome.made;
const missed = MatchShotOutcome.missed;
const foul = MatchShotOutcome.foul;
const scratch = MatchShotOutcome.scratch;
const bad = PositionOutcome.unsuccessful;
const ok = PositionOutcome.successful;

SkillSignal sig(SkillCategory c, int failures, int attempts,
        {int matches = 3}) =>
    SkillSignal(
        category: c, failures: failures, attempts: attempts, matches: matches);

/// shots, made, dry, fouls, scratches, racksBroken, breakAndRuns
List<int> breakList(BreakStats b) => [
      b.shots,
      b.made,
      b.dry,
      b.fouls,
      b.scratches,
      b.racksBroken,
      b.breakAndRuns,
    ];

int total(Map<LostRackCause, int> m) => m.values.fold(0, (x, y) => x + y);

void main() {
  group('matchWeaknesses', () {
    test('9 lần thử thì không kết luận, 10 thì có', () {
      SkillSignal s(int attempts) => SkillSignal(
          category: SkillCategory.aiming,
          failures: attempts,
          attempts: attempts,
          matches: 3);
      expect(matchWeaknesses([s(9)], minMatches: 3, minAttempts: 10), isEmpty);
      expect(
          matchWeaknesses([s(10)], minMatches: 3, minAttempts: 10)
              .single
              .category,
          SkillCategory.aiming);
    });

    test('đủ 10 lần thử nhưng chỉ 2 trận thì không kết luận', () {
      final s = sig(SkillCategory.aiming, 10, 10, matches: 2);
      expect(matchWeaknesses([s], minMatches: 3, minAttempts: 10), isEmpty);
      expect(
          matchWeaknesses([s], minMatches: 2, minAttempts: 10), hasLength(1));
    });

    test('đúng ngưỡng 35% vẫn là yếu', () {
      expect(
          matchWeaknesses([sig(SkillCategory.aiming, 7, 20)],
              minMatches: 3, minAttempts: 10),
          hasLength(1));
      expect(
          matchWeaknesses([sig(SkillCategory.aiming, 6, 20)],
              minMatches: 3, minAttempts: 10),
          isEmpty);
    });

    test('nhóm vượt ngưỡng nhiều nhất đứng đầu', () {
      // Điều bi 90% vượt 40% là +50; Tấn công 80% vượt 35% là +45.
      final r = matchWeaknesses([
        sig(SkillCategory.aiming, 8, 10),
        sig(SkillCategory.position, 9, 10),
      ], minMatches: 3, minAttempts: 10);
      expect(r.map((s) => s.category),
          [SkillCategory.position, SkillCategory.aiming]);
    });

    test('vượt ngưỡng bằng nhau thì theo thứ tự nhóm', () {
      // Tấn công 5/10 vượt +15; Điều bi 55/100 vượt +15 (đúng bằng nhau).
      final r = matchWeaknesses([
        sig(SkillCategory.position, 55, 100),
        sig(SkillCategory.aiming, 5, 10),
      ], minMatches: 3, minAttempts: 10);
      expect(r.map((s) => s.category),
          [SkillCategory.aiming, SkillCategory.position]);
    });

    test('nhóm không có ngưỡng (A băng, Cân bi) không bao giờ yếu', () {
      final r = matchWeaknesses([
        sig(SkillCategory.kick, 10, 10),
        sig(SkillCategory.bank, 10, 10),
      ], minMatches: 3, minAttempts: 10);
      expect(r, isEmpty);
    });
  });

  group('percentOf', () {
    test('null khi mẫu bằng 0, còn lại làm tròn', () {
      expect(percentOf(0, 0), isNull);
      expect(percentOf(1, 3), 33);
      expect(percentOf(2, 3), 67);
      expect(percentOf(5, 5), 100);
    });
  });

  group('recentCompletedMatches', () {
    test('chỉ trận hoàn tất, mới nhất trước, hòa ngày thì theo id, có giới hạn',
        () {
      final open = PoolMatch(
        id: 'open',
        gameType: PoolGameType.eightBall,
        playerName: 'P',
        opponentName: 'O',
        targetRacks: 3,
        rackWinners: const [p],
        startedAt: DateTime(2026, 10, 30),
      );
      final r = recentCompletedMatches([
        completedMatch('b', [p], const [], at: DateTime(2026, 10, 5)),
        open,
        completedMatch('a', [p], const [], at: DateTime(2026, 10, 5)),
        completedMatch('c', [p], const [], at: DateTime(2026, 10, 9)),
        completedMatch('d', [p], const [], at: DateTime(2026, 10, 1)),
      ], limit: 3);
      expect(r.map((m) => m.id), ['c', 'a', 'b']);
    });
  });

  group('analyzeMatches', () {
    test('đổi dữ liệu: yếu Ngắm bi rồi yếu Điều bi', () {
      expect(
          analyzeMatches(matchesWeakAt(SkillCategory.aiming,
                  at: DateTime(2026, 10, 20)))
              .weaknesses
              .first
              .category,
          SkillCategory.aiming);
      expect(
          analyzeMatches(matchesWeakAt(SkillCategory.position,
                  at: DateTime(2026, 10, 20)))
              .weaknesses
              .first
              .category,
          SkillCategory.position);
    });

    test('yếu Ngắm bi: 3 trận, 15 lần thử, 9 hỏng, chỉ một nhóm yếu', () {
      final a = analyzeMatches(
          matchesWeakAt(SkillCategory.aiming, at: DateTime(2026, 10, 20)));
      final s = a.signals[SkillCategory.aiming]!;
      expect([s.failures, s.attempts, s.matches], [9, 15, 3]);
      expect(a.weaknesses.map((w) => w.category), [SkillCategory.aiming]);
      expect(a.signals.keys.toSet(), {
        SkillCategory.breakShot,
        SkillCategory.aiming,
        SkillCategory.position,
        SkillCategory.safety,
      });
    });

    test('trận đang đánh không tính; chỉ 10 trận hoàn tất gần nhất', () {
      final matches = [
        for (var day = 1; day <= 12; day++)
          // Hai trận cũ nhất thắng 2 ván để lộ ra nếu bị tính nhầm.
          completedMatch('m$day', day <= 2 ? [p, p] : [p], const [],
              at: DateTime(2026, 10, day, 21)),
        PoolMatch(
          id: 'open',
          gameType: PoolGameType.eightBall,
          playerName: 'P',
          opponentName: 'O',
          targetRacks: 3,
          rackWinners: const [p],
          startedAt: DateTime(2026, 10, 20),
        ),
      ];
      final a = analyzeMatches(matches);
      expect(a.matches, 10);
      expect(a.racksWon, 10);
      expect(analyzeMatches(matches, limit: 3).matches, 3);
    });

    test('trận không có cú: mọi số đếm 0, không nhóm yếu, percentOf null', () {
      final a = analyzeMatches([completedMatch('m', [p, o, p], const [])]);
      expect([
        a.matches,
        a.racksWon,
        a.racksLost,
        a.racksWithShots,
        a.fullRacks,
        a.playerShots
      ], [1, 2, 1, 0, 0, 0]);
      expect(a.lostRackCauses[LostRackCause.notFull], 1);
      expect(a.lostRackCauses.length, LostRackCause.values.length);
      expect(total(a.lostRackCauses), 1);
      expect(a.weaknesses, isEmpty);
      expect(percentOf(a.missedNormal, a.normalShots), isNull);
      expect(breakList(a.playerBreak), everyElement(0));
      expect(breakList(a.opponentBreak), everyElement(0));
      expect(a.signals.values.map((s) => s.attempts), everyElement(0));
    });

    test(
        'phá: đếm của người chơi và đối thủ tách riêng; phá-và-dọn trên số ván đã phá',
        () {
      final m = completedMatch('m', [p, o, o, p, p, p], [
        // Ván 1: người chơi phá-và-dọn.
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, N, made),
        shotAt(1, 3, p, N, made),
        // Ván 2: người chơi phá khô, đối thủ thắng.
        shotAt(2, 1, p, B, missed),
        shotAt(2, 2, o, N, made),
        // Ván 3: đối thủ phá-và-dọn.
        shotAt(3, 1, o, B, made),
        shotAt(3, 2, o, N, made),
        // Ván 4: đối thủ phá chết cái, người chơi dọn bàn.
        shotAt(4, 1, o, B, scratch),
        shotAt(4, 2, p, N, made),
        // Ván 5: người chơi phá phạm lỗi, đối thủ trượt, người chơi thắng.
        shotAt(5, 1, p, B, foul),
        shotAt(5, 2, o, N, missed),
        shotAt(5, 3, p, N, made),
        // Ván 6: chỉ có cú phá của đối thủ, chưa đủ.
        shotAt(6, 1, o, B, made),
      ]);
      final a = analyzeMatches([m]);
      expect(breakList(a.playerBreak), [3, 1, 1, 1, 0, 3, 1]);
      expect(breakList(a.opponentBreak), [3, 2, 0, 0, 1, 2, 1]);
      expect([a.racksWon, a.racksLost, a.racksWithShots, a.fullRacks],
          [4, 2, 6, 5]);
      expect(a.runOuts, 2);
      expect(a.playerShots, 7);
      expect([a.fouls, a.scratches], [1, 0]);
      expect([a.normalShots, a.missedNormal], [4, 0]);
      expect(a.lostRackCauses[LostRackCause.dryBreak], 1);
      expect(a.lostRackCauses[LostRackCause.opponentBreakAndRun], 1);
      expect(total(a.lostRackCauses), 2);
      // Mất lượt: ván 2 phá khô, ván 5 phạm lỗi; không cái nào là phòng thủ.
      expect([a.safetyTurnovers, a.proactiveTurnovers], [0, 0]);
      final brk = a.signals[SkillCategory.breakShot]!;
      expect([brk.failures, brk.attempts, brk.matches], [2, 3, 1]);
    });

    test('điều bi hỏng làm trượt cú kế tiếp: đếm sau hỏng và sau tốt', () {
      final full = completedMatch('full', [p], [
        shotAt(1, 1, o, B, missed),
        shotAt(1, 2, p, N, made, position: bad),
        shotAt(1, 3, p, N, missed),
        shotAt(1, 4, o, N, missed),
        shotAt(1, 5, p, N, made, position: ok),
        shotAt(1, 6, p, N, made),
        shotAt(1, 7, p, N, made, position: bad),
        shotAt(1, 8, p, N, made),
        shotAt(1, 9, p, N, made, position: ok),
        shotAt(1, 10, p, N, missed),
        shotAt(1, 11, o, N, missed),
        shotAt(1, 12, p, N, made, position: ok),
        shotAt(1, 13, p, N, made),
      ]);
      // Ván chưa đủ: chấm điều bi vẫn tính, nhưng cú kế tiếp thì không.
      final notFull = completedMatch('notfull', [o], [
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, N, made, position: bad),
        shotAt(1, 3, p, N, missed),
      ]);
      // Ván đủ nhưng cú kế tiếp là của đối thủ: không tính.
      final opponentNext = completedMatch('opnext', [o], [
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, N, made, position: bad),
        shotAt(1, 3, o, N, made),
      ]);
      final a = analyzeMatches([full, notFull, opponentNext]);
      expect([a.assessedPositions, a.failedPositions], [7, 4]);
      expect([a.nextAfterFailedPosition, a.missAfterFailedPosition], [2, 1]);
      expect([a.nextAfterGoodPosition, a.missAfterGoodPosition], [3, 1]);
    });

    test('chết cái: một lần thử Điều bi, chỉ vào số đã chấm khi có chấm', () {
      final withPosition = completedMatch('a', [o], [
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, N, scratch, position: bad),
        shotAt(1, 3, o, N, made),
      ]);
      final without = completedMatch('b', [o], [
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, N, scratch),
        shotAt(1, 3, o, N, made),
      ]);
      final a = analyzeMatches([withPosition, without]);
      // assessed/failed chỉ đếm cú có chấm điều bi.
      expect([a.assessedPositions, a.failedPositions], [1, 1]);
      // Tín hiệu Điều bi: mỗi chết cái một lần thử hỏng, trong 2 trận.
      final pos = a.signals[SkillCategory.position]!;
      expect([pos.failures, pos.attempts, pos.matches], [2, 2, 2]);
      expect(a.scratches, 2);
      expect([a.normalShots, a.missedNormal], [0, 0]);
      expect(a.signals[SkillCategory.aiming]!.attempts, 0);
    });

    test('phòng thủ thành công và tỷ lệ trên mất lượt chủ động', () {
      final m = completedMatch('m', [p, p], [
        // Ván 1: người chơi thắng, đủ cú.
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, S, missed), // đối thủ trượt kế tiếp: thành công
        shotAt(1, 3, o, N, missed),
        shotAt(1, 4, p, S, missed), // đối thủ vào bi kế tiếp: hỏng
        shotAt(1, 5, o, N, made),
        shotAt(1, 6, p, S, missed), // đối thủ phạm lỗi kế tiếp: thành công
        shotAt(1, 7, o, N, foul),
        shotAt(1, 8, p, N, missed), // trượt tấn công: mất lượt chủ động
        shotAt(1, 9, o, N, missed),
        shotAt(1, 10, p, S, missed), // cú kế tiếp là của người chơi
        shotAt(1, 11, p, N, made),
        // Ván 2: đối thủ phá khô; đối thủ chết cái sau phòng thủ.
        shotAt(2, 1, o, B, missed),
        shotAt(2, 2, p, N, made),
        shotAt(2, 3, p, S, missed), // đối thủ chết cái kế tiếp: thành công
        shotAt(2, 4, o, N, scratch),
        shotAt(2, 5, p, N, made),
      ]);
      final a = analyzeMatches([m]);
      expect([a.safeties, a.assessedSafeties, a.successfulSafeties],
          [5, 4, 3]);
      // Mất lượt: ván 1 có 3 phòng thủ + 1 trượt, ván 2 có 1 phòng thủ.
      expect([a.safetyTurnovers, a.proactiveTurnovers], [4, 5]);
      final safety = a.signals[SkillCategory.safety]!;
      expect([safety.failures, safety.attempts], [1, 4]);
    });

    test('phòng thủ ở ván chưa đủ cú thì không vào số đã chấm', () {
      final m = completedMatch('m', [p], [
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, S, missed),
        shotAt(1, 3, o, N, missed),
      ]);
      final a = analyzeMatches([m]);
      expect([a.safeties, a.assessedSafeties, a.successfulSafeties],
          [1, 0, 0]);
      expect([a.safetyTurnovers, a.proactiveTurnovers], [0, 0]);
    });
  });

  group('singleMatchFocus', () {
    test('một trận: 5 lần thử là đủ, 4 thì không; tối đa 2 nhóm; kèm bài tập',
        () {
      final m = completedMatch('m', [p, o], [
        // Ván 1: Tấn công 3 trượt trên 8; Điều bi 4 hỏng trên 5.
        shotAt(1, 1, o, B, missed),
        shotAt(1, 2, p, N, missed),
        shotAt(1, 3, p, N, missed),
        shotAt(1, 4, p, N, missed),
        shotAt(1, 5, p, N, made, position: bad),
        shotAt(1, 6, p, N, made, position: bad),
        shotAt(1, 7, p, N, made, position: bad),
        shotAt(1, 8, p, N, made, position: bad),
        shotAt(1, 9, p, N, made, position: ok),
        // Ván 2: 4 lần phòng thủ, cả 4 đều hỏng: chưa đủ 5 lần thử.
        shotAt(2, 1, o, B, missed),
        shotAt(2, 2, p, S, missed),
        shotAt(2, 3, o, N, made),
        shotAt(2, 4, p, S, missed),
        shotAt(2, 5, o, N, made),
        shotAt(2, 6, p, S, missed),
        shotAt(2, 7, o, N, made),
        shotAt(2, 8, p, S, missed),
        shotAt(2, 9, o, N, made),
      ]);
      final analysis = analyzeMatches([m]);
      final safety = analysis.signals[SkillCategory.safety]!;
      expect([safety.failures, safety.attempts], [4, 4]);
      expect(analysis.weaknesses, isEmpty); // mới có 1 trận
      final focus =
          singleMatchFocus(analysis, drills: roadmapDrills, logs: const []);
      expect(focus.map((f) => f.signal.category),
          [SkillCategory.position, SkillCategory.aiming]);
      expect(focus.map((f) => f.drill?.id), ['p1', 'a1']);
    });

    test('xếp theo tỷ lệ hỏng chứ không theo mức vượt ngưỡng; chỉ giữ 2 nhóm',
        () {
      // Phòng thủ 5/5 = 100%; Phá 4/6 = 67% (vượt +17); Tấn công 3/5 = 60%
      // (vượt +25). Theo mức vượt: phòng thủ, Tấn công, Phá. Theo tỷ lệ:
      // phòng thủ, Phá, Tấn công. Chỉ giữ 2 nhóm đầu.
      final shots = <MatchShot>[
        shotAt(1, 1, p, B, made),
        shotAt(1, 2, p, N, missed),
        shotAt(1, 3, p, N, missed),
        shotAt(1, 4, p, N, missed),
        shotAt(1, 5, p, N, made),
        shotAt(1, 6, p, N, made),
        for (var r = 2; r <= 5; r++) shotAt(r, 1, p, B, missed),
        shotAt(6, 1, p, B, made),
        shotAt(7, 1, o, B, missed),
        for (var k = 0; k < 5; k++) ...[
          shotAt(7, 2 + 2 * k, p, S, missed),
          shotAt(7, 3 + 2 * k, o, N, made),
        ],
      ];
      final analysis = analyzeMatches(
          [completedMatch('m', [p, p, p, p, p, p, o], shots)]);
      SkillSignal at(SkillCategory c) => analysis.signals[c]!;
      expect([at(SkillCategory.safety).failures, at(SkillCategory.safety).attempts],
          [5, 5]);
      expect([at(SkillCategory.breakShot).failures, at(SkillCategory.breakShot).attempts],
          [4, 6]);
      expect([at(SkillCategory.aiming).failures, at(SkillCategory.aiming).attempts],
          [3, 5]);
      final focus =
          singleMatchFocus(analysis, drills: roadmapDrills, logs: const []);
      expect(focus.map((f) => f.signal.category),
          [SkillCategory.safety, SkillCategory.breakShot]);
      expect(focus.map((f) => f.drill?.id), ['s1', 'b1']);
    });

    test('bài tập theo nhật ký: đạt bài cấp 1 thì sang cấp 2; không có bài thì null',
        () {
      final m = completedMatch('m', [p], [
        shotAt(1, 1, o, B, missed),
        for (var n = 2; n <= 6; n++) shotAt(1, n, p, N, missed),
        shotAt(1, 7, p, N, made),
      ]);
      final analysis = analyzeMatches([m]);
      final logs = sessions('a1', 9, [on(10, 1)]); // 9/10 >= 0.8: đạt
      final withLogs =
          singleMatchFocus(analysis, drills: roadmapDrills, logs: logs);
      expect(withLogs.single.drill?.id, 'a2');
      final noDrills =
          singleMatchFocus(analysis, drills: const <Drill>[], logs: const []);
      expect(noDrills.single.drill, isNull);
      expect(noDrills.single.signal.category, SkillCategory.aiming);
    });
  });
}
