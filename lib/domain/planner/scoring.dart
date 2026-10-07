import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

double bankPenaltyFor(int railCount) => railCount == 0
    ? 0
    : (railCount == 1 ? bankPenaltyOneRail : bankPenaltyManyRails);

/// Kiểu đánh cộng áp phê: càng nhiều thông số xoáy càng nhiều sai số (PRD §8).
double techPenaltyFor(Stroke stroke, SideSpin spin) {
  final base = switch (stroke) {
    Stroke.stun => techPenaltyStun,
    Stroke.follow => techPenaltyFollow,
    Stroke.draw => techPenaltyDraw,
  };
  if (spin.isNone) return base;
  return base + (spin.tips <= 0.5 ? sidePenaltyHalfTip : sidePenaltyOneTip);
}

double powerPenaltyFor(double power) => power * powerPenaltyPerPercent;

/// Góc cắt dễ nhất từ [from] để đánh [ball], bỏ lỗ bị [obstacles] chắn;
/// null khi không lỗ nào (spec mục 4).
double? bestAngleFrom(Vec2 from, Vec2 ball, Iterable<Vec2> obstacles,
        {TableSpec table = TableSpec.nineFoot}) =>
    bestPocket(cue: from, object: ball, others: obstacles, table: table)?.angle;

/// Điểm của một phương án, từng khoản (spec mục 5). Càng thấp càng tốt.
class OptionScore {
  const OptionScore({
    required this.position,
    this.robustDiff1,
    this.diff2,
    required this.bank,
    required this.tech,
    required this.power,
    required this.distance,
  });

  /// max(robustDiff1, diff2), hoặc robustDiff1; 0 khi là bi cuối.
  final double position;
  final double? robustDiff1;
  final double? diff2;
  final double bank;
  final double tech;
  final double power;

  /// Quãng bi ảo → điểm dừng, đã nhân [distanceWeight].
  final double distance;

  double get total => position + bank + tech + power + distance;
}

class ScoredOption {
  const ScoredOption(this.key, this.aimed, this.score);
  final ShotKey key;
  final AimedShot aimed;
  final OptionScore score;
}

/// Mọi thứ cần để chấm phương án cho một cặp bi–lỗ đã chọn.
class ScoringContext {
  ScoringContext({
    required this.geometry,
    required this.after,
    required this.lookup,
    required this.next,
  });

  /// Cặp bi–lỗ của bước này.
  final ShotGeometry geometry;

  /// Bi còn trên bàn sau khi bi này vào lỗ — cũng là bi chắn của cú này.
  final List<PlacedBall> after;
  final ShotLookup lookup;
  final CandidateFinder next;

  TableSpec get table => next.table;
  late final List<Vec2> obstacles = [for (final b in after) b.pos];

  /// Còn bi để đánh sau bi này không. 8 bi: bi đối thủ không tính.
  late final bool hasNext = legalTargetsAmong(next.game, after).isNotEmpty;

  /// Góc dễ nhất cho bi kế tiếp từ điểm dừng của [aimed]; mức nào quá giờ,
  /// chết cái, bị chắn hay bi mục tiêu không vào thì [blockedAngle].
  double angleAt(AimedShot? aimed) {
    if (aimed == null ||
        rejectionOf(aimed, geometry.pocket, obstacles, table: table) != null) {
      return blockedAngle;
    }
    return next.easiest(aimed.trace.cueEnd, after)?.angle ?? blockedAngle;
  }

  /// Nhìn trước bi thứ hai: cú kế tiếp là Đánh đứng bi [lookaheadPower] vào
  /// lỗ dễ nhất, mô phỏng thật. null khi sau bi kế tiếp không còn bi nào.
  double? lookahead(Candidate first) {
    final after2 = [for (final b in after) if (b.number != first.ball.number) b];
    if (legalTargetsAmong(next.game, after2).isEmpty) return null;
    final a = lookup(shotKey(first.geometry, Stroke.stun, lookaheadPower));
    if (a == null ||
        rejectionOf(a, first.geometry.pocket, [for (final b in after2) b.pos], table: table) !=
            null) {
      return blockedAngle;
    }
    return next.easiest(a.trace.cueEnd, after2)?.angle ?? blockedAngle;
  }
}

/// Chấm một phương án đã qua vòng loại (spec mục 5). null khi từ điểm dừng
/// không lỗ nào khả thi cho bi kế tiếp — vị trí đó giết cú sau (PRD §5.3).
OptionScore? scoreOption(ScoringContext c, ShotKey key, AimedShot aimed) {
  final trace = aimed.trace;
  final bank = bankPenaltyFor(trace.cueRailCount);
  final tech = techPenaltyFor(key.stroke, key.spin);
  final power = powerPenaltyFor(key.power);
  if (!c.hasNext) {
    return OptionScore(position: 0, bank: bank, tech: tech, power: power, distance: 0);
  }
  final first = c.next.easiest(trace.cueEnd, c.after);
  if (first == null) return null;
  var robust = first.angle;
  for (final delta in const [-powerJitter, powerJitter]) {
    robust = math.max(robust, c.angleAt(c.lookup(withPower(key, jitteredPower(key.power, delta)))));
  }
  final diff2 = c.lookahead(first);
  return OptionScore(
    position: diff2 == null ? robust : math.max(robust, diff2),
    robustDiff1: robust,
    diff2: diff2,
    bank: bank,
    tech: tech,
    power: power,
    distance: c.geometry.ghost.distanceTo(trace.cueEnd) * distanceWeight,
  );
}

/// Mô phỏng và chấm các phương án theo đúng thứ tự [keys]; chỉ trả phương
/// án dùng được.
List<ScoredOption> scoreTier(ScoringContext c, Iterable<ShotKey> keys) {
  final out = <ScoredOption>[];
  for (final key in keys) {
    final aimed = c.lookup(key);
    if (aimed == null) continue;
    if (rejectionOf(aimed, c.geometry.pocket, c.obstacles, table: c.table) != null) continue;
    final score = scoreOption(c, key, aimed);
    if (score != null) out.add(ScoredOption(key, aimed, score));
  }
  return out;
}

/// Điểm thấp nhất; bằng điểm thì giữ phương án thử trước, để tất định.
ScoredOption? bestOf(List<ScoredOption> options) {
  ScoredOption? best;
  for (final o in options) {
    final current = best;
    if (current == null || o.score.total < current.score.total) best = o;
  }
  return best;
}

typedef ToleranceCounts = ({int good, int fair, int bad});

/// Độ chịu sai số lực, chỉ để hiển thị (spec mục 5.4): [toleranceSamples]
/// mức đều nhau từ lực − [powerJitter] tới lực + [powerJitter], cùng hàm
/// mô phỏng và chấm với lúc chọn phương án.
ToleranceCounts toleranceOf(ScoringContext c, ShotKey key) {
  var good = 0, fair = 0, bad = 0;
  const span = 2 * powerJitter;
  for (var k = 0; k < toleranceSamples; k++) {
    final p = jitteredPower(key.power, -powerJitter + k * span / (toleranceSamples - 1));
    final angle = c.angleAt(c.lookup(withPower(key, p)));
    if (angle <= zoneGood) {
      good++;
    } else if (angle <= zoneFair) {
      fair++;
    } else {
      bad++;
    }
  }
  return (good: good, fair: fair, bad: bad);
}

enum ZoneLevel { good, fair }

class ZoneCell {
  const ZoneCell(this.center, this.level);
  final Vec2 center;
  final ZoneLevel level;
}

/// Lưới vùng điều tốt (spec mục 7.1): ô [zoneCell] cm; ô xanh nếu góc dễ
/// nhất cho bi kế tiếp ≤ [zoneGood], vàng nếu ≤ [zoneFair]; bỏ ô xấu hơn,
/// ô không có đường, ô đè lên bi. Cùng [CandidateFinder.easiest] với lúc chấm.
List<ZoneCell> zoneGrid({required List<PlacedBall> after, required CandidateFinder next}) {
  if (legalTargetsAmong(next.game, after).isEmpty) return const [];
  final cells = <ZoneCell>[];
  for (var x = zoneCell / 2; x < next.table.length; x += zoneCell) {
    _zoneRow(x, after, next, cells);
  }
  return cells;
}

/// Một hàng ô của [zoneGrid] (cùng x), thêm vào [cells].
void _zoneRow(double x, List<PlacedBall> after, CandidateFinder next, List<ZoneCell> cells) {
  final table = next.table;
  for (var y = zoneCell / 2; y < table.width; y += zoneCell) {
    final p = Vec2(x, y);
    if (!table.contains(p)) continue;
    if (after.any((b) => b.pos.distanceTo(p) < table.ballDiameter)) continue;
    final angle = next.easiest(p, after)?.angle;
    if (angle == null) continue;
    if (angle <= zoneGood) {
      cells.add(ZoneCell(p, ZoneLevel.good));
    } else if (angle <= zoneFair) {
      cells.add(ZoneCell(p, ZoneLevel.fair));
    }
  }
}

/// [zoneGrid] tính vài hàng mỗi khung hình: tính một mạch thì khung hình
/// bước 1 hiện ra bị rớt. Cùng thứ tự hàng, cùng hàm một hàng, nên xong
/// thì [cells] đúng y [zoneGrid]; ngân sách chỉ quyết định *khi nào* dừng.
class ZoneGridJob {
  ZoneGridJob({required this.after, required this.next})
      : _done = legalTargetsAmong(next.game, after).isEmpty;

  final List<PlacedBall> after;
  final CandidateFinder next;
  final _cells = <ZoneCell>[];
  double _x = zoneCell / 2;
  bool _done;

  bool get isDone => _done;

  /// Các ô đã tính tới giờ.
  List<ZoneCell> get cells => List.unmodifiable(_cells);

  /// Làm từng hàng tới khi hết [budget] (hoặc đủ [maxRows] hàng, cho
  /// test), luôn ít nhất một hàng. Không bắt đầu hàng mới nếu hàng dài
  /// nhất của lát này không còn vừa ngân sách.
  void step({required Duration budget, int? maxRows}) {
    final clock = Stopwatch()..start();
    var rows = 0;
    var longest = Duration.zero;
    while (!_done) {
      final started = clock.elapsed;
      _zoneRow(_x, after, next, _cells);
      _x += zoneCell;
      rows++;
      if (_x >= next.table.length) _done = true;
      final row = clock.elapsed - started;
      if (row > longest) longest = row;
      if (maxRows != null && rows >= maxRows) break;
      if (clock.elapsed + longest > budget) break;
    }
  }
}
