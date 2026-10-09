import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

import '../../support/planner_tables.dart';

/// Hình học của cú phòng thủ (spec cú phòng thủ mục 3.2–3.4, quyết định 5).
void main() {
  const table = TableSpec.nineFoot;
  final d = table.ballDiameter;

  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  /// Số đường A băng hình học còn mở với [count] băng, cả ba điểm chạm.
  int openPaths(TableSetup s, int count) {
    final c = contextOf(s);
    var n = 0;
    for (final target in c.legal) {
      for (final rails in railSequences(count)) {
        for (final (f, side) in kickContactOrder) {
          final path = kickPath(
              cue: c.cue,
              ball: target.pos,
              rails: rails,
              lateral: contactLateral(f, side),
              obstacles: c.obstaclesOf(target.number));
          if (path != null) n++;
        }
      }
    }
    return n;
  }

  test('độ dày ra độ lệch ngang: trọn bi 0, trái dương, phải âm', () {
    expect(contactLateral(1, ThicknessSide.full), 0);
    expect(contactLateral(0.5, ThicknessSide.left), closeTo(d / 2, 1e-12));
    expect(contactLateral(0.5, ThicknessSide.right), closeTo(-d / 2, 1e-12));
    expect(contactLateral(0.125, ThicknessSide.left), closeTo(d * 0.875, 1e-12));
  });

  test('bi ảo theo độ dày: cách tâm bi đúng một đường kính, lệch đúng bên', () {
    const cue = Vec2(30, 80), ball = Vec2(180, 80);
    for (final lateral in [0.0, d / 2, -d / 2, 0.875 * d]) {
      final c = directContact(cue, ball, lateral)!;
      expect(c.contact.distanceTo(ball), closeTo(d, 1e-9));
      final u = (c.contact - cue).normalized;
      expect((c.contact - ball).dot(leftOf(u)), closeTo(lateral, 1e-9));
    }
    // Bi cái đi sang phải màn: bên trái là phía trên (y nhỏ hơn).
    expect(directContact(cue, ball, d / 2)!.contact.y, lessThan(80));
  });

  test('đo độ lệch ở vết thật: dương là bi cái lệch bên trái', () {
    const s = BallState(pos: Vec2(0, -1), vel: Vec2(10, 0));
    expect(lateralAt(s, Vec2.zero), closeTo(1, 1e-12));
  });

  test('bi cái sát bi hợp lệ: phân loại không lỗi', () {
    const ball = Vec2(100, 60);
    final c = SafetyContext(
      game: GameType.nineBall,
      cue: ball + Vec2(d + 0.001, 0),
      balls: const [PlacedBall(number: 1, pos: ball)],
    );
    expect(() => c.snookered, returnsNormally);
    expect(c.snookered, isFalse);
  });

  group('phân loại đui (spec 3.2, test 9.1.1)', () {
    test('bi chắn giữa đường chắn cả trọn bi lẫn hai đường mỏng: đui', () {
      final c = contextOf(snookerOneRailTable());
      expect(c.snookered, isTrue);
      expect(c.reason, SafetyReason.snookered);
    });

    test('hở một mép: không đui, chỉ thử độ dày nhìn thấy được', () {
      final s = partlyVisibleTable();
      final c = contextOf(s);
      expect(c.snookered, isFalse);
      expect(openContacts(c.cue, c.legal.single.pos, c.obstaclesOf(1)),
          [(0.25, ThicknessSide.left), (0.125, ThicknessSide.left)]);
    });

    test('bàn hết đường ăn và bàn 8 bi: không lỗ nào, nhưng thấy bi', () {
      for (final s in [noPotTable(), eightSafetyTable()]) {
        expect(CandidateFinder(game: s.game).easiest(s.cue, s.balls), isNull);
        expect(contextOf(s).snookered, isFalse);
      }
    });

    test('8 bi: đui chỉ khi mọi bi hợp lệ bị chắn', () {
      final s = snookerOneRailTable();
      final c = SafetyContext(game: GameType.eightBall, cue: s.cue, balls: [
        ...s.balls,
        const PlacedBall(number: 3, pos: Vec2(60, 20)),
      ]);
      // Bi 2 (bi chắn) cũng là bi của tôi trong 8 bi, nên còn thấy bi.
      expect(c.legal.map((b) => b.number), [1, 2, 3]);
      expect(c.snookered, isFalse);
    });
  });

  test('chuỗi băng không lặp băng liền nhau: 4, 12, 36, 108', () {
    for (final (n, count) in [(1, 4), (2, 12), (3, 36), (4, 108)]) {
      final seqs = railSequences(n);
      expect(seqs, hasLength(count));
      for (final s in seqs) {
        for (var i = 0; i + 1 < s.length; i++) {
          expect(s[i], isNot(s[i + 1]));
        }
      }
    }
    expect(railSequences(1), [for (final r in Rail.values) [r]]);
  });

  test('soi gương qua băng: đối xứng qua biên tâm bi', () {
    const p = Vec2(100, 40);
    expect(mirrorAcross(p, Rail.top), Vec2(100, 2 * table.minY - 40));
    expect(mirrorAcross(p, Rail.right), Vec2(2 * table.maxX - 100, 40));
  });

  test('miệng lỗ: điểm chạm băng sát lỗ góc bị bỏ, giữa băng thì không', () {
    expect(inPocketMouth(Vec2(table.minX, 5)), isTrue);
    expect(inPocketMouth(Vec2(table.length / 2 + 3, table.minY)), isTrue);
    expect(inPocketMouth(Vec2(table.minX, 63.5)), isFalse);
  });

  group('A băng hình học trên các bàn đui (kiểm bằng nguyên mẫu trên a35667b)', () {
    test('bàn 1 băng: đi băng dài trên chạm đúng giữa hai bi, băng ngắn bị chắn', () {
      final c = contextOf(snookerOneRailTable());
      final top = kickPath(
          cue: c.cue, ball: c.legal.single.pos, rails: const [Rail.top], lateral: 0,
          obstacles: c.obstaclesOf(1))!;
      expect(top.hits.single.x, closeTo(105, 1e-9));
      expect(top.hits.single.y, table.minY);
      for (final r in [Rail.left, Rail.right]) {
        expect(
            kickPath(cue: c.cue, ball: c.legal.single.pos, rails: [r], lateral: 0,
                obstacles: c.obstaclesOf(1)),
            isNull);
      }
      // Nguyên mẫu đếm 6 / 15 / 23 đường mở cho 1 / 2 / 3 băng.
      expect(openPaths(snookerOneRailTable(), 1), 6);
    });

    test('bàn 2 băng: không còn đường 1 băng nào, còn đường 2 băng', () {
      // Nguyên mẫu: 0 / 13 / 8.
      expect(openPaths(snookerTwoRailTable(), 1), 0);
      expect(openPaths(snookerTwoRailTable(), 2), greaterThan(0));
    });

    test('bàn 3 băng: không còn đường 1 hay 2 băng nào, còn đường 3 băng', () {
      // Nguyên mẫu: 0 / 0 / 8.
      expect(openPaths(snookerThreeRailTable(), 1), 0);
      expect(openPaths(snookerThreeRailTable(), 2), 0);
      expect(openPaths(snookerThreeRailTable(), 3), greaterThan(0));
      for (final s in [snookerTwoRailTable(), snookerThreeRailTable()]) {
        expect(contextOf(s).snookered, isTrue);
        expect(CandidateFinder(game: s.game).easiest(s.cue, s.balls), isNull);
      }
    });
  });

  test('chấm: băng dài 0–8 từ góc trái, băng ngắn 0–4 từ góc trên, làm tròn nửa chấm', () {
    expect(diamondOf(Vec2(table.length / 2, table.minY), Rail.top), 4);
    expect(diamondOf(Vec2(table.length * 2.3 / 8, table.maxY), Rail.bottom), 2.5);
    expect(diamondOf(Vec2(table.length * 2.2 / 8, table.minY), Rail.top), 2);
    expect(diamondOf(Vec2(table.minX, table.width * 3 / 4), Rail.left), 3);
    expect(diamondOf(Vec2(table.maxX, table.width * 0.3 / 4), Rail.right), 0.5);
    expect(longRailDiamonds, 2 * shortRailDiamonds);
  });

  test('sát băng: cách băng không quá một bi', () {
    expect(nearRail(Vec2(table.minX + nearRailDiameters * d, 63.5)), isTrue);
    expect(nearRail(Vec2(table.minX + nearRailDiameters * d + 0.01, 63.5)), isFalse);
    expect(nearRail(Vec2(127, table.maxY - 1)), isTrue);
  });
}
