import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Phương án A băng qua [rails] vào [target] (spec 3.4); null khi đường soi
/// gương bị chắn, sai thứ tự băng hay chạm băng ở miệng lỗ.
SafetyOption? kickOption(SafetyContext c, PlacedBall target, List<Rail> rails,
    double thickness, ThicknessSide side, Stroke stroke, double power) {
  final lateral = contactLateral(thickness, side, table: c.table);
  final path = kickPath(
    cue: c.cue,
    ball: target.pos,
    rails: rails,
    lateral: lateral,
    obstacles: c.obstaclesOf(target.number),
    table: c.table,
  );
  if (path == null) return null;
  return SafetyOption(
    kind: SafetyKind.kick,
    ballNum: target.number,
    ball: target.pos,
    rails: List.unmodifiable(rails),
    thickness: thickness,
    side: side,
    lateral: lateral,
    stroke: stroke,
    power: power,
    initialAim: path.aim,
    contact: path.contact,
  );
}
