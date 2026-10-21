import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/evaluation.dart';
import 'package:poolcoachai/domain/coach/grading.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/rng.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/sim_cache.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

/// Điểm đặt bi (foot spot): bi cái không nằm ở đây (spec mục 8.3).
Vec2 footSpot(TableSpec table) => Vec2(table.length * 3 / 4, table.width / 2);

double _quantize(double v) => (v / coachPositionQuantum).round() * coachPositionQuantum;

/// Vị trí hợp lệ cho một bi mới (spec mục 8.3): trong mặt chơi, cách mọi bi
/// đã đặt ≥ đường kính + [coachBallGap], cách mọi điểm lỗ ≥
/// [coachMinPocketClearance].
bool validSpot(Vec2 p, Iterable<Vec2> placed, TableSpec table) {
  if (!table.contains(p)) return false;
  final gap = table.ballDiameter + coachBallGap;
  for (final q in placed) {
    if (p.distanceTo(q) < gap) return false;
  }
  for (final pocket in Pocket.values) {
    if (p.distanceTo(table.pocketPosition(pocket)) < coachMinPocketClearance) return false;
  }
  return true;
}

/// Một điểm ngẫu nhiên: xác suất [coachFrozenRailChance] sát băng (tâm cách
/// mép băng nửa bi, chỉ làm tròn dọc theo băng), còn lại tự do trên bàn.
Vec2 _randomSpot(CoachRng rng, TableSpec table) {
  if (rng.chance(coachFrozenRailChance)) {
    final rail = rng.intIn(0, 3);
    final along = rng.nextDouble();
    return switch (rail) {
      0 => Vec2(_quantize(table.minX + along * (table.maxX - table.minX)), table.minY),
      1 => Vec2(_quantize(table.minX + along * (table.maxX - table.minX)), table.maxY),
      2 => Vec2(table.minX, _quantize(table.minY + along * (table.maxY - table.minY))),
      _ => Vec2(table.maxX, _quantize(table.minY + along * (table.maxY - table.minY))),
    };
  }
  return Vec2(
    _quantize(rng.range(table.minX, table.maxX)),
    _quantize(rng.range(table.minY, table.maxY)),
  );
}

/// Đặt một bi ở chỗ hợp lệ, thử tối đa vài lần; null khi không được.
Vec2? _place(CoachRng rng, List<Vec2> placed, TableSpec table, {Vec2 Function()? near}) {
  for (var i = 0; i < 30; i++) {
    final raw = near?.call() ?? _randomSpot(rng, table);
    final p = Vec2(_quantize(raw.x), _quantize(raw.y));
    if (validSpot(p, placed, table)) return p;
  }
  return null;
}

/// Điểm trên đường bi [ball] → lỗ [pocket], cách điểm lỗ [distance] cm.
Vec2 _onPocketLine(Vec2 ball, Pocket pocket, double distance, TableSpec table) {
  final at = table.pocketPosition(pocket);
  return at + (ball - at).normalized * distance;
}

/// Lỗ gần bi [ball] nhất (theo khoảng cách tới điểm lỗ); hoà thì lỗ đứng trước.
Pocket nearestPocket(Vec2 ball, TableSpec table) {
  var best = Pocket.values.first;
  for (final p in Pocket.values) {
    if (ball.distanceTo(table.pocketPosition(p)) <
        ball.distanceTo(table.pocketPosition(best))) {
      best = p;
    }
  }
  return best;
}

/// Kết quả hình học của bi phải chạm ở cả sáu lỗ.
Map<Pocket, ShotResult> _pocketResults(TableSetup s) {
  final target = legalTargetsAmong(s.game, s.balls).first;
  final others = obstaclesFor(target, s.balls);
  return {
    for (final p in Pocket.values)
      p: evaluateShot(cue: s.cue, object: target.pos, pocket: p, others: others, table: s.table),
  };
}

/// Điều kiện hình học của từng nhóm (spec mục 8.5, lượt hình học). [bands]
/// null là không xét dải góc cắt (thư viện không có độ khó).
bool geometryFitsTopic(TableSetup s, CoachTopic topic, {List<DifficultyBand>? bands}) {
  final target = legalTargetsAmong(s.game, s.balls).first;
  final others = obstaclesFor(target, s.balls);
  final best = bestPocket(cue: s.cue, object: target.pos, others: others, table: s.table);
  final seen = canSee(s.cue, target.pos, others, table: s.table);
  switch (topic) {
    case CoachTopic.safety:
      return seen && best == null;
    case CoachTopic.kick:
      return !seen && best == null;
    case CoachTopic.position:
      if (best == null) return false;
      if (bands != null && !bands.contains(bandFor(best.angle))) return false;
      return s.balls.length - 1 >= 2;
    case CoachTopic.aiming:
      if (best == null) return false;
      if (bands != null && !bands.contains(bandFor(best.angle))) return false;
      final results = _pocketResults(s);
      final makeable = results.values.whereType<Makeable>().length;
      final hard = results.values.whereType<Unmakeable>().where((u) =>
          u.reason == UnmakeableReason.cueBlocked ||
          u.reason == UnmakeableReason.objectBlocked ||
          u.reason == UnmakeableReason.tooThin);
      return makeable >= 2 &&
          hard.isNotEmpty &&
          best.pocket != nearestPocket(target.pos, s.table);
  }
}

/// Lượt hình học (spec mục 8.5): đề xuất một thế bàn 9 bi cho [topic] ở độ
/// khó [difficulty], thử tới [coachGeometryTries] lần; null khi không được.
/// Phòng thủ và A băng sinh có chủ đích: đặt bi chắn lên đường bi → lỗ, hay
/// lên đường bi cái → bi, không đợi gặp may.
TableSetup? proposeLayout(CoachRng rng, CoachTopic topic, CoachDifficulty difficulty,
    {TableSpec table = TableSpec.nineFoot}) {
  for (var attempt = 0; attempt < coachGeometryTries; attempt++) {
    final s = _proposeOnce(rng, topic, difficulty, table);
    if (s != null && geometryFitsTopic(s, topic, bands: _bandsFor(topic, difficulty))) return s;
  }
  return null;
}

List<DifficultyBand>? _bandsFor(CoachTopic topic, CoachDifficulty d) =>
    topic == CoachTopic.aiming || topic == CoachTopic.position ? coachCutBands(d) : null;

TableSetup? _proposeOnce(CoachRng rng, CoachTopic topic, CoachDifficulty d, TableSpec table) {
  final count = switch (topic) {
    CoachTopic.aiming || CoachTopic.position => () {
        final c = coachBallCount(d);
        return rng.intIn(c.min, c.max);
      }(),
    CoachTopic.safety || CoachTopic.kick => () {
        final c = coachBlockerCount(d);
        return 1 + rng.intIn(c.min, c.max);
      }(),
  };
  final placed = <Vec2>[];
  final foot = footSpot(table);
  final target = _place(rng, placed, table);
  if (target == null) return null;
  placed.add(target);
  // Bi cái: không trên điểm đặt bi.
  final cue = _place(rng, [...placed, foot], table);
  if (cue == null) return null;
  placed.add(cue);

  final balls = <Vec2>[];
  switch (topic) {
    case CoachTopic.aiming:
      // Một bi chắn một đường bi → lỗ, để có lỗ bị chắn.
      final pocket = Pocket.values[rng.intIn(0, Pocket.values.length - 1)];
      final b = _place(rng, placed, table,
          near: () => _onPocketLine(target, pocket, rng.range(14, 40), table));
      if (b == null) return null;
      balls.add(b);
      placed.add(b);
    case CoachTopic.safety:
      // Chắn mọi lỗ đánh được của bi phải chạm.
      final open = [
        for (final p in Pocket.values)
          if (evaluateShot(cue: cue, object: target, pocket: p, others: balls, table: table)
              is Makeable)
            p,
      ];
      for (final p in open) {
        if (balls.length >= count - 1) return null;
        final b = _place(rng, placed, table,
            near: () => _onPocketLine(target, p, rng.range(13, 30), table));
        if (b == null) return null;
        balls.add(b);
        placed.add(b);
      }
    case CoachTopic.kick:
      // Một bi giữa đường bi cái → bi phải chạm.
      final t = rng.range(0.3, 0.7);
      final b = _place(rng, placed, table,
          near: () => cue + (target - cue) * t);
      if (b == null) return null;
      balls.add(b);
      placed.add(b);
    case CoachTopic.position:
      break;
  }
  while (balls.length < count - 1) {
    // Phòng thủ và A băng: bi chắn quanh bi phải chạm; còn lại tự do.
    final b = switch (topic) {
      CoachTopic.safety || CoachTopic.kick => _place(rng, placed, table,
          near: () => target + Vec2(rng.range(-40, 40), rng.range(-40, 40))),
      _ => _place(rng, placed, table),
    };
    if (b == null) return null;
    balls.add(b);
    placed.add(b);
  }
  final first = 10 - count;
  return TableSetup(
    game: GameType.nineBall,
    cue: cue,
    balls: [
      PlacedBall(number: first, pos: target),
      for (var i = 0; i < balls.length; i++) PlacedBall(number: first + 1 + i, pos: balls[i]),
    ],
    table: table,
  );
}

/// Lượt vật lý (spec mục 8.5), chỉ cho Ngắm bi và Vị trí, sau khi có tham
/// chiếu. Hàm thuần trên [lookup]: Ngắm bi phải chấm các cú vào lỗ gần nhất,
/// thiếu lần mô phỏng nào thì [lookup] ném và người gọi chạy lại.
bool acceptsForTopic(CoachTopic topic, CoachReference ref, ShotLookup lookup) {
  switch (topic) {
    case CoachTopic.safety:
      return ref.kind == PlanStepKind.safety && geometryFitsTopic(ref.setup, topic);
    case CoachTopic.kick:
      return ref.kind == PlanStepKind.safety && geometryFitsTopic(ref.setup, topic);
    case CoachTopic.position:
      if (ref.kind != PlanStepKind.normal) return false;
      if (ref.best!.score.position > zoneFair) return false;
      final options = ref.tier == 1 ? tierOneCount : tierTwoCount;
      return (options - ref.accepted.length) * 3 >= options;
    case CoachTopic.aiming:
      if (ref.kind != PlanStepKind.normal || ref.accepted.isEmpty) return false;
      final target = legalTargetsAmong(ref.setup.game, ref.setup.balls).first;
      final near = nearestPocket(target.pos, ref.setup.table);
      if (near == ref.step.pocket) return true;
      for (final stroke in strokeCandidates) {
        for (final power in powerCandidates) {
          final a = PotAnswer(ball: target.number, pocket: near, stroke: stroke, power: power);
          final e = evaluateAnswer(a, ref, lookup);
          if (e is EvalUnmakeable) return true;
          if (gradeAnswer(ref, a, e).passed) return false;
        }
      }
      return true;
  }
}

/// Số phương án của tầng 1 và tầng 2 (spec Planner mục 5.5).
final tierOneCount = strokeCandidates.length * powerCandidates.length;
final tierTwoCount = tierOneCount * 2 * sideTipsCandidates.length;

/// Sinh tình huống chia lát (spec mục 8): lượt hình học, rồi với Ngắm bi và
/// Vị trí chạy `CoachJob` tới khi có tham chiếu và xét lượt vật lý. Thế bàn
/// không đạt thì đề xuất thế khác bằng số kế tiếp của cùng [CoachRng], nên
/// cùng seed ban đầu ra cùng tình huống cuối cùng.
class CoachGenerateJob {
  CoachGenerateJob({
    required this.topic,
    required this.difficulty,
    required this.seed,
    this.aim = aimShot,
    this.safety = const SafetyPhysics(),
    this.table = TableSpec.nineFoot,
  }) : _rng = CoachRng(seed);

  final CoachTopic topic;
  final CoachDifficulty difficulty;
  final int seed;
  final AimShotFn aim;
  final SafetyPhysics safety;
  final TableSpec table;
  final CoachRng _rng;

  CoachJob? _job;
  CoachSituation? _result;
  bool _failed = false;
  bool _cancelled = false;
  int _physicsTries = 0;

  /// Tình huống đã sinh; null khi chưa xong hay không sinh được.
  CoachSituation? get result => _result;

  /// Việc tính của tình huống đã sinh — Ngắm bi và Vị trí đã có tham chiếu,
  /// màn hình dùng lại, không tính lại.
  CoachJob? get job => _result == null ? null : _job;

  /// Hết số lần thử: lấy tình huống thư viện (spec mục 8.6).
  bool get failed => _failed;
  bool get isDone => _result != null || _failed || _cancelled;

  /// Số thế bàn đã chạy lượt vật lý.
  int get physicsTries => _physicsTries;

  void cancel() {
    _cancelled = true;
    _job?.cancel();
  }

  /// Làm tới khi hết [budget] (hoặc đủ [maxUnits] đơn vị), luôn ít nhất một.
  void step({Duration budget = sliceBudget, int? maxUnits}) {
    final clock = Stopwatch()..start();
    var units = 0;
    var longest = Duration.zero;
    while (!isDone) {
      final started = clock.elapsed;
      _unit();
      units++;
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxUnits != null && units >= maxUnits) break;
      if (clock.elapsed + longest > budget) break;
    }
  }

  void _unit() {
    final job = _job;
    if (job == null) {
      final setup = proposeLayout(_rng, topic, difficulty, table: table);
      if (setup == null) {
        _failed = true;
        return;
      }
      _job = CoachJob(setup, aim: aim, safety: safety);
      if (topic == CoachTopic.safety || topic == CoachTopic.kick) _accept(setup);
      return;
    }
    final ref = job.reference;
    if (ref == null) {
      job.step(budget: Duration.zero, maxUnits: 1);
      return;
    }
    try {
      if (acceptsForTopic(topic, ref, job.cache.lookup)) {
        _accept(job.setup);
        return;
      }
    } on MissingSimulation catch (m) {
      job.cache.fill(m.key, aim: aim, table: table);
      return;
    }
    job.cancel();
    _job = null;
    _physicsTries++;
    if (_physicsTries >= coachPhysicsTries) _failed = true;
  }

  void _accept(TableSetup setup) {
    _result = CoachSituation(
      key: generatedKey(topic, difficulty, seed),
      topic: topic,
      source: CoachSource.generated,
      difficulty: difficulty,
      setup: setup,
      seed: seed,
    );
  }
}
