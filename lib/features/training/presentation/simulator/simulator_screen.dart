import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_panel.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

enum _Ball { cue, object }

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5.
///
/// State cục bộ: không có gì để lưu hay chia sẻ, rời màn là mất.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  /// Khoá của bàn, để test quy đổi toạ độ bàn ra điểm chạm trên màn.
  static const tableKey = Key('simulator-table');

  /// Bố cục mở màn: một cú cắt nhẹ, hợp lệ.
  static const initialCue = Vec2(80, 90);
  static const initialObject = Vec2(170, 50);

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

  Vec2 _cue = SimulatorScreen.initialCue;
  Vec2 _object = SimulatorScreen.initialObject;
  Pocket? _pocketOverride;
  Stroke _stroke = Stroke.stun;
  double _power = powerPresets[1];
  SideSpin _spin = const SideSpin.none();
  _Ball? _dragging;

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

  void _onPanStart(DragStartDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    final grab = _table.radius * _grabRadii;
    final toCue = p.distanceTo(_cue);
    final toObject = p.distanceTo(_object);
    if (toCue > grab && toObject > grab) return;
    _dragging = toCue <= toObject ? _Ball.cue : _Ball.object;
  }

  void _onPanUpdate(DragUpdateDetails details, TableLayout layout) {
    final dragging = _dragging;
    if (dragging == null) return;
    final other = dragging == _Ball.cue ? _object : _cue;
    final moved =
        _separate(_table.clamp(layout.toTable(details.localPosition)), other);
    setState(() {
      if (dragging == _Ball.cue) {
        _cue = moved;
      } else {
        _object = moved;
      }
      // Kéo bi là bố cục mới: quay về tự chọn lỗ.
      _pocketOverride = null;
    });
  }

  /// Thả đè lên bi kia thì đẩy về vừa chạm nhau.
  ///
  /// Đẩy xa hơn đúng một đường kính một chút: đặt đúng `D` thì sai số
  /// làm tròn có thể cho ra 5.7149999 và lõi báo hai bi chồng nhau.
  Vec2 _separate(Vec2 p, Vec2 other) {
    final gap = p - other;
    if (gap.length >= _table.ballDiameter) return p;
    final dir = gap.isZero ? const Vec2(1, 0) : gap.normalized;
    return _table.clamp(other + dir * (_table.ballDiameter + 1e-6));
  }

  void _onTapUp(TapUpDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    for (final pocket in Pocket.values) {
      if (p.distanceTo(_table.pocketPosition(pocket)) <= _pocketTapRadius) {
        setState(() => _pocketOverride = pocket);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot();
    final geometry = switch (shot) {
      Makeable(:final geometry) => geometry,
      _ => null,
    };
    final path = geometry == null
        ? null
        : simulateCueBall(geometry,
            stroke: _stroke, power: _power, spin: _spin, table: _table);
    final advice = geometry == null
        ? const <Advice>[]
        : scratchAdvice(geometry,
            stroke: _stroke, power: _power, spin: _spin, table: _table);
    final scene = SimulatorScene(
      cue: _cue,
      object: _object,
      pocket: geometry?.pocket ?? _pocketOverride,
      geometry: geometry,
      path: path,
      riskPocket: advice.whereType<OverhitRisk>().firstOrNull?.pocket,
    );

    return PcRootScaffold(
      title: Vi.simTitle,
      // Bàn nằm ngoài vùng cuộn: kéo dọc trên bàn là kéo bi, không cuộn trang.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AspectRatio(
              aspectRatio: TableLayout.aspectRatio(_table),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout =
                      TableLayout(size: constraints.biggest, table: _table);
                  return Semantics(
                    label: Vi.simSummary(shot, path),
                    child: GestureDetector(
                      key: SimulatorScreen.tableKey,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (d) => _onPanStart(d, layout),
                      onPanUpdate: (d) => _onPanUpdate(d, layout),
                      onPanEnd: (_) => _dragging = null,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SimulatorPanel(
                shot: shot,
                path: path,
                advice: advice,
                stroke: _stroke,
                power: _power,
                spin: _spin,
                onStroke: (v) => setState(() => _stroke = v),
                onPower: (v) => setState(() => _power = v),
                onSpin: (v) => setState(() => _spin = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
