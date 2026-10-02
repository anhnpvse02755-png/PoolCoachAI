import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final shots = gridShots().toList();

  bool onBounds(Vec2 p) =>
      p.x == table.minX || p.x == table.maxX || p.y == table.minY || p.y == table.maxY;

  /// Pháp tuyến hướng ra băng tại điểm chạm; null khi chạm đúng góc.
  Vec2? outwardAt(Vec2 hit) {
    final onX = hit.x == table.minX || hit.x == table.maxX;
    final onY = hit.y == table.minY || hit.y == table.maxY;
    if (onX == onY) return null;
    if (onX) return Vec2(hit.x == table.maxX ? 1 : -1, 0);
    return Vec2(0, hit.y == table.maxY ? 1 : -1);
  }

  /// Mọi cú dội băng không chết cái trên lưới, đánh đứng bi lực 95%.
  final banked = [
    for (final g in shots)
      if (simulateCueBall(g, stroke: Stroke.stun, power: 95)
          case final path when path.bankUsed && path.scratch == null)
        (g: g, path: path),
  ];

  /// Cú bật gần song song với băng: áp phê bị kẹp ở giới hạn 89°, nên
  /// hướng đổi không còn nói được gì về chiều của áp phê.
  bool grazing(Vec2 hit, Vec2 rebound) {
    final out = outwardAt(hit);
    if (out == null) return true;
    final fromNormal = (-out).signedAngleTo(rebound).abs() * 180 / math.pi;
    return fromNormal > 87;
  }

  test('lưới có đủ cú dội băng để test có ý nghĩa', () {
    expect(banked.length, greaterThan(30));
  });

  test('điểm chạm băng nằm đúng trên biên, đoạn đầu là đường thẳng', () {
    for (final (:g, :path) in banked) {
      expect(onBounds(path.railHit!), isTrue, reason: '${g.cue}→${g.object}');
      final first = path.segments.first;
      expect(first, isA<Straight>());
      expect(first.start, g.ghost);
      expect(first.end, path.railHit);
      expect(path.segments.length, lessThanOrEqualTo(2));
    }
  });

  test('không áp phê thì góc tới bằng góc phản xạ', () {
    for (final (:g, :path) in banked) {
      final hit = path.railHit!;
      final out = outwardAt(hit);
      if (out == null) continue;
      final incoming = (hit - g.ghost).normalized;
      final expected = out.x != 0
          ? Vec2(-incoming.x, incoming.y)
          : Vec2(incoming.x, -incoming.y);
      expect(path.reboundDir!.distanceTo(expected), lessThan(1e-9),
          reason: '${g.cue}→${g.object}');
    }
  });

  test('áp phê phải đẩy về bên phải hướng ra băng, áp phê trái ngược lại',
      () {
    for (final (:g, :path) in banked) {
      final out = outwardAt(path.railHit!);
      if (out == null || grazing(path.railHit!, path.reboundDir!)) continue;
      final none = path.reboundDir!;
      final right = simulateCueBall(g,
              stroke: Stroke.stun,
              power: 95,
              spin: const SideSpin(SpinSide.right, 1))
          .reboundDir;
      final left = simulateCueBall(g,
              stroke: Stroke.stun,
              power: 95,
              spin: const SideSpin(SpinSide.left, 1))
          .reboundDir;
      // Rơi lỗ trước băng với áp phê này thì không còn hướng bật để so.
      if (right == null || left == null) continue;
      expect((right - none).dot(out.rightNormal), greaterThan(0),
          reason: '${g.cue}→${g.object}');
      expect((left - none).dot(out.rightNormal), lessThan(0),
          reason: '${g.cue}→${g.object}');
    }
  });

  test('càng lệch nhiều đầu cơ, góc bật càng đổi nhiều', () {
    double turn(Vec2 a, Vec2 b) => a.signedAngleTo(b).abs();
    var strictlyGrew = 0;
    for (final (:g, :path) in banked) {
      if (grazing(path.railHit!, path.reboundDir!)) continue;
      final none = path.reboundDir!;
      final dirs = [
        for (final tips in [0.5, 1.0, 2.0])
          simulateCueBall(g,
                  stroke: Stroke.stun,
                  power: 95,
                  spin: SideSpin(SpinSide.right, tips))
              .reboundDir,
      ];
      if (dirs.contains(null)) continue;
      final turns = [for (final d in dirs) turn(none, d!)];
      expect(turns[0], lessThanOrEqualTo(turns[1] + 1e-12));
      expect(turns[1], lessThanOrEqualTo(turns[2] + 1e-12));
      if (turns[2] > turns[0] + 1e-6) strictlyGrew++;
    }
    expect(strictlyGrew, greaterThan(0));
  });

  test('góc bật không bao giờ quá song song với băng', () {
    for (final (:g, :path) in banked) {
      final out = outwardAt(path.railHit!);
      if (out == null) continue;
      final rebound = simulateCueBall(g,
              stroke: Stroke.stun,
              power: 95,
              spin: const SideSpin(SpinSide.right, 2))
          .reboundDir;
      if (rebound == null) continue;
      expect(rebound.dot(-out), greaterThan(math.cos(89.5 * math.pi / 180)));
    }
  });

  // Chủ dự án duyệt trên Chrome: xoáy trô gần như hết trước khi tới
  // băng, nên sau dội băng bi cái đi thẳng. Cu lê vẫn giữ đường cong.
  test('trô dội băng thì đoạn sau là đường thẳng theo hướng bật', () {
    var drawBanks = 0;
    var followCurves = 0;
    for (final g in shots) {
      for (final p in powerPresets) {
        final draw = simulateCueBall(g, stroke: Stroke.draw, power: p);
        if (draw.bankUsed && draw.scratch == null && draw.segments.length == 2) {
          drawBanks++;
          final second = draw.segments[1];
          final where = '${g.cue}→${g.object} $p';
          expect(second, isA<Straight>(), reason: where);
          expect(second.start, draw.railHit, reason: where);
          final heading = (second.end - second.start).normalized;
          expect(heading.dot(draw.reboundDir!), closeTo(1, 1e-9),
              reason: where);
        }
        final follow = simulateCueBall(g, stroke: Stroke.follow, power: p);
        if (follow.bankUsed &&
            follow.segments.length == 2 &&
            follow.segments[1] is Curve) {
          followCurves++;
        }
      }
    }
    expect(drawBanks, greaterThan(10));
    expect(followCurves, greaterThan(10));
  });

  test('không chạm băng thì áp phê không đổi đường đi', () {
    for (final g in shots) {
      final plain = simulateCueBall(g, stroke: Stroke.follow, power: 40);
      if (plain.bankUsed) continue;
      final spun = simulateCueBall(g,
          stroke: Stroke.follow,
          power: 40,
          spin: const SideSpin(SpinSide.left, 2));
      expect(spun.end, plain.end, reason: '${g.cue}→${g.object}');
    }
  });

  test('áp phê không đổi đoạn trước khi chạm băng', () {
    for (final (:g, :path) in banked) {
      final spun = simulateCueBall(g,
          stroke: Stroke.stun,
          power: 95,
          spin: const SideSpin(SpinSide.left, 1));
      // Rơi lỗ trước băng thì không có điểm chạm để so.
      if (spun.railHit != null) expect(spun.railHit, path.railHit);
    }
  });

  // PRD §8: tối đa một lần dội — nếu đoạn sau sẽ ra khỏi bàn thì bi cái
  // dừng đúng trên biên theo hướng bật, không dội lần hai.
  group('chạm băng thứ hai thì dừng ở đó', () {
    /// Điểm cuối chưa kẹp của đoạn sau: railHit + reboundDir * phần còn lại.
    /// Phần còn lại = quãng bi cái đi tổng cộng trừ quãng tới băng đầu.
    Vec2 unclampedEnd(ShotGeometry g, CueBallPath path, Stroke stroke,
        double power) {
      final travel = maxTravel * power / 100;
      final theta = g.angle * math.pi / 180;
      final rollSign = switch (stroke) {
        Stroke.stun => 0.0,
        Stroke.follow => 1.0,
        Stroke.draw => -1.0,
      };
      final target = g.ghost +
          g.tangentDir * (travel * math.sin(theta)) +
          g.objectDir * (rollSign * rollCarry * travel * math.cos(theta));
      final remaining =
          g.ghost.distanceTo(target) - g.ghost.distanceTo(path.railHit!);
      return path.railHit! + path.reboundDir! * remaining;
    }

    void expectStopsOnRail(
        ShotGeometry g, CueBallPath path, Stroke stroke, String where) {
      final last = path.segments.last;
      expect(path.segments.length, 2, reason: where);
      expect(onBounds(path.end), isTrue, reason: where);
      expect(last, isA<Straight>(), reason: where);
      expect(last.start, path.railHit, reason: where);
      expect(last.end, path.end, reason: where);
      if (stroke != Stroke.follow) {
        final heading = (last.end - last.start).normalized;
        expect(heading.dot(path.reboundDir!), closeTo(1, 1e-9),
            reason: where);
      }
    }

    test('lưới: đoạn sau ra khỏi bàn thì dừng đúng trên biên', () {
      var cases = 0;
      for (final g in shots) {
        for (final stroke in Stroke.values) {
          for (final power in powerPresets) {
            for (final spin in SideSpin.all) {
              final path = simulateCueBall(g,
                  stroke: stroke, power: power, spin: spin);
              if (!path.bankUsed || path.scratch != null) continue;
              if (table.contains(unclampedEnd(g, path, stroke, power))) {
                continue;
              }
              cases++;
              expectStopsOnRail(g, path, stroke,
                  '${g.cue}→${g.object} $stroke $power $spin');
            }
          }
        }
      }
      expect(cases, greaterThan(10),
          reason: 'lưới phải có cú chạm băng thứ hai thì test mới có nghĩa');
    });

    test('dựng tay: bi cái dội băng rồi chạy tiếp tới băng thứ hai', () {
      final g = geometryFor(const Vec2(200, 40), Pocket.topRight, 35);
      final path = simulateCueBall(g, stroke: Stroke.stun, power: 95);
      expect(path.bankUsed, isTrue);
      expect(table.contains(unclampedEnd(g, path, Stroke.stun, 95)), isFalse,
          reason: 'bố cục dựng tay phải đủ lực để ra khỏi bàn');
      expectStopsOnRail(g, path, Stroke.stun, 'dựng tay');
    });
  });
}
