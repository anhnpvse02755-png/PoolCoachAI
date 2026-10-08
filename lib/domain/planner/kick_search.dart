import 'package:poolcoachai/domain/planner/planner_constants.dart';
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

/// Mọi phương án A băng từ [fromRails] tới [toRails] băng (spec 3.4), đúng
/// thứ tự thử: ít băng trước, bi số nhỏ trước, chuỗi theo [railSequences],
/// điểm chạm theo [kickContactOrder], kiểu đánh, lực tăng dần. Đường soi
/// gương hỏng thì bỏ cả nhóm.
List<SafetyOption> kickOptions(SafetyContext c, {required int fromRails, required int toRails}) {
  final out = <SafetyOption>[];
  for (var n = fromRails; n <= toRails; n++) {
    for (final target in c.legal) {
      for (final rails in railSequences(n)) {
        for (final (f, side) in kickContactOrder) {
          if (kickOption(c, target, rails, f, side, kickStrokes.first, powerCandidates.first) ==
              null) {
            continue;
          }
          for (final stroke in kickStrokes) {
            for (final power in powerCandidates) {
              out.add(kickOption(c, target, rails, f, side, stroke, power)!);
            }
          }
        }
      }
    }
  }
  return out;
}
