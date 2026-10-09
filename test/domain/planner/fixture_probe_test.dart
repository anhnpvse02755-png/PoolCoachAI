// ignore_for_file: avoid_print
@Tags(['probe'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

/// Không phải test: in số liệu để người dò chọn toạ độ bàn.
void main() {
  void dump(String name, TableSetup setup) {
    final c = contextFor(setup);
    print('== $name: lỗ ${c.geometry.pocket.name}, góc ${c.geometry.angle.toStringAsFixed(1)}°');
    for (final key in tierOneKeys(c.geometry)) {
      final a = c.lookup(key);
      final why = a == null ? 'quá giờ' : rejectionOf(a, key.pocket, c.obstacles)?.name;
      final s = (a == null || why != null) ? null : scoreOption(c, key, a);
      // Góc tại điểm dừng danh nghĩa (chưa lệch lực) và bi kế tiếp đó.
      final first = s == null ? null : c.next.easiest(a!.trace.cueEnd, c.after);
      final row = why ??
          (s == null
              ? 'không có cú cho bi sau'
              : 'băng ${a!.trace.cueRailCount} · robust ${s.robustDiff1?.toStringAsFixed(2)}'
                  ' · danh nghĩa ${first?.angle.toStringAsFixed(2)} (bi ${first?.ball.number}'
                  ', cách ${first == null ? '-' : a.trace.cueEnd.distanceTo(first.ball.pos).toStringAsFixed(1)} cm)'
                  ' · diff2 ${s.diff2?.toStringAsFixed(2)}'
                  ' · cách bi ảo ${(s.distance / distanceWeight).toStringAsFixed(1)} cm'
                  ' · tổng ${s.total.toStringAsFixed(2)}');
      print('  ${key.stroke.name} ${key.power.round()}%: $row');
    }
    final steps = planToEnd(setup);
    print('  kế hoạch: ${steps.map((s) => '${s.ballNum}:${s.kind.name}').join(' → ')}');
  }

  test('bảng phương án của các bàn test', () {
    dump('railTable', railTable());
    dump('cornerFollowTable', cornerFollowTable());
    dump('orderTable 9 bi', orderTable(GameType.nineBall));
    dump('orderTable 8 bi', orderTable(GameType.eightBall));
    dump('typicalNineBallTable', typicalNineBallTable());
    dump('penultimateTable', penultimateTable());
    dump('eightLastTable', eightLastTable());
  });

  test('lưới bàn 2 bi thoả điều kiện test 5, 7, 8', () {
    const cues = [Vec2(127, 63.5), Vec2(60, 90), Vec2(190, 40)];
    for (var bx = 30.0; bx <= 224; bx += 38) {
      for (var by = 20.0; by <= 107; by += 29) {
        for (var nx = 20.0; nx <= 234; nx += 42) {
          for (var ny = 15.0; ny <= 112; ny += 32) {
            final b1 = Vec2(bx, by), b2 = Vec2(nx, ny);
            if (b1.distanceTo(b2) < 15) continue;
            for (final cue in cues) {
              if (cue.distanceTo(b1) < 10 || cue.distanceTo(b2) < 10) continue;
              final setup = TableSetup(
                game: GameType.nineBall,
                cue: cue,
                balls: [PlacedBall(number: 1, pos: b1), PlacedBall(number: 2, pos: b2)],
              );
              // Không có cặp bi–lỗ nào thì không có gì để chấm.
              if (CandidateFinder(game: setup.game).easiest(cue, setup.balls) == null) {
                continue;
              }
              final c = contextFor(setup);
              final options = scoreTier(c, tierOneKeys(c.geometry));
              final chosen = bestOf(options);
              if (chosen == null) continue;
              final tags = <String>[
                if (options.any((a) =>
                    a.score.distance < chosen.score.distance &&
                    a.score.robustDiff1! - chosen.score.robustDiff1! >
                        (chosen.score.bank + chosen.score.tech + chosen.score.power) -
                            (a.score.bank + a.score.tech + a.score.power)))
                  'test5',
                if (chosen.key.stroke != Stroke.draw &&
                    chosen.aimed.trace.cueRailCount >= 1 &&
                    options.any((d) =>
                        d.key.stroke == Stroke.draw &&
                        d.aimed.trace.cueRailCount == 0 &&
                        d.score.position >= chosen.score.position &&
                        d.score.position - chosen.score.position <=
                            techPenaltyDraw - bankPenaltyOneRail))
                  'test7',
                if (powerCandidates.any((p) {
                  final a = c.lookup(shotKey(c.geometry, Stroke.follow, p));
                  if (a == null || a.trace.cuePocket == null) return false;
                  final there = c.next.easiest(a.trace.cueEnd, c.after)?.angle;
                  return there != null && there < chosen.score.robustDiff1!;
                }))
                  'test8',
              ];
              if (tags.isNotEmpty) {
                print('${tags.join(',')}: bi cái $cue, bi 1 $b1, bi 2 $b2, '
                    'chọn ${chosen.key.stroke.name} ${chosen.key.power.round()}%');
              }
            }
          }
        }
      }
    }
  });
}
