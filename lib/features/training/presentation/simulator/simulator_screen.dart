import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_panel.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

enum _Ball { cue, object }

/// Cùng chữ ký với `aimShot`, để test thay lõi (vd lõi quá giờ).
typedef AimShotFn = AimedShot Function({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  SideSpin spin,
  required double power,
  CueElevation elevation,
  TableSpec table,
  bool compensate,
  bool withUncompensated,
});

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5, chạy trên lõi vật lý của
/// spec 2026-10-02 mục 6.
///
/// State cục bộ: không có gì để lưu hay chia sẻ, rời màn là mất.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key, this.aim = aimShot});

  /// Lõi dò và mô phỏng cú đánh; test thay để ép lõi quá giờ hay đếm
  /// số lần gọi.
  @visibleForTesting
  final AimShotFn aim;

  /// Khoá của bàn, để test quy đổi toạ độ bàn ra điểm chạm trên màn.
  static const tableKey = Key('simulator-table');

  /// Bố cục mở màn: một cú cắt nhẹ, hợp lệ.
  static const initialCue = Vec2(80, 90);
  static const initialObject = Vec2(170, 50);

  /// Mỗi khung hình chạy gợi ý chống chết cái tối đa ngần này mili giây,
  /// để Chrome vẫn vẽ kịp 60 khung hình/giây trong lúc chờ.
  static const adviceSliceMs = 8;

  /// Có ném thì mới có đường "không bù ném" để xem: cần áp phê (SIT) hoặc
  /// góc cắt hiện trên màn khác 0° (CIT).
  static bool canShowUncompensated(ShotGeometry g, SideSpin spin) =>
      !spin.isNone || g.angle.round() != 0;

  /// Thả đè lên bi kia thì đẩy về vừa chạm nhau.
  ///
  /// Đẩy xa hơn đúng một đường kính một chút: đặt đúng `D` thì sai số
  /// làm tròn có thể cho ra 5.7149999 và lõi báo hai bi chồng nhau.
  ///
  /// Sát băng thì hướng đẩy có thể chỉ ra ngoài bàn, kẹp lại là chồng tiếp.
  /// Khi đó thử trượt dọc theo băng (đẩy theo từng trục, về phía điểm thả);
  /// không cách nào tách được thì giữ [previous] — bi không nhảy.
  @visibleForTesting
  static Vec2 separate(Vec2 p, Vec2 other, Vec2 previous,
      {TableSpec table = TableSpec.nineFoot}) {
    final d = table.ballDiameter;
    if ((p - other).length >= d) return p;
    bool clear(Vec2 v) => v.distanceTo(other) >= d;

    final gap = p - other;
    final dir = gap.isZero ? const Vec2(1, 0) : gap.normalized;
    final direct = table.clamp(other + dir * (d + 1e-6));
    if (clear(direct)) return direct;

    final sx = gap.x < 0 ? -1.0 : 1.0;
    final sy = gap.y < 0 ? -1.0 : 1.0;
    final slides = [
      Vec2(sx, 0), Vec2(-sx, 0), Vec2(0, sy), Vec2(0, -sy), //
    ];
    for (final s in slides) {
      final slid = table.clamp(other + s * (d + 1e-6));
      if (clear(slid)) return slid;
    }
    return previous;
  }

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  static const _table = TableSpec.nineFoot;

  /// Chạm trong 1.5 bán kính quanh tâm bi là bắt được bi — ngón tay
  /// không phải trúng từng milimét.
  static const _grabRadii = 1.5;

  /// Chạm trong bán kính này quanh điểm lỗ là chọn lỗ đó, cm.
  static const _pocketTapRadius = 10.0;

  /// Sàn bán kính chạm trên màn, tính bằng px logic. Trên điện thoại bàn co
  /// còn ~1.3 px/cm, nên bán kính tính theo cm chỉ còn vài px — nhỏ hơn
  /// đầu ngón tay. Lấy lớn hơn giữa bán kính cm và sàn này.
  static const _minTouchPx = 24.0;

  /// Lề quanh bàn — kích thước bàn tính trên phần còn lại sau lề này.
  static const _tablePadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  Vec2 _cue = SimulatorScreen.initialCue;
  Vec2 _object = SimulatorScreen.initialObject;
  Pocket? _pocketOverride;
  Stroke _stroke = Stroke.stun;
  double _power = powerPresets[1];
  SideSpin _spin = const SideSpin.none();
  CueElevation _elevation = CueElevation.normal;
  bool _showUncompensated = false;
  _Ball? _dragging;

  /// Gợi ý chống chết cái; null khi đang tính (spec mục 5, quyết định 13).
  List<Advice>? _advice;
  ScratchAdviceJob? _job;

  /// Cú đã dò gần nhất và đúng đầu vào của nó. Gợi ý tính xong, bật tắt
  /// công tắc, đổi khung màn đều dựng lại màn mà không đổi cú đánh: dùng
  /// lại kết quả thay vì dò và mô phỏng lại từ đầu.
  (Vec2, Vec2, Pocket, Stroke, SideSpin, double, CueElevation, bool)? _aimKey;

  /// null khi lõi quá maxSimTime cho cú này.
  AimedShot? _aimed;

  @override
  void initState() {
    super.initState();
    _startAdvice();
  }

  @override
  void dispose() {
    _job = null;
    super.dispose();
  }

  /// Lỗ người chơi chạm thì dùng lỗ đó; không thì tự chọn (Priority 1).
  ShotResult? _shot() {
    final override = _pocketOverride;
    if (override != null) {
      return evaluateShot(
          cue: _cue, object: _object, pocket: override, table: _table);
    }
    final best = bestPocket(cue: _cue, object: _object, table: _table);
    return best == null ? null : Makeable(best);
  }

  /// Bắt đầu tính gợi ý cho bố cục và nút chỉnh hiện tại, từng chút một
  /// giữa các khung hình. Gọi khi thả tay hoặc đổi nút chỉnh — không gọi
  /// mỗi khung hình lúc kéo, vì một lần tính đắt gần trăm lần mô phỏng.
  void _startAdvice() {
    final shot = _shot();
    if (shot is! Makeable) {
      _job = null;
      _advice = const [];
      return;
    }
    final job = ScratchAdviceJob(shot.geometry,
        stroke: _stroke,
        power: _power,
        spin: _spin,
        elevation: _elevation,
        table: _table);
    _job = job;
    _advice = null;
    _scheduleAdvice(job);
  }

  void _scheduleAdvice(ScratchAdviceJob job) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => _pumpAdvice(job));
    SchedulerBinding.instance.scheduleFrame();
  }

  void _pumpAdvice(ScratchAdviceJob job) {
    // Bố cục đã đổi từ lúc bắt đầu: bỏ kết quả cũ.
    if (!mounted || !identical(job, _job)) return;
    final slice = Stopwatch()..start();
    List<Advice>? done;
    while (done == null &&
        slice.elapsedMilliseconds < SimulatorScreen.adviceSliceMs) {
      done = job.step();
    }
    if (done == null) {
      _scheduleAdvice(job);
      return;
    }
    setState(() {
      _advice = done;
      _job = null;
    });
  }

  /// Hết ném thì tắt công tắc *Xem nếu không bù ném*: không thì công tắc
  /// khoá mà vẫn hiện bật, và đường đỏ tự hiện lại khi có ném trở lại mà
  /// người chơi không bấm gì.
  void _dropUncompensatedIfNoThrow() {
    final shot = _shot();
    if (shot is! Makeable ||
        !SimulatorScreen.canShowUncompensated(shot.geometry, _spin)) {
      _showUncompensated = false;
    }
  }

  /// Đổi một nút chỉnh: tính lại cú đánh ngay, gợi ý tính dần.
  void _change(VoidCallback update) {
    setState(() {
      update();
      _dropUncompensatedIfNoThrow();
      _startAdvice();
    });
  }

  void _onPanStart(DragStartDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    final grab = math.max(_table.radius * _grabRadii, _minTouchPx / layout.scale);
    final toCue = p.distanceTo(_cue);
    final toObject = p.distanceTo(_object);
    if (toCue > grab && toObject > grab) return;
    _dragging = toCue <= toObject ? _Ball.cue : _Ball.object;
  }

  void _onPanUpdate(DragUpdateDetails details, TableLayout layout) {
    final dragging = _dragging;
    if (dragging == null) return;
    final other = dragging == _Ball.cue ? _object : _cue;
    final moved = SimulatorScreen.separate(
        _table.clamp(layout.toTable(details.localPosition)),
        other,
        dragging == _Ball.cue ? _cue : _object);
    setState(() {
      if (dragging == _Ball.cue) {
        _cue = moved;
      } else {
        _object = moved;
      }
      // Kéo bi là bố cục mới: quay về tự chọn lỗ.
      _pocketOverride = null;
      _dropUncompensatedIfNoThrow();
      // Lúc kéo chỉ tính cú đang xem; gợi ý chờ tới khi thả tay.
      _job = null;
      _advice = null;
    });
  }

  void _onPanEnd() {
    if (_dragging == null) return;
    _dragging = null;
    setState(_startAdvice);
  }

  void _onTapUp(TapUpDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    final reach = math.max(_pocketTapRadius, _minTouchPx / layout.scale);
    for (final pocket in Pocket.values) {
      if (p.distanceTo(_table.pocketPosition(pocket)) <= reach) {
        _change(() => _pocketOverride = pocket);
        return;
      }
    }
  }

  /// Cú đã dò cho [g]; null khi lõi quá maxSimTime.
  AimedShot? _aimFor(ShotGeometry g, bool showRed) {
    final key =
        (g.cue, g.object, g.pocket, _stroke, _spin, _power, _elevation, showRed);
    if (key == _aimKey) return _aimed;
    _aimKey = key;
    try {
      return _aimed = widget.aim(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        stroke: _stroke,
        spin: _spin,
        power: _power,
        elevation: _elevation,
        table: _table,
        withUncompensated: showRed,
      );
    } on SimulationTimeout {
      // Lõi chạy quá maxSimTime (spec mục 4.5): không có đường đi để vẽ.
      // Ném tiếp trong build thì cả màn thành ô lỗi; vẽ hình học thôi.
      return _aimed = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot();
    final geometry = switch (shot) {
      Makeable(:final geometry) => geometry,
      _ => null,
    };
    final canToggle = geometry != null &&
        SimulatorScreen.canShowUncompensated(geometry, _spin);
    final showRed = canToggle && _showUncompensated;
    // Đường đỏ tốn thêm một lần mô phỏng đủ mỗi khung kéo thả: chỉ tính
    // khi nó thật sự được vẽ.
    final aimed = geometry == null ? null : _aimFor(geometry, showRed);
    final cannotSimulate = geometry != null && aimed == null;
    final scene = SimulatorScene(
      cue: _cue,
      object: _object,
      pocket: geometry?.pocket ?? _pocketOverride,
      geometry: geometry,
      aimed: aimed,
      showUncompensated: showRed,
      riskPocket: _advice?.whereType<OverhitRisk>().firstOrNull?.pocket,
    );

    return PcRootScaffold(
      title: Vi.simTitle,
      // Bàn nằm ngoài vùng cuộn: kéo dọc trên bàn là kéo bi, không cuộn trang.
      body: LayoutBuilder(
        builder: (context, bodyConstraints) {
          // Trên Chrome desktop, cửa sổ ngang hơn dọc: bàn cao theo chiều
          // rộng mà không trần thì tràn RenderFlex và bảng điều khiển biến
          // mất. Ghim chiều cao bàn theo cái nhỏ hơn giữa "vừa bề ngang" và
          // "tối đa 55% chiều cao thân màn" — còn lại luôn dành cho bảng.
          //
          // Trần tính trên phần còn lại sau Padding của bàn: tính theo cả bề
          // ngang thì SizedBox bị ép hẹp mà giữ chiều cao, bàn méo tỉ lệ.
          final aspectRatio = TableLayout.aspectRatio(_table);
          final availableWidth = (bodyConstraints.maxWidth -
                  _tablePadding.horizontal)
              .clamp(0.0, double.infinity);
          final maxTableHeight = (bodyConstraints.maxHeight * 0.55 -
                  _tablePadding.vertical)
              .clamp(0.0, double.infinity);
          final widthLimitedHeight = availableWidth / aspectRatio;
          final tableHeight = widthLimitedHeight < maxTableHeight
              ? widthLimitedHeight
              : maxTableHeight;
          final tableWidth = tableHeight * aspectRatio;

          return Column(
            children: [
              Padding(
                padding: _tablePadding,
                child: Center(
                  child: SizedBox(
                    width: tableWidth,
                    height: tableHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layout = TableLayout(
                            size: constraints.biggest, table: _table);
                        return Semantics(
                          label: Vi.simSummary(shot, aimed,
                              elevation: _elevation,
                              showingUncompensated: showRed,
                              cannotSimulate: cannotSimulate),
                          child: GestureDetector(
                            key: SimulatorScreen.tableKey,
                            dragStartBehavior: DragStartBehavior.down,
                            onPanStart: (d) => _onPanStart(d, layout),
                            onPanUpdate: (d) => _onPanUpdate(d, layout),
                            onPanEnd: (_) => _onPanEnd(),
                            onPanCancel: _onPanEnd,
                            onTapUp: (d) => _onTapUp(d, layout),
                            child: CustomPaint(
                              size: constraints.biggest,
                              painter: TablePainter(scene),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SimulatorPanel(
                    shot: shot,
                    aimed: aimed,
                    cannotSimulate: cannotSimulate,
                    advice: _advice,
                    stroke: _stroke,
                    power: _power,
                    spin: _spin,
                    elevation: _elevation,
                    showUncompensated: _showUncompensated,
                    onStroke: (v) => _change(() => _stroke = v),
                    onPower: (v) => _change(() => _power = v),
                    onSpin: (v) => _change(() => _spin = v),
                    onElevation: (v) => _change(() => _elevation = v),
                    onShowUncompensated: canToggle
                        ? (v) => setState(() => _showUncompensated = v)
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
