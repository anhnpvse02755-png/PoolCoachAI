import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

/// Mức lực đầu tiên làm bi cái chết cái, và rơi lỗ nào.
class ScratchRisk {
  const ScratchRisk({required this.power, required this.pocket});
  final double power;
  final Pocket pocket;
}

/// Tăng lực từ [power] lên từng 1% tới 100%, trả mức đầu tiên chết cái.
///
/// Ngay [power] đã chết cái thì trả chính [power] (biên bằng 0). Không
/// mức nào chết cái thì null. Chỉ xét **dư** lực: thiếu lực làm đường
/// đi ngắn lại, hiếm khi chạm tới lỗ (spec mục 1, ngoài phạm vi).
ScratchRisk? scratchMargin(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  TableSpec table = TableSpec.nineFoot,
}) {
  for (var p = power; p <= 100; p += 1) {
    final pocket =
        simulateCueBall(g, stroke: stroke, power: p, spin: spin, table: table)
            .scratch;
    if (pocket != null) return ScratchRisk(power: p, pocket: pocket);
  }
  return null;
}
