import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

/// Tính một bước từ bi cái [cue] với các bi [remaining] (spec mục 4–5).
///
/// Hàm thuần trên [lookup]: việc tính chia lát gọi lại nó từ đầu mỗi khi
/// bộ nhớ đệm có thêm một lần mô phỏng, nên thứ tự thử ở đây chính là thứ
/// tự mô phỏng — và kết quả không phụ thuộc cỡ lát.
PlanStep planStep({
  required GameType game,
  required Vec2 cue,
  required List<PlacedBall> remaining,
  required ShotLookup lookup,
  required CandidateFinder finder,
}) {
  final candidate = finder.easiest(cue, remaining);
  if (candidate == null) {
    return _safetyStep(game, cue, remaining);
  }
  final g = candidate.geometry;
  final ctx = ScoringContext(
    geometry: g,
    after: [for (final b in remaining) if (b.number != candidate.ball.number) b],
    lookup: lookup,
    next: finder,
  );

  // Tầng 2 chỉ chạy khi tầng 1 không còn phương án nào — không bao giờ để
  // "so" với tầng 1 (spec mục 5.5).
  final best = bestOf(scoreTier(ctx, tierOneKeys(g))) ??
      bestOf(scoreTier(ctx, tierTwoKeys(g)));
  if (best != null) return _chosenStep(ctx, cue, candidate, best);

  final fallback = lookup(shotKey(g, Stroke.stun, fallbackPower));
  if (fallback != null &&
      rejectionOf(fallback, g.pocket, ctx.obstacles, table: ctx.table) == null) {
    return PlanStep(
      kind: PlanStepKind.fallback,
      cbFrom: cue,
      ballNum: candidate.ball.number,
      geometry: g,
      stroke: Stroke.stun,
      power: fallbackPower,
      aimed: fallback,
      missAdvice: ctx.hasNext ? missSafetyAdvice(g, ctx.obstacles, table: ctx.table) : null,
      nextBallNum:
          ctx.hasNext ? finder.easiest(fallback.trace.cueEnd, ctx.after)?.ball.number : null,
    );
  }
  return _safetyStep(game, cue, remaining);
}

/// Bước phòng thủ duy nhất của Planner. 9 / 10 bi: bi bắt buộc là bi bị
/// ép đánh. 8 bi: không có bi cụ thể bị ép, nên không gắn số bi (PRD §4).
PlanStep _safetyStep(GameType game, Vec2 cue, List<PlacedBall> remaining) =>
    PlanStep.safety(
      cbFrom: cue,
      ballNum: game == GameType.eightBall
          ? null
          : legalTargetsAmong(game, remaining).firstOrNull?.number,
    );

PlanStep _chosenStep(ScoringContext ctx, Vec2 cue, Candidate candidate, ScoredOption best) {
  final key = best.key;
  final g = candidate.geometry;
  Vec2? endAt(double delta) {
    final a = ctx.lookup(withPower(key, jitteredPower(key.power, delta)));
    if (a == null || rejectionOf(a, key.pocket, ctx.obstacles, table: ctx.table) != null) {
      return null;
    }
    return a.trace.cueEnd;
  }

  return PlanStep(
    kind: PlanStepKind.normal,
    cbFrom: cue,
    ballNum: candidate.ball.number,
    geometry: g,
    stroke: key.stroke,
    power: key.power,
    spin: key.spin,
    aimed: best.aimed,
    score: best.score,
    jitterEnds: (minus: endAt(-powerJitter), plus: endAt(powerJitter)),
    tolerance: ctx.hasNext ? toleranceOf(ctx, key) : null,
    missAdvice: ctx.hasNext ? missSafetyAdvice(g, ctx.obstacles, table: ctx.table) : null,
    // Cùng quãng cơ → bi ảo hình học như dòng SAWS của màn mô phỏng.
    sawsBhePercent: key.spin.isNone
        ? null
        : sawsBhePercent(distance: cue.distanceTo(g.ghost), power: key.power, stroke: key.stroke),
    nextBallNum: ctx.hasNext
        ? ctx.next.easiest(best.aimed.trace.cueEnd, ctx.after)!.ball.number
        : null,
  );
}

sealed class PlannerEvent {
  const PlannerEvent();
}

/// Bước [index] vừa tính xong. Bước phòng thủ báo lại cùng [index] khi lượt
/// đầy đủ (sau "Tính tiếp", hay tự tìm tiếp sau cú tạm) ra cú thủ tốt hơn
/// hẳn cú lượt thô.
final class StepReady extends PlannerEvent {
  const StepReady(this.index, this.step);
  final int index;
  final PlanStep step;
}

/// Kế hoạch xong (dọn hết bàn hoặc dừng ở bước phòng thủ).
final class PlanDone extends PlannerEvent {
  const PlanDone(this.steps);
  final List<PlanStep> steps;
}

/// Việc tính chia lát (spec mục 4.5), cùng mẫu với `ScratchAdviceJob`.
///
/// Mỗi đơn vị việc chạy lại [planStep] của bước đang tính trên bộ nhớ đệm;
/// gặp lần mô phỏng chưa có thì làm đúng lần đó rồi dừng. Vì vậy chạy từng
/// lát cho đúng y kết quả như chạy một mạch: Stopwatch chỉ quyết định *khi
/// nào* trả quyền cho giao diện, không bao giờ quyết định *tính gì*.
class PlannerJob {
  PlannerJob(this.setup, {this.aim = aimShot, this.safety = const SafetyPhysics()})
      : _cue = setup.cue,
        _remaining = [...setup.balls]..sort((a, b) => a.number.compareTo(b.number)),
        _finder = CandidateFinder(game: setup.game, table: setup.table);

  final TableSetup setup;
  final AimShotFn aim;

  /// Lõi của việc tìm cú thủ; test thay để bước phòng thủ ra nhanh.
  final SafetyPhysics safety;

  /// Việc tìm cú thủ của bước phòng thủ đang chờ báo ra (spec cú phòng thủ 3.6).
  SafetyJob? _search;
  PlanStep? _bareSafety;

  /// Đã báo bước phòng thủ với cú lượt thô (điểm hỏi hay cú tạm).
  bool _reportedRough = false;

  /// Cú lượt thô được báo như cú tạm: lượt thô chưa thủ tốt, việc tìm tự
  /// chạy tiếp (chủ sản phẩm chốt 08/10/2026 sau Task 25).
  bool _provisional = false;
  final CandidateFinder _finder;
  final _sims = <ShotKey, AimedShot?>{};
  final _steps = <PlanStep>[];
  Vec2 _cue;
  List<PlacedBall> _remaining;
  bool _done = false;
  bool _cancelled = false;

  List<PlanStep> get steps => List.unmodifiable(_steps);
  bool get isDone => _done;
  bool get isCancelled => _cancelled;

  /// Đang tìm cú thủ: màn hình nói "Đang tìm cú thủ…" thay "Đang tính bước".
  bool get searchingSafety => _search != null && !_done && !safetyCheckpoint;

  /// Bước phòng thủ đang hiện cú lượt thô tạm, việc tìm vẫn chạy: màn hình
  /// nói "Cú thủ tạm tính — đang tìm cú tốt hơn…". Xong thì tắt; cú chỉ đổi
  /// khi lượt đầy đủ tốt hơn hẳn.
  bool get provisionalSafety => _provisional && searchingSafety;

  /// Lượt thô đã ra cú thủ tốt và bước phòng thủ đã báo với cú đó: chờ
  /// người dùng chọn [continueSafety] ("Tính tiếp") hay [keepSafety] ("Dùng
  /// cú này"). Trong lúc chờ, [step] không làm gì.
  bool get safetyCheckpoint => !_done && !_cancelled && (_search?.atCheckpoint ?? false);

  /// "Tính tiếp": chạy lượt đầy đủ trên cùng việc tìm, không làm lại lượt
  /// thô; xong thì báo lại bước phòng thủ nếu cú mới tốt hơn hẳn.
  void continueSafety() => _search?.resume();

  /// "Dùng cú này": giữ cú lượt thô, kế hoạch xong.
  List<PlannerEvent> keepSafety() {
    if (!safetyCheckpoint) return const [];
    _search!.cancel();
    final events = <PlannerEvent>[];
    _finish(events);
    return events;
  }

  /// Số lần mô phỏng đã chạy, kể cả lần dò và mô phỏng của việc tìm cú thủ.
  int get simulations => _sims.length + (_search?.simulations ?? 0);

  /// Mẫu số của "Đang tính bước X/N".
  int get totalSteps => plannedStepCount(setup);

  /// Lát của [step] khi không truyền `budget`: [safetySliceBudget] trong lúc
  /// tìm cú thủ — người dùng đang chờ "Đang tìm cú thủ…", không kéo bi (chủ
  /// sản phẩm chốt 08/10/2026 sau Task 25) — còn lại [sliceBudget].
  Duration get defaultBudget => _search != null ? safetySliceBudget : sliceBudget;

  /// Rời màn hay sửa bàn: bỏ việc đang tính, không báo thêm gì.
  void cancel() {
    _cancelled = true;
    _search?.cancel();
  }

  /// Làm việc tới khi hết [budget] (hoặc đủ [maxSimulations] lần mô phỏng
  /// mới, cho test), luôn ít nhất một đơn vị. Không bắt đầu đơn vị mới nếu
  /// đơn vị dài nhất của lát này không còn vừa ngân sách: một lần mô phỏng
  /// trên Chrome mất vài mili giây, chạy quá là rớt khung hình.
  ///
  /// [budget] null là [defaultBudget].
  List<PlannerEvent> step({Duration? budget, int? maxSimulations}) {
    if (_done || _cancelled) return const [];
    final events = <PlannerEvent>[];
    final clock = Stopwatch()..start();
    var simulated = 0;
    var longest = Duration.zero;
    while (!_done && !safetyCheckpoint) {
      final started = clock.elapsed;
      final search = _search;
      if (search != null) {
        if (search.work()) simulated++;
        final rough = search.coarseResult;
        // Lượt thô xong mà có cú: báo bước ngay — ở điểm hỏi, hay làm cú tạm.
        if (!_reportedRough && rough != null) {
          _provisional = !search.atCheckpoint;
          _reportSafety(rough, events);
        }
        if (search.isDone) {
          // Cú cuối chỉ khác cú lượt thô khi tốt hơn hẳn: chỉ khi đó báo lại.
          if (!_reportedRough || !identical(search.result, rough)) {
            _reportSafety(search.result, events);
          }
          _finish(events);
        }
      } else {
        try {
          _commit(
            planStep(
              game: setup.game,
              cue: _cue,
              remaining: _remaining,
              lookup: _lookup,
              finder: _finder,
            ),
            events,
          );
        } on _Missing catch (m) {
          _sims[m.key] = simulateKey(m.key, aim: aim, table: setup.table);
          simulated++;
        }
      }
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxSimulations != null && simulated >= maxSimulations) break;
      if (clock.elapsed + longest > (budget ?? defaultBudget)) break;
    }
    return events;
  }

  /// Báo bước phòng thủ với cú [shot]: lần đầu thêm bước, lần sau thay cú
  /// của chính bước đó (cùng chỉ số).
  void _reportSafety(SafetyShot? shot, List<PlannerEvent> events) {
    final bare = _bareSafety!;
    final step = PlanStep.safety(cbFrom: bare.cbFrom, ballNum: bare.ballNum, safety: shot);
    if (_reportedRough) {
      _steps[_steps.length - 1] = step;
    } else {
      _steps.add(step);
      _reportedRough = true;
    }
    events.add(StepReady(_steps.length - 1, step));
  }

  AimedShot? _lookup(ShotKey key) {
    if (_sims.containsKey(key)) return _sims[key];
    throw _Missing(key);
  }

  void _commit(PlanStep step, List<PlannerEvent> events) {
    if (step.kind == PlanStepKind.safety) {
      // Bước phòng thủ: tìm cú thủ trước khi báo bước ra. Kế hoạch vẫn dừng
      // sau bước này vì tới lượt đối thủ (spec cú phòng thủ 3.1).
      _bareSafety = step;
      _search = SafetyJob(
        SafetyContext(game: setup.game, cue: step.cbFrom, balls: _remaining, table: setup.table),
        physics: safety,
      );
      return;
    }
    _steps.add(step);
    events.add(StepReady(_steps.length - 1, step));
    _remaining = [for (final b in _remaining) if (b.number != step.ballNum) b];
    // Bất biến của kế hoạch: bước sau bắt đầu đúng đối tượng này, không
    // tính lại, không sao chép (spec mục 4.4).
    _cue = step.trace!.cueEnd;
    if (legalTargetsAmong(setup.game, _remaining).isEmpty) _finish(events);
  }

  void _finish(List<PlannerEvent> events) {
    _done = true;
    events.add(PlanDone(List.unmodifiable(_steps)));
  }
}

class _Missing implements Exception {
  const _Missing(this.key);
  final ShotKey key;
}

/// Chạy một mạch tới hết — cho test, công cụ dò bàn và đo tốc độ. Ở điểm
/// hỏi của cú thủ thì "Tính tiếp" ([continueSafety], mặc định) hay "Dùng cú
/// này".
List<PlanStep> planToEnd(TableSetup setup,
    {AimShotFn aim = aimShot,
    SafetyPhysics safety = const SafetyPhysics(),
    bool continueSafety = true}) {
  final job = PlannerJob(setup, aim: aim, safety: safety);
  while (!job.isDone) {
    if (job.safetyCheckpoint) {
      if (continueSafety) {
        job.continueSafety();
      } else {
        job.keepSafety();
      }
    }
    job.step(budget: const Duration(days: 1));
  }
  return job.steps;
}
