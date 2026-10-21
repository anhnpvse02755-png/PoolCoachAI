import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/hints.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';

/// Chấm [answer] trên [setup] và trả cả hai gợi ý.
({CoachVerdict v, HintOne? one, HintTwoData? two}) hintsFor(TableSetup setup, CoachAnswer answer,
    {CoachJob? job}) {
  final j = job ?? gradeAll(setup, [answer]);
  final v = j.verdicts.last;
  return (v: v, one: hintOne(v, j.reference!), two: hintTwo(v, j.reference!));
}

void main() {
  final rail = railTable();

  group('gợi ý 1 (spec mục 7.1): mỗi dòng có một bàn thật', () {
    test('đường bị chắn', () {
      final t = typicalNineBallTable();
      final h = hintsFor(t, pot(t, Pocket.bottomMiddle, Stroke.stun, 45));
      expect(h.one, isA<HintPathBlocked>().having((x) => x.pocket, 'pocket', Pocket.bottomMiddle));
      expect(h.two!.hint, isA<Hint2Pocket>());
    });

    test('quá mỏng', () {
      final c = cornerFollowTable();
      expect(hintsFor(c, pot(c, Pocket.topLeft, Stroke.stun, 45)).one, isA<HintTooThin>());
    });

    test('bi ảo ngoài bàn', () {
      const s = TableSetup(
        game: GameType.nineBall,
        cue: Vec2(100, 60),
        balls: [PlacedBall(number: 1, pos: Vec2(100, 3)), PlacedBall(number: 2, pos: Vec2(200, 90))],
      );
      expect(hintsFor(s, pot(s, Pocket.bottomMiddle, Stroke.stun, 45)).one, isA<HintGhostOff>());
    });

    test('chết cái: đúng lỗ; gợi ý 2 nói thông số của cú gần nhất cùng lỗ, kèm vùng điều', () {
      final c = cornerFollowTable();
      final h = hintsFor(c, pot(c, Pocket.bottomRight, Stroke.follow, 45));
      expect(h.one, isA<HintScratch>().having((x) => x.pocket, 'pocket', Pocket.bottomRight));
      expect(h.two!.hint, isA<Hint2Stroke>());
      expect(h.two!.zoneNext, 2);
    });

    test('bi không vào lỗ', () {
      final job = gradeAll(rail, [pot(rail, Pocket.bottomMiddle, Stroke.draw, 60)],
          aim: missingAim((_, stroke, _, power) => stroke == Stroke.draw && power == 60));
      final h = hintsFor(rail, const SafetyAnswer(), job: job);
      expect(h.one, isA<HintMissed>().having((x) => x.ball, 'ball', 1));
    });

    test('bi chắn: đúng số bi', () {
      final h = hintsFor(rail, pot(rail, Pocket.bottomLeft, Stroke.follow, 30));
      expect(h.one, isA<HintBlocker>().having((x) => x.blocker, 'blocker', 2));
    });

    test('không còn cú sau', () {
      final f = fallbackTable();
      final h = hintsFor(f, pot(f, Pocket.bottomLeft, Stroke.stun, 45));
      expect(h.v.fault, CoachFault.noNextShot);
      expect(h.one, isA<HintNoNext>().having((x) => x.next, 'next', 2));
    });

    test('nên ăn: Phòng thủ khi có cú ăn vị trí tốt', () {
      final h = hintsFor(rail, const SafetyAnswer());
      expect(h.one, isA<HintShouldPot>());
      expect(h.two!.hint, isA<Hint2Pot>());
    });

    test('vùng vị trí kém hơn cú gần nhất → hỏi vị trí; cùng vùng → đơn giản hơn', () {
      // Cu lê 30 % dừng ở vùng tạm được, cú gần nhất (đứng bi 45 %) ở vùng tốt.
      final worse = hintsFor(rail, pot(rail, Pocket.bottomMiddle, Stroke.follow, 30));
      expect(worse.v.fault, CoachFault.strokeWorse);
      expect(worse.one, isA<HintPosition>().having((x) => x.next, 'next', 2));
      // Đứng bi 75 % vẫn vùng tốt: chỉ là lực mạnh hơn cần thiết.
      final same = hintsFor(rail, pot(rail, Pocket.bottomMiddle, Stroke.stun, 75));
      expect(same.v.fault, CoachFault.powerWorse);
      expect(same.one, isA<HintSimpler>());
    });

    test('áp phê thừa → đơn giản hơn; gợi ý 2 bỏ áp phê', () {
      final h = hintsFor(rail,
          pot(rail, Pocket.bottomMiddle, Stroke.stun, 45, spin: const SideSpin(SpinSide.left, 0.5)));
      expect(h.v.fault, CoachFault.spinUnneeded);
      expect(h.one, isA<HintSimpler>());
      expect(h.two!.hint, isA<Hint2NoSpin>());
    });

    test('nên thủ: dùng dòng của lỗi hỏng cụ thể', () {
      final n = noPotTable();
      final h = hintsFor(n, pot(n, Pocket.topRight, Stroke.stun, 45));
      expect(h.v.fault, CoachFault.shouldSafety);
      expect(h.one, isA<HintPathBlocked>());
      expect(h.two!.hint, isA<Hint2Safety>());
    });
  });

  group('gợi ý 2 (spec mục 7.2)', () {
    test('lỗ khác điểm kém → thử lỗ khác', () {
      final h = hintsFor(rail, pot(rail, Pocket.bottomLeft, Stroke.stun, 75));
      expect(h.v.fault, CoachFault.pocketWorse);
      expect(h.two!.hint, isA<Hint2Pocket>());
      expect(h.two!.zoneNext, isNull);
    });

    test('lực: nhẹ hơn / mạnh hơn theo hướng của cú gần nhất', () {
      expect(hintsFor(rail, pot(rail, Pocket.bottomMiddle, Stroke.stun, 75)).two!.hint,
          isA<Hint2PowerLess>());
      final more = hintsFor(rail, pot(rail, Pocket.bottomMiddle, Stroke.stun, 30));
      expect(more.v.fault, CoachFault.powerWorse);
      expect(more.two!.hint, isA<Hint2PowerMore>());
      expect(more.two!.zoneNext, 2);
    });

    test('tầng áp phê: không áp phê thì gợi ý thử áp phê', () {
      final ball1 = rail.balls.first.pos;
      final job = gradeAll(rail, [pot(rail, Pocket.bottomMiddle, Stroke.stun, 45)],
          aim: scratchingAim((object, _, spin, _) => object == ball1 && spin.isNone));
      expect(job.reference!.tier, 2);
      final h = hintsFor(rail, const SafetyAnswer(), job: job);
      expect(h.v.fault, CoachFault.scratch);
      expect(h.two!.hint, isA<Hint2NeedSpin>());
    });

    test('gợi ý 2 không bao giờ là giá trị đúng: chỉ nói thông số nào, không nói bằng bao nhiêu', () {
      // Dữ liệu gợi ý 2 không có trường lỗ, kiểu đánh hay mức lực nào của cú đúng.
      final h = hintsFor(rail, pot(rail, Pocket.bottomMiddle, Stroke.stun, 75));
      final hint = h.two!.hint;
      expect(hint, isNot(isA<Hint2Pocket>()));
      expect(hint.toString(), isNot(contains('45')));
    });

    test('kết luận không sai thì không có gợi ý', () {
      final h = hintsFor(rail, pot(rail, Pocket.bottomMiddle, Stroke.stun, 45));
      expect(h.one, isNull);
      expect(h.two, isNull);
    });
  });
}
