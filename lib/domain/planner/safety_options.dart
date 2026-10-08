import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Bàn lúc phải thủ (spec 3.1–3.2): bi cái, các bi còn lại, bi hợp lệ, và
/// có bị đui không.
class SafetyContext {
  SafetyContext({
    required this.game,
    required this.cue,
    required List<PlacedBall> balls,
    this.table = TableSpec.nineFoot,
  }) : balls = List.unmodifiable([...balls]..sort((a, b) => a.number.compareTo(b.number)));

  final GameType game;
  final Vec2 cue;
  final List<PlacedBall> balls;
  final TableSpec table;

  /// 9 / 10 bi: bi số nhỏ nhất. 8 bi: mọi bi nhóm mình, hết thì bi 8.
  late final List<PlacedBall> legal = legalTargetsAmong(game, balls);

  /// Bi hợp lệ nhìn thấy được (một trong ba đường không bị chắn).
  late final List<PlacedBall> visible = [
    for (final t in legal)
      if (canSee(cue, t.pos, obstaclesFor(t, balls), table: table)) t,
  ];

  /// Đui khi mọi bi hợp lệ đều bị chắn (8 bi: mọi bi nhóm mình).
  bool get snookered => visible.isEmpty;

  SafetyReason get reason => snookered ? SafetyReason.snookered : SafetyReason.noPot;

  /// Bi chắn khi đánh bi [ballNum].
  List<Vec2> obstaclesOf(int ballNum) =>
      [for (final b in balls) if (b.number != ballNum) b.pos];

  /// Bàn sau cú thủ: bi [ballNum] ở [to], các bi khác không đổi (bi thứ ba
  /// không tham gia va chạm, PRD §8).
  List<PlacedBall> after(int ballNum, Vec2 to) => [
        for (final b in balls)
          b.number == ballNum ? PlacedBall(number: b.number, pos: to, role: b.role) : b,
      ];
}

/// Một phương án thủ, chưa mô phỏng (spec 3.3–3.4).
class SafetyOption {
  const SafetyOption({
    required this.kind,
    required this.ballNum,
    required this.ball,
    this.rails = const [],
    required this.thickness,
    required this.side,
    required this.lateral,
    required this.stroke,
    this.spin = const SideSpin.none(),
    required this.power,
    required this.initialAim,
    required this.contact,
  });

  final SafetyKind kind;
  final int ballNum;
  final Vec2 ball;

  /// Chuỗi băng của A băng; rỗng khi trực tiếp.
  final List<Rail> rails;
  final double thickness;
  final ThicknessSide side;

  /// Độ lệch ngang mục tiêu lúc chạm, cm (dương là trái).
  final double lateral;
  final Stroke stroke;
  final SideSpin spin;
  final double power;

  /// Hướng cơ hình học (bi ảo hoặc soi gương), rad — điểm bắt đầu dò.
  final double initialAim;

  /// Bi ảo hình học.
  final Vec2 contact;

  @override
  String toString() => 'SafetyOption(${kind.name} bi $ballNum ${rails.map((r) => r.name).join('-')} '
      '$thickness ${side.name} ${stroke.name} $spin ${power.round()}%)';
}

/// Phương án thủ trực tiếp vào [target] với độ dày [thickness] lệch [side];
/// null khi không dựng được bi ảo. Không kiểm đường chắn — [openContacts]
/// đã lọc trước.
SafetyOption? directOption(SafetyContext c, PlacedBall target, double thickness,
    ThicknessSide side, Stroke stroke, SideSpin spin, double power) {
  final lateral = contactLateral(thickness, side, table: c.table);
  final g = directContact(c.cue, target.pos, lateral, table: c.table);
  if (g == null) return null;
  return SafetyOption(
    kind: SafetyKind.direct,
    ballNum: target.number,
    ball: target.pos,
    thickness: thickness,
    side: side,
    lateral: lateral,
    stroke: stroke,
    spin: spin,
    power: power,
    initialAim: g.aim,
    contact: g.contact,
  );
}
