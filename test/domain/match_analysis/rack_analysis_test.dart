import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/match_fixtures.dart';

const p = RackWinner.player;
const o = RackWinner.opponent;
const B = MatchShotType.breakShot;
const N = MatchShotType.normal;
const S = MatchShotType.safety;
const made = MatchShotOutcome.made;
const missed = MatchShotOutcome.missed;
const foul = MatchShotOutcome.foul;
const scratch = MatchShotOutcome.scratch;

void main() {
  test('phá-và-dọn: người phá thắng, đối thủ không có cú nào', () {
    final r = analyzeRack(
        completedMatch('m', [p],
            [shotAt(1, 1, p, B, made), shotAt(1, 2, p, N, made), shotAt(1, 3, p, N, made)]),
        0);
    expect([r.isFull, r.breaker, r.breakAndRun, r.runOut, r.turnovers],
        [true, p, true, false, isEmpty]);
  });

  test('dọn bàn: thắng bằng một lượt sau cú cuối của đối thủ', () {
    final r = analyzeRack(
        completedMatch('m', [p], [
          shotAt(1, 1, o, B, made),
          shotAt(1, 2, o, N, missed),
          shotAt(1, 3, p, N, made),
          shotAt(1, 4, p, N, made),
        ]),
        0);
    expect([r.runOut, r.breakAndRun, r.breaker, r.lostRackCause],
        [true, false, o, null]);
  });

  test('mất lượt có nguyên nhân; thua ván lấy nguyên nhân cú cuối của người chơi', () {
    final r = analyzeRack(
        completedMatch('m', [o], [
          shotAt(1, 1, p, B, missed),
          shotAt(1, 2, o, N, missed),
          shotAt(1, 3, p, N, missed),
          shotAt(1, 4, o, N, made),
          shotAt(1, 5, o, N, made),
        ]),
        0);
    expect(r.turnovers, [TurnoverCause.dryBreak, TurnoverCause.offensiveMiss]);
    expect(r.lostRackCause, LostRackCause.offensiveMiss);
  });

  test('đối thủ phá-và-dọn', () {
    final r = analyzeRack(
        completedMatch('m', [o], [shotAt(1, 1, o, B, made), shotAt(1, 2, o, N, made)]), 0);
    expect(r.lostRackCause, LostRackCause.opponentBreakAndRun);
  });

  test('thua vì chết cái ở cú cuối của chính mình', () {
    final r = analyzeRack(
        completedMatch('m', [o], [shotAt(1, 1, p, B, made), shotAt(1, 2, p, N, scratch)]), 0);
    expect([r.isFull, r.lostRackCause, r.turnovers],
        [true, LostRackCause.scratch, isEmpty]);
  });

  test('turnoverCauseOf theo bảng', () {
    expect(turnoverCauseOf(shotAt(1, 1, p, N, foul)), TurnoverCause.foul);
    expect(turnoverCauseOf(shotAt(1, 1, p, N, scratch)), TurnoverCause.scratch);
    expect(turnoverCauseOf(shotAt(1, 1, p, B, missed)), TurnoverCause.dryBreak);
    expect(turnoverCauseOf(shotAt(1, 1, p, S, missed)), TurnoverCause.safety);
    expect(turnoverCauseOf(shotAt(1, 1, p, N, missed)), TurnoverCause.offensiveMiss);
    expect(turnoverCauseOf(shotAt(1, 1, p, N, made)), TurnoverCause.unknown);
  });

  // Review Focus 1
  test('chỉ ghi cú phá rồi bấm thắng ván: có ghi cú, không ghi đủ, không kết luận', () {
    final r = analyzeRack(completedMatch('m', [p], [shotAt(1, 1, p, B, made)]), 0);
    expect([r.hasShots, r.isFull, r.breakAndRun, r.runOut],
        [true, false, false, false]);
  });

  test('ngừng ghi sau một cú trượt: không ghi đủ, thua ván là notFull', () {
    final r = analyzeRack(
        completedMatch('m', [o], [shotAt(1, 1, p, B, made), shotAt(1, 2, p, N, missed)]), 0);
    expect([r.isFull, r.lostRackCause, r.turnovers],
        [false, LostRackCause.notFull, isEmpty]);
  });

  test('ván ghi đủ mà cú cuối của người chơi là cú vào bi: thua ván là unclear', () {
    final r = analyzeRack(
        completedMatch('m', [o], [
          shotAt(1, 1, p, B, made),
          shotAt(1, 2, p, N, made),
          shotAt(1, 3, o, N, foul),
        ]),
        0);
    // Cú cuối là lỗi của đối thủ (người thắng ván) nên ván không đủ.
    expect(r.isFull, isFalse);

    final full = analyzeRack(
        completedMatch('m', [o], [
          shotAt(1, 1, p, B, made),
          shotAt(1, 2, p, N, made),
          shotAt(1, 3, p, N, foul),
          shotAt(1, 4, o, N, made),
        ]),
        0);
    expect(full.isFull, isTrue);
    expect(full.lostRackCause, LostRackCause.foul);

    final unclear = analyzeRack(
        completedMatch('m', [o], [
          shotAt(1, 1, p, B, made),
          shotAt(1, 2, p, N, made),
          shotAt(1, 3, o, N, made),
        ]),
        0);
    expect([unclear.isFull, unclear.lostRackCause, unclear.turnovers],
        [true, LostRackCause.unclear, [TurnoverCause.unknown]]);
  });

  test('thiếu số cú giữa ván thì không ghi đủ', () {
    final r = analyzeRack(
        completedMatch('m', [p], [shotAt(1, 1, p, B, made), shotAt(1, 3, p, N, made)]), 0);
    expect(r.isFull, isFalse);
  });

  test('ván không có cú: không có người phá, thua là notFull', () {
    final r = analyzeRack(completedMatch('m', [o], const []), 0);
    expect([r.hasShots, r.breaker, r.lostRackCause],
        [false, null, LostRackCause.notFull]);
  });

  test('analyzeRack chỉ lấy cú của đúng ván và xếp theo shotNumber', () {
    final r = analyzeRack(
        completedMatch('m', [p, p], [
          shotAt(2, 1, p, B, made),
          shotAt(1, 2, p, N, made),
          shotAt(1, 1, p, B, made),
        ]),
        0);
    expect(r.rackNumber, 1);
    expect(r.shots.map((s) => s.shotNumber), [1, 2]);
    expect(r.isFull, isTrue);
  });

  test('matchesWeakAt: số trận, ngày lùi dần, nhóm không hỗ trợ ném lỗi', () {
    final at = DateTime(2026, 10, 20, 9);
    final ms = matchesWeakAt(SkillCategory.aiming, at: at);
    expect(ms.map((m) => m.completedAt), [
      at,
      at.subtract(const Duration(days: 1)),
      at.subtract(const Duration(days: 2)),
    ]);
    expect(analyzeRack(ms.first, 0).isFull, isTrue);
    expect(matchesWeakAt(SkillCategory.position, count: 4, at: at), hasLength(4));
    expect(() => matchesWeakAt(SkillCategory.safety, at: at), throwsArgumentError);
  });
}
