import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Vì sao một cú thủ phạm luật WPA (spec quyết định 1, mục 3.5). Thứ tự là
/// thứ tự kiểm: tên lỗi đầu tiên trúng là tên báo ra.
enum SafetyFoul {
  /// Bi cái không chạm bi hợp lệ.
  missed,

  /// Đường bi cái trước va chạm đi qua bi khác: chạm bi khác trước.
  hitOtherFirst,

  /// A băng: số băng bi cái chạm trước va chạm khác số băng của chuỗi.
  wrongRailCount,

  /// Chết cái.
  scratch,

  /// Bi hợp lệ rơi lỗ: là may, không phải cú thủ.
  legalPocketed,

  /// Sau va chạm không bi nào chạm băng.
  noRail,

  /// Đường bi hợp lệ sau va chạm đi qua bi chắn.
  objectBlocked,

  /// Đường bi cái sau va chạm đi qua bi chắn: mô phỏng hai bi không biết bi
  /// cái dừng đâu (độ lệch 5 của kế hoạch, cùng luật với phần ăn bi).
  cueAfterBlocked,

  /// Lõi quá maxSimTime.
  timeout,
}

/// Lỗi của vết [t]; null khi đúng luật. [rails] là số băng của chuỗi (0 khi
/// trực tiếp); [obstacles] là mọi bi khác bi hợp lệ.
SafetyFoul? safetyFoulOf(ShotTrace t,
    {required int rails, required List<Vec2> obstacles, TableSpec table = TableSpec.nineFoot}) {
  if (t.contactCue == null) return SafetyFoul.missed;
  if (!polylineClear(t.cueBefore, obstacles, table: table)) return SafetyFoul.hitOtherFirst;
  final before = t.rails.where((h) => h.ball == ShotBall.cue && !h.afterContact).length;
  if (before != rails) return SafetyFoul.wrongRailCount;
  if (t.cuePocket != null) return SafetyFoul.scratch;
  if (t.objectPocket != null) return SafetyFoul.legalPocketed;
  if (!t.rails.any((h) => h.afterContact)) return SafetyFoul.noRail;
  if (!polylineClear(t.objectPath, obstacles, table: table)) return SafetyFoul.objectBlocked;
  if (!polylineClear(t.cueAfter, obstacles, table: table)) return SafetyFoul.cueAfterBlocked;
  return null;
}
