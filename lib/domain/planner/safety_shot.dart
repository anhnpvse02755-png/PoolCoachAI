import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Vì sao phải thủ: bị đui, hay thấy bi mà hết đường ăn (spec 3.2).
enum SafetyReason { snookered, noPot }

/// Cú thủ trực tiếp hay A băng.
enum SafetyKind { direct, kick }

/// Bên lệch khi chạm: bi cái đi qua bên trái hay bên phải tâm bi hợp lệ,
/// nhìn từ sau bi cái theo hướng đánh. Trọn bi thì không lệch.
enum ThicknessSide { full, left, right }

/// Điểm ngắm A băng: băng đầu tiên và số chấm (spec quyết định 5).
class RailAim {
  const RailAim({required this.rail, required this.diamond, required this.at});

  final Rail rail;

  /// Đếm từ góc trái (băng dài) hoặc góc trên (băng ngắn) trên màn, góc là
  /// chấm 0, làm tròn nửa chấm.
  final double diamond;

  /// Tâm bi cái lúc chạm băng — lấy từ vết mô phỏng, đúng trên biên.
  final Vec2 at;
}

/// Thế bàn đối thủ nhận sau cú thủ (spec 4.1, 4.4).
class OpponentView {
  const OpponentView({required this.snookered, this.ball, this.easiest});

  final bool snookered;

  /// Bi đối thủ được tính sát băng và khoảng cách: bi của cú dễ nhất; đui
  /// hoặc không lỗ nào thì bi số nhỏ nhất đối thủ phải đánh; null khi đối
  /// thủ không còn bi nào.
  final PlacedBall? ball;

  /// Cú dễ nhất của đối thủ (góc cắt nhỏ nhất, bỏ lỗ bị chắn).
  final ShotGeometry? easiest;

  /// Phần đối thủ của điểm: đui 0; không đui thì 95 − góc dễ nhất; không lỗ
  /// nào thì cũng 0 (góc coi như 95°).
  double get part {
    final e = easiest;
    return snookered || e == null ? 0 : blockedAngle - e.angle;
  }

  /// Khó cho đối thủ: đui, hết đường ăn, hay góc dễ nhất > [opponentHardAngle].
  bool get hard {
    final e = easiest;
    return snookered || e == null || e.angle > opponentHardAngle;
  }
}

/// Cú thủ đã chọn — trường `safety` của bước phòng thủ (spec 3.7).
class SafetyShot {
  const SafetyShot({
    required this.reason,
    required this.kind,
    required this.rails,
    required this.ballNum,
    required this.thickness,
    required this.side,
    required this.stroke,
    required this.spin,
    required this.power,
    required this.aimed,
    this.railAim,
    required this.opponent,
    required this.jitterEnds,
    required this.tolerance,
    this.sawsBhePercent,
    required this.contactDistance,
    required this.total,
  });

  final SafetyReason reason;
  final SafetyKind kind;

  /// Số băng của A băng; 0 khi trực tiếp.
  final int rails;

  /// Bi hợp lệ được chạm.
  final int ballNum;
  final double thickness;
  final ThicknessSide side;
  final Stroke stroke;
  final SideSpin spin;
  final double power;

  /// Cú đã dò: vết hai bi, và độ xoay hướng cơ để dòng áp phê dùng lại.
  /// `aimOffsetDeg` không bao giờ hiện thành lời khuyên theo độ.
  final AimedShot aimed;

  /// Chỉ có khi A băng.
  final RailAim? railAim;
  final OpponentView opponent;

  /// Điểm dừng bi cái khi lực −15 % / +15 %; null ở mức phạm luật.
  final ({Vec2? minus, Vec2? plus}) jitterEnds;

  /// Số mức trong 7 mức lực đều nhau ±15 % vẫn khó cho đối thủ (spec 4.3).
  final int tolerance;

  /// Chỉ có khi dùng áp phê.
  final int? sawsBhePercent;

  /// Quãng bi cái → bi ảo hình học, cm — cho dòng áp phê (đổi độ lệch
  /// ngắm ra đầu cơ ở đúng quãng này).
  final double contactDistance;

  /// Điểm của phương án (thấp là tốt), để công cụ dò và test đọc.
  final double total;

  ShotTrace get trace => aimed.trace;
}
