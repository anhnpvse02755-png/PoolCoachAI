import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_collision.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cloth.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Một cú đánh: hai bi, hướng cơ, lực, điểm đặt cơ, độ dốc cơ.
class ShotInput {
  const ShotInput({
    required this.cue,
    required this.object,
    required this.aimAngle,
    required this.power,
    this.verticalOffset = 0,
    this.spin = const SideSpin.none(),
    this.elevation = 0,
    this.table = TableSpec.nineFoot,
  });

  final Vec2 cue;
  final Vec2 object;

  /// Hướng cơ trên mặt bàn, radian.
  final double aimAngle;

  /// %.
  final double power;

  /// `b`, cm, dương là trên tâm.
  final double verticalOffset;
  final SideSpin spin;

  /// Độ dốc cơ, radian.
  final double elevation;
  final TableSpec table;

  ShotInput copyWith({double? aimAngle, double? verticalOffset}) => ShotInput(
        cue: cue,
        object: object,
        aimAngle: aimAngle ?? this.aimAngle,
        power: power,
        verticalOffset: verticalOffset ?? this.verticalOffset,
        spin: spin,
        elevation: elevation,
        table: table,
      );
}

enum ShotBall { cue, object }

/// Một lần chạm băng: bi nào, ở đâu (đúng trên biên), băng nào, và có
/// sau va chạm bi cái–bi mục tiêu không.
class RailHit {
  const RailHit({
    required this.ball,
    required this.pos,
    required this.rail,
    required this.afterContact,
  });

  final ShotBall ball;
  final Vec2 pos;
  final Rail rail;
  final bool afterContact;

  @override
  bool operator ==(Object other) =>
      other is RailHit &&
      other.ball == ball &&
      other.pos == pos &&
      other.rail == rail &&
      other.afterContact == afterContact;

  @override
  int get hashCode => Object.hash(ball, pos, rail, afterContact);
}

/// Kết quả mô phỏng một cú đánh (spec mục 4.5).
class ShotTrace {
  const ShotTrace({
    required this.cueBefore,
    required this.cueAfter,
    required this.objectPath,
    required this.contactCue,
    required this.rails,
    required this.cuePocket,
    required this.objectPocket,
    required this.cueEnd,
  });

  /// Bi cái từ lúc đánh tới lúc chạm bi mục tiêu.
  final List<Vec2> cueBefore;

  /// Bi cái sau va chạm tới khi dừng hoặc rơi lỗ; rỗng nếu trượt bi.
  final List<Vec2> cueAfter;

  /// Bi mục tiêu từ chỗ đứng tới khi dừng hoặc rơi lỗ.
  final List<Vec2> objectPath;

  /// Tâm bi cái lúc chạm (Bi ảo thật); null nếu trượt bi mục tiêu.
  final Vec2? contactCue;

  /// Mọi lần chạm băng, theo thứ tự thời gian.
  final List<RailHit> rails;

  /// Chết cái: lỗ bi cái rơi vào.
  final Pocket? cuePocket;

  /// Lỗ bi mục tiêu rơi vào; null là không vào.
  final Pocket? objectPocket;

  /// Điểm dừng bi cái — đúng đối tượng cuối của [cueAfter] (hoặc của
  /// [cueBefore] khi trượt bi). Planner dùng làm `cbFrom`, không tính lại.
  final Vec2 cueEnd;

  /// Bi cái chạm băng sau va chạm.
  bool get bankUsed => cueRailCount > 0;

  /// Số lần bi cái chạm băng sau va chạm.
  int get cueRailCount =>
      rails.where((h) => h.ball == ShotBall.cue && h.afterContact).length;
}

/// Mô phỏng chạy quá `maxSimTime` — lỗi của lõi, không phải kết quả.
class SimulationTimeout implements Exception {
  const SimulationTimeout(this.input);
  final ShotInput input;

  @override
  String toString() => 'SimulationTimeout: quá $maxSimTime s';
}

/// Hai bi ngay quanh lúc chạm, cho `aimShot` dò.
class ContactProbe {
  const ContactProbe({required this.cueAtContact, required this.objectAfter});

  /// Bi cái ngay trước va chạm.
  final BallState cueAtContact;

  /// Bi mục tiêu ngay sau va chạm.
  final BallState objectAfter;
}

/// Mô phỏng tới khi cả hai bi đứng hẳn hoặc rơi lỗ (spec mục 4.5).
///
/// Tất định: cùng [input] thì cùng trace. [onStep] (cho test) nhận trạng
/// thái hai bi sau mỗi bước.
ShotTrace simulateShot(
  ShotInput input, {
  void Function(BallState cue, BallState object)? onStep,
}) {
  final run = _Run(input, record: true, onStep: onStep);
  run.go(untilContact: false);
  return run.trace();
}

/// Chỉ mô phỏng tới lúc bi cái chạm thẳng bi mục tiêu; null nếu trượt
/// bi, rơi lỗ, hoặc chạm băng trước (cú dội băng không phải cú đang dò).
///
/// Rẻ hơn [simulateShot] nhiều, nên `aimShot` dùng nó để dò.
ContactProbe? probeContact(ShotInput input) {
  final run = _Run(input, record: false);
  run.go(untilContact: true);
  return run.rails.isEmpty ? run.probe : null;
}

/// Chỉ cần biết bi cái có rơi lỗ không: mô phỏng đủ nhưng không ghi
/// đường đi. Cùng kết quả với `simulateShot(input).cuePocket`.
Pocket? simulateCuePocket(ShotInput input) {
  final run = _Run(input, record: false);
  run.go(untilContact: false);
  return run.cue.pocket;
}

class _Ball {
  _Ball(this.state, {required this.moving});

  BallState state;
  bool moving;
  Pocket? pocket;
  List<Vec2> samples = [];

  /// Chỉ số các điểm phải giữ khi rút gọn (điểm chạm băng, chạm bi, lỗ).
  List<int> keep = [];

  bool get inPlay => pocket == null;

  void record(Vec2 p, {bool pinned = false}) {
    if (pinned) keep.add(samples.length);
    samples.add(p);
  }
}

enum _Event { none, balls, rail }

class _Run {
  _Run(this.input, {required this.record, this.onStep})
      : table = input.table,
        radius = input.table.radius,
        cue = _Ball(
          strikeCue(
            pos: input.cue,
            aimAngle: input.aimAngle,
            power: input.power,
            verticalOffset: input.verticalOffset,
            spin: input.spin,
            elevation: input.elevation,
            table: input.table,
          ),
          moving: input.power > 0,
        ),
        object = _Ball(BallState(pos: input.object), moving: false) {
    if (record) {
      cue.record(input.cue);
      object.record(input.object);
    }
  }

  final ShotInput input;
  final bool record;
  final void Function(BallState, BallState)? onStep;
  final TableSpec table;
  final double radius;
  final _Ball cue;
  final _Ball object;

  /// Đường bi cái trước va chạm; khi đã chạm thì [cue] ghi tiếp phần sau.
  _Ball? before;
  Vec2? contact;
  ContactProbe? probe;
  final rails = <RailHit>[];

  void go({required bool untilContact}) {
    var steps = 0;
    final maxSteps = (maxSimTime / timeStep).round();
    while (cue.moving || object.moving) {
      if (steps++ >= maxSteps) throw SimulationTimeout(input);
      _step();
      if (untilContact && (contact != null || rails.isNotEmpty)) return;
      for (final ball in [cue, object]) {
        if (!ball.moving) continue;
        if (ball.state.isStopped) {
          ball.state = BallState(pos: ball.state.pos);
          ball.moving = false;
        }
        if (record) ball.record(ball.state.pos);
      }
      onStep?.call(cue.state, object.state);
    }
  }

  void _step() {
    var left = timeStep;
    // Một bước có thể chứa vài sự kiện (chạm băng rồi chạm bi); trần
    // này chỉ chặn vòng lặp vô hạn nếu số học hỏng.
    for (var events = 0; left > 0 && events < 8; events++) {
      final c1 = cue.moving ? _advance(cue.state, left) : cue.state;
      final o1 = object.moving ? _advance(object.state, left) : object.state;

      var f = 1.0;
      var event = _Event.none;
      _Ball? railBall;
      Rail? rail;

      if (cue.inPlay && object.inPlay) {
        final fb = _ballsMeet(cue.state, c1.pos, object.state, o1.pos);
        if (fb != null && fb < f) {
          f = fb;
          event = _Event.balls;
        }
      }
      for (final (ball, end) in [(cue, c1), (object, o1)]) {
        if (!ball.moving) continue;
        final hit = _railCrossing(ball.state, end.pos);
        if (hit != null && hit.$1 < f) {
          f = hit.$1;
          event = _Event.rail;
          railBall = ball;
          rail = hit.$2;
        }
      }

      if (f == 1) {
        cue.state = c1;
        object.state = o1;
        left = 0;
      } else {
        final dt = left * f;
        if (cue.moving) cue.state = _advance(cue.state, dt);
        if (object.moving) object.state = _advance(object.state, dt);
        left -= dt;
      }

      // Lọt vùng lỗ thì rơi lỗ trước khi xét băng hay bi kia.
      for (final ball in [cue, object]) {
        if (ball.moving) _checkPocket(ball);
      }

      switch (event) {
        case _Event.none:
          break;
        case _Event.balls:
          if (cue.inPlay && object.inPlay) _collide();
        case _Event.rail:
          final ball = railBall!;
          if (ball.inPlay) _bounce(ball, rail!);
      }
      for (final ball in [cue, object]) {
        if (ball.moving) _keepOnTable(ball);
      }
    }
  }

  BallState _advance(BallState s, double dt) =>
      clothStep(s, dt, radius: radius);

  /// Phần bước (0–1) tại đó hai tâm bi cách nhau đúng 2R, coi chuyển
  /// động tương đối trong bước là thẳng; null nếu không lao vào nhau.
  double? _ballsMeet(BallState c0, Vec2 c1, BallState o0, Vec2 o1) {
    final d0 = o0.pos - c0.pos;
    final delta = (o1 - c1) - d0;
    final a = delta.dot(delta);
    final b = 2 * d0.dot(delta);
    final c = d0.dot(d0) - 4 * radius * radius;
    if (b >= 0 || a == 0) return null;
    // Đã chạm sẵn (đặt sát nhau, hoặc vừa va xong): chỉ va khi vận tốc
    // thật sự lao vào nhau. Xét theo quãng đi trong bước thì một bi lăn
    // sát qua bi kia có thể "lao vào" vì sai số, rồi kẹt mãi ở f = 0.
    if (c <= 0) return (c0.vel - o0.vel).dot(d0) > 0 ? 0 : null;
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null;
    final f = (-b - math.sqrt(disc)) / (2 * a);
    return f <= 1 ? f : null;
  }

  /// Phần bước (0–1) tại đó tâm bi chạm biên, và băng nào.
  ///
  /// Bi đang nằm trên biên mà vận tốc không lao vào băng (chạy sát băng,
  /// swerve ép ra ngoài) thì không phải va băng: [_keepOnTable] giữ nó
  /// lại trên biên.
  (double, Rail)? _railCrossing(BallState s0, Vec2 p1) {
    final p0 = s0.pos;
    (double, Rail)? best;
    void consider(double from, double to, double bound, Rail rail) {
      if (from == bound && s0.vel.dot(rail.outward) <= 0) return;
      final f = ((bound - from) / (to - from)).clamp(0.0, 1.0);
      if (best == null || f < best!.$1) best = (f, rail);
    }

    if (p1.x > table.maxX) consider(p0.x, p1.x, table.maxX, Rail.right);
    if (p1.x < table.minX) consider(p0.x, p1.x, table.minX, Rail.left);
    if (p1.y > table.maxY) consider(p0.y, p1.y, table.maxY, Rail.bottom);
    if (p1.y < table.minY) consider(p0.y, p1.y, table.minY, Rail.top);
    return best;
  }

  /// Bi chạy sát băng mà bị đẩy ra ngoài biên: kéo về đúng biên và bỏ
  /// phần vận tốc chĩa ra ngoài — băng chặn lại, không có cú va.
  void _keepOnTable(_Ball ball) {
    final s = ball.state;
    if (table.contains(s.pos)) return;
    var vel = s.vel;
    for (final rail in Rail.values) {
      final out = vel.dot(rail.outward);
      final beyond = switch (rail) {
        Rail.left => s.pos.x < table.minX,
        Rail.right => s.pos.x > table.maxX,
        Rail.top => s.pos.y < table.minY,
        Rail.bottom => s.pos.y > table.maxY,
      };
      if (beyond && out > 0) vel = vel - rail.outward * out;
    }
    ball.state = s.copyWith(pos: table.clamp(s.pos), vel: vel);
  }

  void _checkPocket(_Ball ball) {
    final s = ball.state;
    for (final pocket in Pocket.values) {
      final at = table.pocketPosition(pocket);
      // Bi nằm sẵn trong vùng lỗ mà đang đi ra thì chưa rơi: ngoài bàn
      // thật bi đó đang nằm trên mép lỗ.
      if (s.pos.distanceTo(at) <= table.captureRadius(pocket) &&
          s.vel.dot(at - s.pos) > 0) {
        ball.pocket = pocket;
        ball.moving = false;
        ball.state = BallState(pos: at);
        if (record) ball.record(at, pinned: true);
        return;
      }
    }
  }

  void _bounce(_Ball ball, Rail rail) {
    final p = ball.state.pos;
    // Điểm chạm nằm đúng trên biên, không lệch vì số học.
    final snapped = switch (rail) {
      Rail.left => Vec2(table.minX, p.y),
      Rail.right => Vec2(table.maxX, p.y),
      Rail.top => Vec2(p.x, table.minY),
      Rail.bottom => Vec2(p.x, table.maxY),
    };
    ball.state = cushionImpact(ball.state.copyWith(pos: snapped), rail,
        radius: radius);
    rails.add(RailHit(
      ball: ball == cue ? ShotBall.cue : ShotBall.object,
      pos: snapped,
      rail: rail,
      afterContact: contact != null,
    ));
    if (record) ball.record(snapped, pinned: true);
  }

  void _collide() {
    final cueBefore = cue.state;
    final (c, o) = collideBalls(cue.state, object.state, radius: radius);
    if (identical(c, cue.state)) return;
    cue.state = c;
    object.state = o;
    object.moving = true;
    cue.moving = true;
    if (contact != null) return;
    final at = cueBefore.pos;
    contact = at;
    probe = ContactProbe(cueAtContact: cueBefore, objectAfter: o);
    if (record) {
      cue.record(at, pinned: true);
      // Từ đây bi cái ghi vào đường sau va chạm, bắt đầu đúng tại bi ảo.
      before = _Ball(cueBefore, moving: false)
        ..samples = cue.samples
        ..keep = cue.keep;
      cue
        ..samples = [at]
        ..keep = [0];
    }
  }

  ShotTrace trace() {
    final beforeBall = before;
    final cueBefore = _simplify(beforeBall ?? cue);
    final cueAfter = beforeBall == null ? const <Vec2>[] : _simplify(cue);
    return ShotTrace(
      cueBefore: cueBefore,
      cueAfter: cueAfter,
      objectPath: _simplify(object),
      contactCue: contact,
      rails: List.unmodifiable(rails),
      cuePocket: cue.pocket,
      objectPocket: object.pocket,
      cueEnd: cueAfter.isEmpty ? cueBefore.last : cueAfter.last,
    );
  }
}

/// Rút gọn chuỗi điểm mỗi bước: bỏ điểm lệch khỏi đoạn thẳng nối hai
/// điểm giữ lại dưới `pathTolerance` (Douglas–Peucker). Đường thẳng còn
/// hai điểm, đường cong giữ đủ để vẽ mượt. Điểm chạm băng, điểm chạm bi
/// và hai đầu giữ nguyên đối tượng — `cueEnd` dựa vào điều đó.
List<Vec2> _simplify(_Ball ball) {
  final pts = ball.samples;
  if (pts.length <= 2) return List.unmodifiable(pts);
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = true;
  keep[pts.length - 1] = true;
  for (final i in ball.keep) {
    keep[i] = true;
  }
  var start = 0;
  for (var i = 1; i < pts.length; i++) {
    if (!keep[i]) continue;
    _douglasPeucker(pts, start, i, keep);
    start = i;
  }
  return List.unmodifiable([
    for (var i = 0; i < pts.length; i++)
      if (keep[i]) pts[i],
  ]);
}

void _douglasPeucker(List<Vec2> pts, int first, int last, List<bool> keep) {
  final stack = <(int, int)>[(first, last)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    if (b - a < 2) continue;
    var worst = -1;
    var worstDist = pathTolerance;
    for (var i = a + 1; i < b; i++) {
      final d = distanceToSegment(pts[i], pts[a], pts[b]);
      if (d >= worstDist) {
        worstDist = d;
        worst = i;
      }
    }
    if (worst < 0) continue;
    keep[worst] = true;
    stack
      ..add((a, worst))
      ..add((worst, b));
  }
}
