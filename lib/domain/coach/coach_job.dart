import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/evaluation.dart';
import 'package:poolcoachai/domain/coach/grading.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/sim_cache.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

sealed class CoachEvent {
  const CoachEvent();
}

/// Tham chiếu đã sẵn sàng: câu trả lời chấm được từ lúc này.
final class ReferenceReady extends CoachEvent {
  const ReferenceReady(this.reference);
  final CoachReference reference;
}

/// Cú thủ có hoặc đổi. [done]: việc tìm đã xong, cú không đổi nữa. [shot]
/// null khi xong mà không còn cú thủ hợp lệ nào.
final class SafetyReady extends CoachEvent {
  const SafetyReady(this.shot, {required this.done});
  final SafetyShot? shot;
  final bool done;
}

/// Câu trả lời thứ [index] (theo thứ tự [CoachJob.submit]) đã chấm.
final class Graded extends CoachEvent {
  const Graded(this.index, this.verdict);
  final int index;
  final CoachVerdict verdict;
}

/// Việc tính chia lát của Coach (spec mục 5.3), cùng mẫu với `PlannerJob`.
///
/// Mỗi đơn vị việc chạy lại một phép thuần trên bộ nhớ mô phỏng chung; gặp
/// lần mô phỏng chưa có thì làm đúng lần đó rồi dừng. Vì vậy chạy từng lát
/// cho đúng y kết quả chạy một mạch: đồng hồ chỉ quyết định *khi nào* trả
/// quyền cho giao diện, không bao giờ quyết định *tính gì*.
///
/// Thứ tự việc: tham chiếu (bước 0 của Planner) → chấm các câu trả lời đang
/// chờ → tìm cú thủ. Chấm lựa chọn Phòng thủ không phải chờ cú thủ.
class CoachJob {
  CoachJob(this.setup, {this.aim = aimShot, this.safety = const SafetyPhysics(), SimCache? cache})
      : cache = cache ?? SimCache() {
    _planner = PlannerJob(setup, aim: aim, safety: safety, cache: this.cache);
  }

  final TableSetup setup;
  final AimShotFn aim;
  final SafetyPhysics safety;

  /// Bộ nhớ mô phỏng dùng chung với Planner.
  final SimCache cache;
  late final PlannerJob _planner;

  CoachReference? _reference;
  bool _plannerActive = true;

  /// Việc tìm cú thủ riêng khi người chơi chọn Phòng thủ mà kết luận là
  /// chưa đủ dữ liệu: hiện cả cú ăn lẫn cú thủ (chủ sản phẩm chốt Q4).
  SafetyJob? _extraSafety;
  SafetyShot? _extraShot;
  bool _extraDone = false;

  final _answers = <CoachAnswer>[];
  final _verdicts = <CoachVerdict>[];
  bool _cancelled = false;

  CoachReference? get reference => _reference;
  bool get referenceReady => _reference != null;
  bool get isCancelled => _cancelled;

  /// Kết luận đã có, đúng thứ tự [submit].
  List<CoachVerdict> get verdicts => List.unmodifiable(_verdicts);

  /// Số câu trả lời đang chờ chấm.
  int get pending => _answers.length - _verdicts.length;

  /// Cú thủ để hiện trong đáp án: của bước phòng thủ, hoặc của lần tìm riêng.
  SafetyShot? get safetyShot => _reference?.safety ?? _extraShot;

  /// Đang tìm cú thủ.
  bool get searchingSafety =>
      (_reference?.kind == PlanStepKind.safety && _plannerActive) ||
      (_extraSafety != null && !_extraDone);

  /// Không còn việc gì để làm.
  bool get isIdle => _cancelled || (_reference != null && pending == 0 && !searchingSafety);

  /// Xếp [answer] vào hàng chấm; trả chỉ số của nó.
  int submit(CoachAnswer answer) {
    _answers.add(answer);
    return _answers.length - 1;
  }

  /// Rời màn hình: bỏ việc đang tính, không báo thêm gì.
  void cancel() {
    _cancelled = true;
    _planner.cancel();
    _extraSafety?.cancel();
  }

  /// Làm tới khi hết [budget] (hoặc đủ [maxUnits] đơn vị, cho test), luôn ít
  /// nhất một đơn vị. Không bắt đầu đơn vị mới nếu đơn vị dài nhất của lát
  /// không còn vừa ngân sách.
  List<CoachEvent> step({Duration budget = sliceBudget, int? maxUnits}) {
    final events = <CoachEvent>[];
    if (_cancelled) return events;
    final clock = Stopwatch()..start();
    var units = 0;
    var longest = Duration.zero;
    while (!isIdle) {
      final started = clock.elapsed;
      _unit(events);
      units++;
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxUnits != null && units >= maxUnits) break;
      if (clock.elapsed + longest > budget) break;
    }
    return events;
  }

  void _unit(List<CoachEvent> events) {
    final ref = _reference;
    if (ref == null) {
      _plannerUnit(events);
    } else if (pending > 0) {
      _gradeUnit(ref, events);
    } else if (ref.kind == PlanStepKind.safety && _plannerActive) {
      _plannerUnit(events);
    } else if (_extraSafety != null && !_extraDone) {
      _extraUnit(events);
    }
  }

  void _plannerUnit(List<CoachEvent> events) {
    // Ngân sách 0: đúng một đơn vị việc của Planner.
    final out = _planner.step(budget: Duration.zero);
    for (final e in out) {
      switch (e) {
        case StepReady(:final index, :final step) when index == 0:
          _onStep0(step, events);
        case StepReady():
          break;
        case PlanDone():
          if (_reference?.kind == PlanStepKind.safety) {
            _plannerActive = false;
            events.add(SafetyReady(_reference!.safety, done: true));
          }
      }
    }
    if (!_plannerActive) return;
    // Bước 0 là phòng thủ: báo tham chiếu ngay, chưa cần cú thủ.
    final pendingSafety = _planner.pendingSafety;
    if (_reference == null && pendingSafety != null) {
      _setReference(pendingSafety, events);
    }
    // Ở điểm hỏi thì giữ cú lượt thô, như "Dùng cú này" (spec mục 5.3).
    if (_planner.safetyCheckpoint) {
      for (final e in _planner.keepSafety()) {
        if (e is PlanDone) {
          _plannerActive = false;
          events.add(SafetyReady(_reference!.safety, done: true));
        }
      }
    }
  }

  void _onStep0(PlanStep step, List<CoachEvent> events) {
    if (step.kind == PlanStepKind.safety) {
      final ref = _reference;
      if (ref == null) {
        _setReference(step, events);
      } else {
        _reference = ref.withSafety(step.safety);
      }
      events.add(SafetyReady(step.safety, done: false));
      return;
    }
    _setReference(step, events);
    // Chỉ cần bước 0: không tính bước 2 trở đi.
    _planner.cancel();
    _plannerActive = false;
  }

  void _setReference(PlanStep step, List<CoachEvent> events) {
    // Mọi lần mô phỏng của tầng Planner đã dùng có sẵn trong bộ nhớ chung.
    final ref = buildReference(setup, step, cache.lookup);
    _reference = ref;
    events.add(ReferenceReady(ref));
  }

  void _gradeUnit(CoachReference ref, List<CoachEvent> events) {
    final index = _verdicts.length;
    final answer = _answers[index];
    try {
      final evaluation = switch (answer) {
        PotAnswer() => evaluateAnswer(answer, ref, cache.lookup),
        SafetyAnswer() => null,
      };
      final verdict = gradeAnswer(ref, answer, evaluation);
      _verdicts.add(verdict);
      events.add(Graded(index, verdict));
      if (verdict.undecided == CoachUndecidedReason.potVsSafety && _extraSafety == null) {
        _extraSafety = SafetyJob(
          SafetyContext(game: setup.game, cue: setup.cue, balls: setup.balls, table: setup.table),
          physics: safety,
        );
      }
    } on MissingSimulation catch (m) {
      cache.fill(m.key, aim: aim, table: setup.table);
    }
  }

  void _extraUnit(List<CoachEvent> events) {
    final search = _extraSafety!;
    search.work();
    if (search.atCheckpoint) {
      // Lượt thô đã thủ tốt: giữ cú đó, như màn Planner khi "Dùng cú này".
      search.cancel();
      _extraShot = search.coarseResult;
    } else if (search.isDone) {
      _extraShot = search.result;
    } else {
      return;
    }
    _extraDone = true;
    events.add(SafetyReady(_extraShot, done: true));
  }
}

/// Chạy một mạch tới khi xong việc — cho test, công cụ dò bàn và đo tốc độ.
CoachJob runCoachJob(CoachJob job) {
  while (!job.isIdle) {
    job.step(budget: const Duration(days: 1));
  }
  return job;
}
