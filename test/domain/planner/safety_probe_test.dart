// ignore_for_file: avoid_print
@Tags(['probe'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

/// Không phải test: in số liệu để người dò chọn toạ độ bàn thủ bi.
///   flutter test --tags probe --run-skipped test/domain/planner/safety_probe_test.dart
void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  /// Số phương án của một đường A băng mở: kiểu đánh × lực.
  final kickGroup = kickStrokes.length * safetyPowers.length;

  void dump(String name, TableSetup s) {
    final c = contextOf(s);
    final pot = CandidateFinder(game: s.game).easiest(s.cue, s.balls);
    print('== $name: ${c.reason.name}, lỗ ${pot?.geometry.pocket.name ?? 'không'}');
    for (final t in c.visible) {
      print('  trực tiếp bi ${t.number}: '
          '${directOptions(c, t, const [SideSpin.none()]).length} không áp phê, '
          '${directOptions(c, t, safetySideSpins).length} áp phê');
    }
    // A băng luôn thử, kể cả khi không đui (chủ sản phẩm chốt 08/10/2026).
    for (var n = 1; n <= 4; n++) {
      final groups = kickOptions(c, fromRails: n, toRails: n).length ~/ kickGroup;
      print('  $n băng: $groups đường hình học mở');
    }
    String line(SafetyShot r) {
      final o = r.opponent;
      return '${r.kind.name} ${r.rails} băng, bi ${r.ballNum}, ${r.thickness} ${r.side.name}, '
          '${r.stroke.name} ${r.spin} ${r.power.round()}%, tổng ${r.total.toStringAsFixed(2)}, '
          'chấm ${r.railAim?.diamond} ${r.railAim?.rail.name}; đối thủ: '
          '${o.snookered ? 'đui' : '${o.easiest?.angle.toStringAsFixed(1) ?? 'hết đường'}° bi ${o.ball?.number}'}; '
          'chịu sai số ${r.tolerance}/7';
    }

    // Lượt thô xong là lúc bước thủ hiện ra — ở điểm hỏi, hay làm cú tạm.
    // Lượt thô không có cú nào thì bước hiện ra ở cuối lượt đầy đủ. Từng đơn
    // vị việc như PlannerJob, nên đo cả đơn vị đầu của lượt đầy đủ đi cùng.
    final w = Stopwatch()..start();
    final job = SafetyJob(c);
    while (!job.coarseDone) {
      job.work();
    }
    final coarseMs = w.elapsedMilliseconds;
    final coarseUnits = job.simulations;
    final rough = job.coarseResult;
    print('  lượt thô: ${job.coarseOptions.length} phương án, xong sau $coarseUnits lần '
        'dò/mô phỏng, $coarseMs ms; ${rough == null ? 'không có cú hợp lệ, chờ lượt đầy đủ' : job.atCheckpoint ? 'thủ tốt, dừng hỏi' : 'chưa thủ tốt, hiện tạm và tìm tiếp'}');
    if (rough != null) print('  lượt thô chọn: ${line(rough)}');
    job.resume();
    while (!job.isDone) {
      job.step(budget: const Duration(days: 1));
    }
    final r = job.result;
    print('  đầy đủ: ${job.simulations} lần dò/mô phỏng, ${w.elapsedMilliseconds} ms, '
        '${job.options.length} phương án, thử ${job.triedRailCounts.toList()..sort()} băng; '
        'chặng ${job.openedStages.map((s) => '${s.tier.name}${s.ballNum ?? ''}').join(' → ')}');
    if (r == null) {
      print('  không có cú thủ hợp lệ');
      return;
    }
    print('  ${identical(r, rough) ? 'giữ cú lượt thô' : 'đầy đủ chọn: ${line(r)}'}');
  }

  test('bảng cú thủ của các bàn test', () {
    dump('snookerOneRailTable', snookerOneRailTable());
    dump('snookerTwoRailTable', snookerTwoRailTable());
    dump('snookerThreeRailTable', snookerThreeRailTable());
    dump('noPotTable', noPotTable());
    dump('eightSafetyTable', eightSafetyTable());
  });

  test('lưới bàn hết đường ăn: bi chắn ở miệng các lỗ đánh được', () {
    const cues = [Vec2(60, 100), Vec2(40, 63.5), Vec2(127, 110)];
    for (final cue in cues) {
      for (var bx = 60.0; bx <= 200; bx += 35) {
        for (var by = 25.0; by <= 105; by += 20) {
          final ball = Vec2(bx, by);
          if (ball.distanceTo(cue) < 20) continue;
          // Mọi lỗ đánh được khi bàn trống đều có một bi chắn ở miệng lỗ.
          final blockers = [
            for (final p in Pocket.values)
              if (evaluateShot(cue: cue, object: ball, pocket: p) is Makeable) jawBlocker(ball, p),
          ];
          final s = TableSetup(game: GameType.nineBall, cue: cue, balls: [
            PlacedBall(number: 1, pos: ball),
            for (var i = 0; i < blockers.length; i++)
              PlacedBall(number: i + 2, pos: blockers[i]),
          ]);
          final c = contextOf(s);
          if (c.snookered || CandidateFinder(game: s.game).easiest(cue, s.balls) != null) continue;
          print('ứng viên: bi cái $cue, bi 1 $ball, chắn $blockers');
        }
      }
    }
  });

  test('lưới tham lam thêm bi chắn để buộc thêm một băng', () {
    // Từ snookerTwoRailTable, thêm từng bi chắn trên lưới 6 cm sao cho hết
    // đường 1 và 2 băng mà còn ít nhất ba đường 3 băng.
    var balls = snookerTwoRailTable().balls;
    const cue = Vec2(30, 80);
    int open(List<PlacedBall> bs, int n) =>
        kickOptions(SafetyContext(game: GameType.nineBall, cue: cue, balls: bs),
                fromRails: n, toRails: n)
            .length;
    for (var round = 0; round < 4 && open(balls, 2) > 0; round++) {
      PlacedBall? pick;
      var best = 1 << 30;
      for (var x = 12.0; x <= 242; x += 6) {
        for (var y = 8.0; y <= 119; y += 6) {
          final at = Vec2(x, y);
          if ([cue, ...balls.map((b) => b.pos)]
              .any((q) => q.distanceTo(at) < TableSpec.nineFoot.ballDiameter + 1)) {
            continue;
          }
          final next = [...balls, PlacedBall(number: balls.length + 1, pos: at)];
          if (open(next, 1) > 0) continue;
          final three = open(next, 3);
          if (three < 3 * kickGroup) continue;
          final score = open(next, 2) * 100 - three;
          if (score < best) {
            best = score;
            pick = next.last;
          }
        }
      }
      if (pick == null) break;
      balls = [...balls, pick];
      print('thêm ${pick.pos}: 2 băng còn ${open(balls, 2) ~/ kickGroup} nhóm, 3 băng ${open(balls, 3) ~/ kickGroup}');
    }
  });
}
