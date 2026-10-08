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

/// Phương án của lượt thô (chủ sản phẩm chốt 08/10/2026 sau Task 25: "thử
/// các mốc, mức lực trước"): không áp phê; trực tiếp ở [coarseThicknesses];
/// A băng tới [coarseKickRails] băng ở [coarseKickThicknesses].
bool isCoarseOption(SafetyOption o) =>
    o.spin.isNone &&
    switch (o.kind) {
      SafetyKind.direct => coarseThicknesses.contains(o.thickness),
      SafetyKind.kick =>
        o.rails.length <= coarseKickRails && coarseKickThicknesses.contains(o.thickness),
    };

/// "Thủ tốt" ở điểm hỏi: đối thủ bị đui, hết đường ăn, hay cú dễ nhất của
/// đối thủ đã khó — đúng `OpponentView.hard`, cùng mức [opponentHardAngle]
/// với độ chịu sai số, không thêm ngưỡng mới.
bool isGoodSafety(SafetyShot s) => s.opponent.hard;

enum _Phase { coarse, checkpoint, full, done }

/// Tìm cú thủ chia lát (spec cú phòng thủ 3.6), cùng mẫu với `PlannerJob`.
///
/// Mỗi đơn vị việc chạy lại phép chấm thuần của phương án đang xét trên bộ
/// nhớ đệm; gặp lần dò hay lần mô phỏng chưa có thì làm đúng lần đó rồi
/// dừng. Khác `PlannerJob` ở chỗ nhớ luôn kết quả các phương án đã chấm (con
/// trỏ): tìm cú thủ cần vài nghìn lần mô phỏng, chạy lại từ đầu mỗi lần thì
/// tốn theo bình phương. Thứ tự cố định và phép chấm thuần, nên chạy từng
/// lát vẫn cho đúng y kết quả chạy một mạch.
///
/// Hai lượt (chủ sản phẩm chốt 08/10/2026 sau Task 25). Lượt thô xét
/// [coarseOptions] trước. Cú tốt nhất của nó mà thủ tốt ([isGoodSafety]) thì
/// việc tìm dừng ở [atCheckpoint] cho người dùng chọn: [resume] tìm tiếp,
/// hay dùng luôn [coarseResult]. Không thì đi thẳng vào lượt đầy đủ, không
/// hỏi; [coarseResult] khi đó là cú tạm để hiện trong lúc chờ. Lượt đầy đủ là đúng việc tìm cũ, từ đầu danh sách, với con trỏ và
/// điểm tốt nhất riêng; chỉ bộ nhớ đệm là dùng chung, nên lượt thô không
/// phải làm lại và lượt đầy đủ ra đúng như khi không có lượt thô.
///
/// Phương án của lượt đầy đủ được thêm theo từng chặng ([stages]). Mở chặng
/// nào chỉ tuỳ kết quả dò và mô phỏng, không tuỳ cắt tỉa, nên có cắt tỉa hay
/// không vẫn xét cùng một tập phương án.
class SafetyJob {
  SafetyJob(this.context,
      {this.physics = const SafetyPhysics(), this.prune = true, this.maxOptions, this.coarse = true})
      : stages = List.unmodifiable(<SafetyStage>[
          for (final t in context.visible) ...[
            (tier: SafetyTier.direct, ballNum: t.number),
            (tier: SafetyTier.directSpin, ballNum: t.number),
          ],
          (tier: SafetyTier.kick, ballNum: null),
          (tier: SafetyTier.kickFallback, ballNum: null),
        ]),
        _phase = coarse ? _Phase.coarse : _Phase.full;

  final SafetyContext context;
  final SafetyPhysics physics;

  /// Bỏ phương án không thể thắng (độ lệch 4 của kế hoạch). false chỉ để
  /// test kiểm cắt tỉa không đổi kết quả.
  final bool prune;

  /// Mỗi chặng chỉ xét ngần này phương án đầu — cho test chạy nhanh mà vẫn
  /// đi qua mọi chặng. Lượt thô lọc từ đúng các danh sách đã cắt này.
  final int? maxOptions;

  /// Chạy lượt thô trước. false là chỉ lượt đầy đủ: test so lượt đầy đủ
  /// sau "Tính tiếp" với lượt đầy đủ chạy một mạch.
  final bool coarse;

  /// Mọi chặng có thể mở, đúng thứ tự: mỗi bi thấy được (số nhỏ trước) một
  /// chặng [SafetyTier.direct] rồi một chặng [SafetyTier.directSpin], sau đó
  /// [SafetyTier.kick], cuối cùng [SafetyTier.kickFallback].
  final List<SafetyStage> stages;

  _Phase _phase;

  /// Danh sách phương án của từng chặng, dựng một lần. Bộ nhớ dò khoá theo
  /// đúng đối tượng phương án, nên hai lượt phải dùng chung đối tượng.
  final _lists = <int, List<SafetyOption>>{};
  final _aims = Map<SafetyOption, AimResult?>.identity();
  final _sims = <SimKey, ShotTrace?>{};
  final _tried = <int>{};

  final _coarseOptions = <SafetyOption>[];
  var _coarseBuilt = false;
  var _coarseCursor = 0;
  SafetyEval? _coarseBest;
  SafetyShot? _coarseResult;

  final _options = <SafetyOption>[];
  final _opened = <SafetyStage>[];
  var _cursor = 0;
  var _nextStage = 0;

  /// Chỗ đang hỏi xem chặng [SafetyTier.direct] vừa xong có phương án nào
  /// hợp lệ không; giữ qua các đơn vị việc như [_cursor].
  var _scan = 0;
  SafetyEval? _best;
  var _cancelled = false;
  SafetyShot? _result;

  bool get isDone => _phase == _Phase.done;
  bool get isCancelled => _cancelled;

  /// Lượt thô xong và cú tốt nhất của nó thủ tốt: việc tìm đứng chờ người
  /// dùng chọn tìm tiếp ([resume]) hay dùng [coarseResult].
  bool get atCheckpoint => _phase == _Phase.checkpoint;

  /// Lượt thô đã xong (hay không chạy): từ lúc này [coarseResult] không đổi
  /// nữa.
  bool get coarseDone => _phase != _Phase.coarse;

  /// Cú tốt nhất của lượt thô; null khi lượt thô chưa xong, không chạy, hay
  /// không có phương án hợp lệ nào.
  SafetyShot? get coarseResult => _coarseResult;

  /// Cú thủ cuối cùng; null khi không còn cú thủ hợp lệ nào (spec 3.7). Cú
  /// của lượt đầy đủ chỉ thay cú lượt thô khi điểm thấp hơn hẳn; bằng điểm
  /// thì đúng đối tượng [coarseResult].
  SafetyShot? get result => _result;

  /// Chỉ số trong [options] của phương án tốt nhất lượt đầy đủ — để test so
  /// với lượt đầy đủ chạy một mạch.
  int? get bestIndex => _best?.index;

  /// Số lần dò và mô phỏng đã chạy, cả hai lượt.
  int get simulations => _aims.length + _sims.length;

  /// Số băng của các phương án đã dò (0 là trực tiếp) — test 9.1.4 kiểm 4
  /// băng chỉ là đường lui.
  Set<int> get triedRailCounts => Set.unmodifiable(_tried);

  /// Các chặng đã mở ở lượt đầy đủ, đúng thứ tự.
  List<SafetyStage> get openedStages => List.unmodifiable(_opened);

  /// Mọi phương án của các chặng đã mở ở lượt đầy đủ, đúng thứ tự xét.
  List<SafetyOption> get options => List.unmodifiable(_options);

  /// Phương án của lượt thô, đúng thứ tự xét; rỗng khi chưa dựng.
  List<SafetyOption> get coarseOptions => List.unmodifiable(_coarseOptions);

  void cancel() => _cancelled = true;

  /// "Tính tiếp": từ điểm hỏi, chạy lượt đầy đủ trên cùng bộ nhớ đệm.
  void resume() {
    if (_phase == _Phase.checkpoint) _phase = _Phase.full;
  }

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

  List<SafetyOption> _listOf(int stage) =>
      _lists.putIfAbsent(stage, () => _capped(_optionsOf(stages[stage])));

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

  /// Một bước của lượt thô. Lượt thô lọc từ hai tầng luôn mở
  /// ([SafetyTier.direct], [SafetyTier.kick]) và giữ thứ tự, nên là tập con
  /// của lượt đầy đủ. Xong lượt thì dừng ở điểm hỏi hay sang lượt đầy đủ.
  void _coarseUnit() {
    if (!_coarseBuilt) {
      for (var i = 0; i < stages.length; i++) {
        final tier = stages[i].tier;
        if (tier == SafetyTier.direct || tier == SafetyTier.kick) {
          _coarseOptions.addAll(_listOf(i).where(isCoarseOption));
        }
      }
      _coarseBuilt = true;
    }
    if (_coarseCursor < _coarseOptions.length) {
      final e = evaluateOption(
          context, _coarseCursor, _coarseOptions[_coarseCursor], _coarseLookup,
          bound: prune ? _coarseBest?.total : null);
      if (e != null && beats(e, _coarseBest)) _coarseBest = e;
      _coarseCursor++;
      return;
    }
    final best = _coarseBest;
    final shot = best == null ? null : buildSafetyShot(context, best, _coarseLookup.trace);
    _coarseResult = shot;
    // Không có cú hợp lệ, hay có mà chưa thủ tốt: tìm tiếp luôn, không hỏi
    // (có cú thì PlannerJob hiện nó tạm trong lúc tìm).
    _phase = shot != null && isGoodSafety(shot) ? _Phase.checkpoint : _Phase.full;
  }

  /// Một bước của lượt đầy đủ — đúng việc tìm trước khi có lượt thô.
  void _fullUnit() {
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
        _options.addAll(_listOf(_nextStage));
      }
      _nextStage++;
    } else {
      final best = _best;
      final rough = _coarseResult;
      // Lượt thô là tập con của lượt đầy đủ, nên best không thể kém hơn.
      // Bằng điểm thì giữ cú đang hiện, khỏi dựng lại.
      if (rough != null && (best == null || best.total >= rough.total)) {
        _result = rough;
      } else {
        _result = best == null ? null : buildSafetyShot(context, best, _lookup.trace);
      }
      _phase = _Phase.done;
    }
  }

  /// Một đơn vị việc. true khi vừa chạy đúng một lần dò hay mô phỏng mới;
  /// false khi xong, đang chờ ở điểm hỏi, hay đã hủy mà không cần lần nào.
  bool work() {
    while (!_cancelled && (_phase == _Phase.coarse || _phase == _Phase.full)) {
      try {
        if (_phase == _Phase.coarse) {
          _coarseUnit();
        } else {
          _fullUnit();
        }
      } on _MissingAim catch (m) {
        final o = m.option;
        _tried.add(o.rails.length);
        _aims[o] = aimSafety(o, cue: context.cue, physics: physics, table: context.table);
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
  /// nhất của lát này không còn vừa ngân sách. Dừng ở điểm hỏi. Stopwatch chỉ
  /// quyết định *khi nào* dừng, không bao giờ quyết định *tính gì*.
  void step({Duration budget = safetySliceBudget, int? maxSimulations}) {
    final clock = Stopwatch()..start();
    var simulated = 0;
    var longest = Duration.zero;
    while (!isDone && !atCheckpoint && !_cancelled) {
      final started = clock.elapsed;
      if (work()) simulated++;
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxSimulations != null && simulated >= maxSimulations) break;
      if (clock.elapsed + longest > budget) break;
    }
  }

  late final SafetyLookup _lookup = _JobLookup(this, _options);
  late final SafetyLookup _coarseLookup = _JobLookup(this, _coarseOptions);
}

/// Tra theo chỉ số trong [options] của một lượt; bộ nhớ đệm chung.
class _JobLookup implements SafetyLookup {
  _JobLookup(this.job, this.options);
  final SafetyJob job;
  final List<SafetyOption> options;

  @override
  AimResult? aim(int index) {
    final o = options[index];
    if (job._aims.containsKey(o)) return job._aims[o];
    throw _MissingAim(o);
  }

  @override
  ShotTrace? trace(SimKey key) {
    if (job._sims.containsKey(key)) return job._sims[key];
    throw _MissingSim(key);
  }
}

class _MissingAim implements Exception {
  const _MissingAim(this.option);
  final SafetyOption option;
}

class _MissingSim implements Exception {
  const _MissingSim(this.key);
  final SimKey key;
}

/// Chạy một mạch tới hết, qua điểm hỏi luôn như khi người dùng bấm "Tính
/// tiếp" — cho test, công cụ dò bàn và đo tốc độ.
SafetyShot? searchToEnd(SafetyContext c, {SafetyPhysics physics = const SafetyPhysics()}) {
  final job = SafetyJob(c, physics: physics);
  while (!job.isDone) {
    job.resume();
    job.step(budget: const Duration(days: 1));
  }
  return job.result;
}
