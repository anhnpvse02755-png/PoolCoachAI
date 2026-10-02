import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Góc của hai mức độ dốc cơ, radian.
extension CueElevationAngle on CueElevation {
  double get radians =>
      (this == CueElevation.normal ? cueElevationNormal : cueElevationSteep) *
      math.pi /
      180;
}

/// Độ lệch ngang `a` của đầu cơ, cm: dương là áp phê phải.
double sideOffsetOf(SideSpin spin) => switch (spin.side) {
      null => 0,
      SpinSide.right => spin.tips * tipWidth,
      SpinSide.left => -spin.tips * tipWidth,
    };

/// Bi cái bị lệch do áp phê: góc giữa hướng cơ và hướng bi đi, radian
/// (Alciatore TP A.31). Cùng dấu với [sideOffset]; bi lệch về phía
/// ngược lại, nên [strikeCue] quay hướng đi một góc âm của giá trị này.
double squirtAngle(double sideOffset, double radius) {
  final r = sideOffset / radius;
  final rest = 1 - r * r;
  return math.atan(2.5 * r * math.sqrt(rest) /
      (1 + 1 / endMassRatio + 2.5 * rest));
}

/// Cơ chạm bi cái: trạng thái ban đầu của bi cái (spec mục 4.1).
///
/// [aimAngle] là hướng cơ trên mặt bàn, radian, cùng chiều với
/// [Vec2.rotated]. [verticalOffset] là `b`, cm, dương là trên tâm.
/// [elevation] là độ dốc cơ, radian.
BallState strikeCue({
  required Vec2 pos,
  required double aimAngle,
  required double power,
  required double verticalOffset,
  required SideSpin spin,
  required double elevation,
  TableSpec table = TableSpec.nineFoot,
}) {
  final radius = table.radius;
  final speed = maxCueSpeed * power / 100;
  final a = sideOffsetOf(spin);
  final heading = Vec2(math.cos(aimAngle), math.sin(aimAngle));

  // Cơ cứng đẩy bi qua điểm chạm r: xung lực J dọc hướng cơ cho
  // m·v = J và I·ω = r × J, nên ω = (5 v₀ / 2R²)·(r × d̂). Cơ dốc thì d̂
  // chúi xuống mặt bàn, áp phê sinh thêm xoáy quanh trục nằm ngang dọc
  // đường đi — chính phần đó làm bi cong (swerve) khi trượt trên khăn.
  final h = Vec3.flat(heading);
  final right = Vec3.flat(heading.rightNormal);
  final c = math.cos(elevation);
  final s = math.sin(elevation);
  final cueDir = h * c - Vec3.up * s;
  final faceUp = h * s + Vec3.up * c;
  final contact = right * a + faceUp * verticalOffset;
  final omega = contact.cross(cueDir) * (5 * speed / (2 * radius * radius));

  // Vận tốc nằm ngang theo hướng cơ chiếu xuống bàn, quay ngược phía áp
  // phê đúng bằng góc lệch.
  final dir = heading.rotated(-squirtAngle(a, radius));
  return BallState(pos: pos, vel: dir * speed, spin: omega);
}
