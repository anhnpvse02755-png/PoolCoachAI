import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  const power = 20.0;
  const travel = maxTravel * power / 100;

  CueBallPath run(ShotGeometry g, Stroke stroke, {double p = power}) =>
      simulateCueBall(g, stroke: stroke, power: p);

  group('cú thẳng — PRD cho trô/cu lê đứng im, spec sửa bằng thành phần cos',
      () {
    final g = geometryFor(tableCenter, Pocket.topRight, 0);

    test('đánh đứng bi dừng ngay tại bi ảo', () {
      final path = run(g, Stroke.stun);
      expect(path.end.distanceTo(g.ghost), lessThan(1e-6));
      expect(path.bankUsed, isFalse);
      expect(path.scratch, isNull);
    });

    test('cu lê đi thẳng theo bi mục tiêu', () {
      final moved = run(g, Stroke.follow).end - g.ghost;
      expect(moved.cross(g.objectDir), closeTo(0, 1e-9));
      expect(moved.dot(g.objectDir), closeTo(rollCarry * travel, 1e-9));
    });

    test('trô lùi thẳng về', () {
      final moved = run(g, Stroke.draw).end - g.ghost;
      expect(moved.cross(g.objectDir), closeTo(0, 1e-9));
      expect(moved.dot(g.objectDir), closeTo(-rollCarry * travel, 1e-9));
    });
  });

  group('cú cắt 40°', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 40);

    test('đánh đứng bi đi thẳng theo đường tiếp tuyến', () {
      final path = run(g, Stroke.stun);
      expect(path.segments.single, isA<Straight>());
      final moved = path.end - g.ghost;
      expect(moved.cross(g.tangentDir), closeTo(0, 1e-9));
      expect(moved.length, closeTo(travel * 0.6427876097, 1e-6)); // sin 40°
    });

    test('cu lê cong về phía trước, trô cong về phía sau', () {
      final follow = run(g, Stroke.follow);
      final draw = run(g, Stroke.draw);
      expect((follow.end - g.ghost).dot(g.objectDir), greaterThan(0));
      expect((draw.end - g.ghost).dot(g.objectDir), lessThan(0));

      final curve = follow.segments.single as Curve;
      expect(curve.p0, g.ghost);
      expect(curve.p3, follow.end);
      // Rời bi ảo theo đường tiếp tuyến rồi mới cong.
      expect((curve.p1 - curve.p0).normalized.cross(g.tangentDir),
          closeTo(0, 1e-9));
      expect((curve.p1 - curve.p0).dot(g.tangentDir), greaterThan(0));
    });
  });

  test('cắt đường cong tại t giữ nguyên điểm đầu và trúng điểm giữa đường',
      () {
    const c = Curve(Vec2(0, 0), Vec2(10, 0), Vec2(20, 10), Vec2(20, 20));
    final half = c.splitAt(0.5);
    expect(half.p0, c.p0);
    expect(half.p3.distanceTo(c.pointAt(0.5)), lessThan(1e-12));
    expect(c.splitAt(1).p3, c.p3);
    expect(c.pointAt(1), c.p3);
  });

  group('tính chất trên cả lưới bố cục', () {
    final shots = gridShots().toList();

    test('đường đi liền mạch, kết thúc trong bàn, end là điểm cuối thật', () {
      for (final g in shots) {
        for (final stroke in Stroke.values) {
          for (final p in powerPresets) {
            final path = run(g, stroke, p: p);
            final where = '${g.cue}→${g.object} $stroke $p';
            expect(path.segments.first.start, g.ghost, reason: where);
            for (var i = 0; i + 1 < path.segments.length; i++) {
              expect(path.segments[i].end, path.segments[i + 1].start,
                  reason: where);
            }
            expect(path.end, path.segments.last.end, reason: where);
            if (path.scratch == null) {
              expect(table.contains(path.end), isTrue, reason: where);
            }
          }
        }
      }
    });

    test('điểm điều khiển của đường cong không bao giờ ra ngoài băng', () {
      for (final g in shots) {
        for (final stroke in Stroke.values) {
          for (final p in powerPresets) {
            for (final seg in run(g, stroke, p: p).segments) {
              if (seg is Curve) {
                expect(table.contains(seg.p1) && table.contains(seg.p2),
                    isTrue,
                    reason: '${g.cue}→${g.object} $stroke $p');
              }
            }
          }
        }
      }
    });
  });

  test('SideSpin: bảy mức, 2 đầu cơ là nguy cơ trượt cơ', () {
    expect(SideSpin.all, hasLength(7));
    expect(SideSpin.all.first, const SideSpin.none());
    expect(const SideSpin(SpinSide.right, 2).risksMiscue, isTrue);
    expect(const SideSpin(SpinSide.right, 1).risksMiscue, isFalse);
    expect(const SideSpin(SpinSide.left, 1) == const SideSpin(SpinSide.left, 1),
        isTrue);
  });
}
