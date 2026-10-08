import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_scoring.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Các tầng của việc tìm cú thủ, theo thứ tự cố định (chủ sản phẩm chốt
/// 08/10/2026). Trực tiếp trước A băng: có cú trực tiếp tốt rồi thì cắt tỉa
/// bỏ được phần lớn A băng mà không mô phỏng (phạt A băng từ 10 trở lên).
enum SafetyTier {
  /// Trực tiếp vào một bi hợp lệ thấy được, không áp phê.
  direct,

  /// Trực tiếp vào bi đó có áp phê — chỉ khi tầng [direct] của bi không có
  /// phương án nào hợp lệ.
  directSpin,

  /// A băng 1–3 băng vào mọi bi hợp lệ — luôn thử, kể cả khi không đui.
  kick,

  /// A băng 4 băng — chỉ khi mọi chặng trước không có phương án hợp lệ nào.
  kickFallback,
}

/// Một chặng: tầng và bi (null với A băng, vì A băng thử mọi bi hợp lệ).
typedef SafetyStage = ({SafetyTier tier, int? ballNum});

/// Tìm cú thủ chia lát (spec cú phòng thủ 3.6), cùng mẫu với `PlannerJob`.
///
/// Mỗi đơn vị việc chạy lại phép chấm thuần của phương án đang xét trên bộ
/// nhớ đệm; gặp lần dò hay lần mô phỏng chưa có thì làm đúng lần đó rồi
/// dừng. Khác `PlannerJob` ở chỗ nhớ luôn kết quả các phương án đã chấm (con
/// trỏ): tìm cú thủ cần vài nghìn lần mô phỏng, chạy lại từ đầu mỗi lần thì
/// tốn theo bình phương. Thứ tự cố định và phép chấm thuần, nên chạy từng
/// lát vẫn cho đúng y kết quả chạy một mạch.
///
/// Phương án được thêm theo từng chặng ([stages]). Mở chặng nào chỉ tuỳ kết
/// quả dò và mô phỏng, không tuỳ cắt tỉa, nên có cắt tỉa hay không vẫn xét
/// cùng một tập phương án.
class SafetyJob {
  SafetyJob(this.context, {this.physics = const SafetyPhysics(), this.prune = true, this.maxOptions})
      : stages = List.unmodifiable(<SafetyStage>[
          for (final t in context.visible) ...[
            (tier: SafetyTier.direct, ballNum: t.number),
            (tier: SafetyTier.directSpin, ballNum: t.number),
          ],
          (tier: SafetyTier.kick, ballNum: null),
          (tier: SafetyTier.kickFallback, ballNum: null),
        ]);

  final SafetyContext context;
  final SafetyPhysics physics;

  /// Bỏ phương án không thể thắng (độ lệch 4 của kế hoạch). false chỉ để
  /// test kiểm cắt tỉa không đổi kết quả.
  final bool prune;

  /// Mỗi chặng chỉ xét ngần này phương án đầu — cho test chạy nhanh mà vẫn
  /// đi qua mọi chặng.
  final int? maxOptions;

  /// Mọi chặng có thể mở, đúng thứ tự: mỗi bi thấy được (số nhỏ trước) một
  /// chặng [SafetyTier.direct] rồi một chặng [SafetyTier.directSpin], sau đó
  /// [SafetyTier.kick], cuối cùng [SafetyTier.kickFallback].
  final List<SafetyStage> stages;

  final _options = <SafetyOption>[];
  final _opened = <SafetyStage>[];
  final _aims = <int, AimResult?>{};
  final _sims = <SimKey, ShotTrace?>{};
  final _tried = <int>{};
  var _cursor = 0;
  var _nextStage = 0;

  /// Chỗ đang hỏi xem chặng [SafetyTier.direct] vừa xong có phương án nào
  /// hợp lệ không; giữ qua các đơn vị việc như [_cursor].
  var _scan = 0;
  SafetyEval? _best;
  var _done = false;
  var _cancelled = false;
  SafetyShot? _result;

  bool get isDone => _done;
  bool get isCancelled => _cancelled;

  /// null khi không còn cú thủ hợp lệ nào (spec 3.7).
  SafetyShot? get result => _result;

  /// Số lần dò và mô phỏng đã chạy.
  int get simulations => _aims.length + _sims.length;

  /// Số băng của các phương án đã dò (0 là trực tiếp) — test 9.1.4 kiểm 4
  /// băng chỉ là đường lui.
  Set<int> get triedRailCounts => Set.unmodifiable(_tried);

  /// Các chặng đã mở, đúng thứ tự.
  List<SafetyStage> get openedStages => List.unmodifiable(_opened);

  /// Mọi phương án của các chặng đã mở, đúng thứ tự xét.
  List<SafetyOption> get options => List.unmodifiable(_options);

  void cancel() => _cancelled = true;

  List<SafetyOption> _capped(List<SafetyOption> list) {
    final cap = maxOptions;
    return cap == null || list.length <= cap ? list : list.sublist(0, cap);
  }

  List<SafetyOption> _optionsOf(SafetyStage s) {
    PlacedBall target() => context.visible.firstWhere((b) => b.number == s.ballNum);
    return switch (s.tier) {
      SafetyTier.direct => directOptions(context, target(), const [SideSpin.none()]),
      SafetyTier.directSpin => directOptions(context, target(), safetySideSpins),
      SafetyTier.kick => kickOptions(context, fromRails: 1, toRails: kickFallbackRails - 1),
      SafetyTier.kickFallback =>
        kickOptions(context, fromRails: kickFallbackRails, toRails: maxKickRails),
    };
  }

  /// Chặng [s] có mở không. Chỉ đọc qua [_lookup]: thiếu kết quả thì ném lỗi
  /// thiếu, đơn vị việc làm đúng lần đó rồi lần sau hỏi tiếp từ [_scan].
  bool _opens(SafetyStage s) => switch (s.tier) {
        SafetyTier.direct || SafetyTier.kick => true,
        // Áp phê là đường lui: chỉ khi bi này không có cú không áp phê nào
        // hợp lệ (chủ sản phẩm chốt 08/10/2026).
        SafetyTier.directSpin => !_plainLegal(),
        // 4 băng chỉ khi chưa có phương án hợp lệ nào (spec quyết định 3).
        // _best null đúng khi chưa có phương án hợp lệ, và khi đó chưa cắt
        // tỉa gì, nên điều kiện này không tuỳ cắt tỉa.
        SafetyTier.kickFallback => _best == null,
      };

  /// Chặng [SafetyTier.direct] vừa xong (từ [_scan] tới cuối danh sách) có
  /// phương án nào hợp lệ không. Phương án đã chấm thì đọc bộ nhớ đệm;
  /// phương án cắt tỉa đã bỏ trước khi dò thì phải dò và mô phỏng lực chọn,
  /// để câu trả lời giống hệt khi không cắt tỉa.
  bool _plainLegal() {
    for (; _scan < _options.length; _scan++) {
      if (isLegalOption(context, _scan, _options[_scan], _lookup)) return true;
    }
    return false;
  }

  /// Một đơn vị việc. true khi vừa chạy đúng một lần dò hay mô phỏng mới;
  /// false khi xong mà không cần lần nào.
  bool work() {
    while (!_done && !_cancelled) {
      try {
        if (_cursor < _options.length) {
          final e = evaluateOption(context, _cursor, _options[_cursor], _lookup,
              bound: prune ? _best?.total : null);
          if (e != null && beats(e, _best)) _best = e;
          _cursor++;
        } else if (_nextStage < stages.length) {
          final stage = stages[_nextStage];
          if (_opens(stage)) {
            _opened.add(stage);
            if (stage.tier == SafetyTier.direct) _scan = _options.length;
            _options.addAll(_capped(_optionsOf(stage)));
          }
          _nextStage++;
        } else {
          final best = _best;
          _result = best == null ? null : buildSafetyShot(context, best, _lookup.trace);
          _done = true;
        }
      } on _MissingAim catch (m) {
        final o = _options[m.index];
        _tried.add(o.rails.length);
        _aims[m.index] =
            aimSafety(o, cue: context.cue, physics: physics, table: context.table);
        return true;
      } on _MissingSim catch (m) {
        _sims[m.key] = simulateSafety(m.key, physics: physics, table: context.table);
        return true;
      }
    }
    return false;
  }

  /// Làm việc tới khi hết [budget] (hoặc đủ [maxSimulations] lần mới, cho
  /// test), luôn ít nhất một đơn vị; không bắt đầu đơn vị mới nếu đơn vị dài
  /// nhất của lát này không còn vừa ngân sách. Stopwatch chỉ quyết định
  /// *khi nào* dừng, không bao giờ quyết định *tính gì*.
  void step({Duration budget = sliceBudget, int? maxSimulations}) {
    final clock = Stopwatch()..start();
    var simulated = 0;
    var longest = Duration.zero;
    while (!_done && !_cancelled) {
      final started = clock.elapsed;
      if (work()) simulated++;
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxSimulations != null && simulated >= maxSimulations) break;
      if (clock.elapsed + longest > budget) break;
    }
  }

  late final SafetyLookup _lookup = _JobLookup(this);
}

class _JobLookup implements SafetyLookup {
  _JobLookup(this.job);
  final SafetyJob job;

  @override
  AimResult? aim(int index) {
    if (job._aims.containsKey(index)) return job._aims[index];
    throw _MissingAim(index);
  }

  @override
  ShotTrace? trace(SimKey key) {
    if (job._sims.containsKey(key)) return job._sims[key];
    throw _MissingSim(key);
  }
}

class _MissingAim implements Exception {
  const _MissingAim(this.index);
  final int index;
}

class _MissingSim implements Exception {
  const _MissingSim(this.key);
  final SimKey key;
}

/// Chạy một mạch tới hết — cho test, công cụ dò bàn và đo tốc độ.
SafetyShot? searchToEnd(SafetyContext c, {SafetyPhysics physics = const SafetyPhysics()}) {
  final job = SafetyJob(c, physics: physics);
  while (!job.isDone) {
    job.step(budget: const Duration(days: 1));
  }
  return job.result;
}
