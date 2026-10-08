import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_shell_scaffold.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/separate.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/step_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_panel_layout.dart';

/// Màn từng bước — spec 2026-10-07 mục 7.
///
/// Tính từng bước giữa các khung hình (cùng cách gợi ý chống chết cái của
/// màn mô phỏng): bước 1 hiện ngay khi xong, các bước sau tính tiếp.
class PlannerStepsView extends StatefulWidget {
  const PlannerStepsView({
    required this.setup,
    required this.onEditTable,
    this.aim = aimShot,
    this.safety = const SafetyPhysics(),
    this.maxSimulationsPerFrame,
    this.maxZoneRowsPerFrame,
    super.key,
  });

  static const tableKey = Key('planner-steps-table');
  static const shotDoneKey = Key('planner-shot-done');
  static const backKey = Key('planner-back');

  final TableSetup setup;

  /// *Sửa bàn*: về màn nhập bàn, giữ nguyên các bi.
  final VoidCallback onEditTable;

  /// Lõi dò và mô phỏng; test thay để ép lõi quá giờ.
  @visibleForTesting
  final AimShotFn aim;

  /// Lõi của việc tìm cú thủ; test thay để bước phòng thủ ra nhanh.
  @visibleForTesting
  final SafetyPhysics safety;

  /// Giới hạn số lần mô phỏng mỗi khung hình, để test thấy được lúc kế
  /// hoạch mới tính xong một phần. null là theo `sliceBudget`.
  @visibleForTesting
  final int? maxSimulationsPerFrame;

  /// Giới hạn số hàng lưới vùng điều mỗi khung hình, để test thấy được lúc
  /// vùng điều mới hiện một phần. null là theo ngân sách thời gian.
  @visibleForTesting
  final int? maxZoneRowsPerFrame;

  @override
  State<PlannerStepsView> createState() => _PlannerStepsViewState();
}

class _PlannerStepsViewState extends State<PlannerStepsView> {
  /// Ngân sách lưới vùng điều mỗi khung hình, bằng `sliceBudget`: cùng
  /// khung hình còn một lát kế hoạch và phần vẽ, cộng lại vẫn dưới 16 ms.
  static const _zoneBudget = Duration(milliseconds: 4);

  late TableSetup _planned;
  late CandidateFinder _finder;
  PlannerJob? _job;
  List<PlanStep> _steps = const [];
  bool _done = false;
  int _view = 0;

  /// Đang đặt lại bi cái: chỗ bi cái đang kéo tới; null khi không.
  Vec2? _resetCue;

  /// Ngón tay đã bắt được bi cái lúc bắt đầu kéo.
  bool _draggingCue = false;

  /// Lưới vùng điều theo bước, tính dần; giữ cả lưới dở khi đổi bước.
  final _zones = <int, ZoneGridJob>{};

  /// Lưới đang được tính tiếp mỗi khung hình: luôn là lưới của bước đang xem.
  ZoneGridJob? _zonePumping;

  @override
  void initState() {
    super.initState();
    _start(widget.setup);
  }

  @override
  void dispose() {
    _job?.cancel();
    _job = null;
    super.dispose();
  }

  /// Kế hoạch mới cho [setup]: bỏ việc tính cũ, bắt đầu lại từ bước 1.
  void _start(TableSetup setup) {
    _job?.cancel();
    final job = PlannerJob(setup, aim: widget.aim, safety: widget.safety);
    _planned = setup;
    _finder = CandidateFinder(game: setup.game, table: setup.table);
    _job = job;
    _steps = const [];
    _done = false;
    _view = 0;
    _resetCue = null;
    _draggingCue = false;
    _zones.clear();
    _zonePumping = null;
    _schedule(job);
  }

  void _schedule(PlannerJob job) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => _pump(job));
    SchedulerBinding.instance.scheduleFrame();
  }

  void _pump(PlannerJob job) {
    // Rời màn, sửa bàn hay tính lại từ chỗ mới: bỏ việc cũ.
    if (!mounted || !identical(job, _job)) return;
    final events = job.step(maxSimulations: widget.maxSimulationsPerFrame);
    if (events.isNotEmpty) {
      setState(() {
        for (final e in events) {
          switch (e) {
            case StepReady(:final step):
              _steps = [..._steps, step];
            case PlanDone():
              _done = true;
          }
        }
      });
    }
    if (!job.isDone) _schedule(job);
  }

  int get _total => _done ? _steps.length : (_job?.totalSteps ?? _steps.length);

  /// Bi còn trên bàn trước bước [index].
  List<PlacedBall> _ballsBefore(int index) {
    final gone = {for (final s in _steps.take(index)) ?s.ballNum};
    return [for (final b in _planned.balls) if (!gone.contains(b.number)) b];
  }

  PlacedBall _ball(int number) => _planned.balls.firstWhere((b) => b.number == number);

  /// Vùng điều của bước [index]: các ô đã tính tới giờ. Lưới tính vài hàng
  /// mỗi khung hình (tính một mạch thì khung hình bước 1 hiện ra bị rớt),
  /// hiện dần trong khoảng 0,1–0,2 giây; tính xong thì nhớ.
  List<ZoneCell> _zoneFor(int index) {
    if (_steps[index].nextBallNum == null) return const [];
    final job = _zones.putIfAbsent(
        index, () => ZoneGridJob(after: _ballsBefore(index + 1), next: _finder));
    if (!job.isDone && !identical(job, _zonePumping)) {
      _zonePumping = job;
      _scheduleZone(job);
    }
    return job.cells;
  }

  void _scheduleZone(ZoneGridJob job) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => _pumpZone(job));
    SchedulerBinding.instance.scheduleFrame();
  }

  void _pumpZone(ZoneGridJob job) {
    // Đã sang bước khác hay tính lại: lưới này dừng, quay lại thì tính tiếp.
    if (!mounted || !identical(job, _zonePumping)) return;
    job.step(budget: _zoneBudget, maxRows: widget.maxZoneRowsPerFrame);
    if (job.isDone) {
      _zonePumping = null;
    } else {
      _scheduleZone(job);
    }
    setState(() {});
  }

  PlannerScene _scene() {
    final reset = _resetCue;
    if (reset != null) return PlannerScene(cue: reset, balls: _ballsBefore(_view + 1));
    if (_steps.isEmpty) return PlannerScene(cue: _planned.cue, balls: _planned.balls);
    final step = _steps[_view];
    // Bi của bước đang xem và 2 bước kế tiếp vẽ rõ; các bi khác còn trên bàn
    // vẽ mờ (PRD §6.3).
    final shown = {for (final s in _steps.skip(_view).take(3)) ?s.ballNum};
    return PlannerScene(
      cue: step.cbFrom,
      balls: [for (final n in shown) _ball(n)],
      ghosts: [
        for (final b in _ballsBefore(_view))
          if (!shown.contains(b.number)) b,
      ],
      step: step,
      preview: _view + 1 < _steps.length ? _steps[_view + 1] : null,
      zone: _zoneFor(_view),
    );
  }

  Future<void> _askCueStopped() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Vi.planCueStoppedQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Vi.planResetCue),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Vi.planYes),
          ),
        ],
      ),
    );
    if (!mounted || reset == null) return;
    setState(() {
      if (reset) {
        _resetCue = _steps[_view].trace!.cueEnd;
      } else {
        _view++;
      }
    });
  }

  /// Chỉ bắt bi cái khi chạm gần nó — cùng bán kính chạm của màn mô
  /// phỏng; chạm chỗ khác rồi kéo thì bi không nhảy.
  void _onPanStart(Offset local, TableLayout layout) {
    final cue = _resetCue;
    _draggingCue = cue != null && layout.toTable(local).distanceTo(cue) <= layout.ballGrab;
  }

  void _dragCue(Offset local, TableLayout layout) {
    if (!_draggingCue) return;
    final at = separateFromAll(
      layout.toTable(local),
      [for (final b in _ballsBefore(_view + 1)) b.pos],
      table: _planned.table,
    );
    if (at != null) setState(() => _resetCue = at);
  }

  /// Kế hoạch mới từ chỗ bi cái dừng thật, với các bi còn lại (spec 4.5).
  void _recompute() {
    final cue = _resetCue!;
    final pocketed = {for (final s in _steps.take(_view + 1)) ?s.ballNum};
    setState(() => _start(_planned.without(pocketed).withCue(cue)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scene = _scene();
    final resetting = _resetCue != null;
    final step = _steps.isEmpty ? null : _steps[_view];
    final atEnd = _done && _view == _steps.length - 1;

    return TablePanelLayout(
      table: _planned.table,
      tableBuilder: (layout) => Semantics(
        label: resetting
            ? Vi.planResetSummary
            : Vi.planSummary(step, index: step == null ? _steps.length : _view, total: _total),
        child: GestureDetector(
          key: PlannerStepsView.tableKey,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: resetting ? (d) => _onPanStart(d.localPosition, layout) : null,
          onPanUpdate: resetting ? (d) => _dragCue(d.localPosition, layout) : null,
          onPanEnd: resetting ? (_) => _draggingCue = false : null,
          onPanCancel: resetting ? () => _draggingCue = false : null,
          child: CustomPaint(size: layout.size, painter: PlannerPainter(scene)),
        ),
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chú giải các lớp ngay dưới bàn (spec mục 7.1).
          for (final line in Vi.planLegend) Text(line, style: text.bodySmall),
          const SizedBox(height: 12),
          if (!_done) Text(Vi.planComputing(_steps.length + 1, _total), style: text.bodyMedium),
          if (step != null && !resetting)
            _LinesCard(
                lines: planStepLines(step, index: _view, total: _total, table: _planned.table)),
          if (scene.preview case final preview?)
            _PreviewCard(
                lines: planStepLines(preview,
                    index: _view + 1, total: _total, table: _planned.table)),
          const SizedBox(height: 8),
          if (resetting) Text(Vi.planResetHint, style: text.bodySmall),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: PlannerStepsView.backKey,
                onPressed: _view > 0 && !resetting ? () => setState(() => _view--) : null,
                child: const Text(Vi.planBack),
              ),
              if (resetting)
                FilledButton(onPressed: _recompute, child: const Text(Vi.planRecompute))
              else if (atEnd)
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(Vi.planFinish),
                )
              else
                FilledButton(
                  key: PlannerStepsView.shotDoneKey,
                  // Bước cuối đã tính mà kế hoạch chưa xong: chờ bước kế tiếp.
                  onPressed: _view + 1 < _steps.length ? _askCueStopped : null,
                  child: const Text(Vi.planShotDone),
                ),
              TextButton(onPressed: widget.onEditTable, child: const Text(Vi.planEditTable)),
            ],
          ),
          const SizedBox(height: 12),
          Text(Vi.simDisclaimer, style: text.bodySmall),
          // Cuộn hết thì nút Coach nổi không che ô XEM TRƯỚC hay nút bấm.
          const SizedBox(height: PcShellScaffold.fabClearance),
        ],
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return PcCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l, style: style),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bước kế tiếp: viền đứt, nhạt hơn (PRD §6.4).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Opacity(
        opacity: 0.6,
        child: CustomPaint(
          painter: const DashedBorderPainter(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Vi.planPreviewLabel, style: theme.labelSmall),
                for (final l in lines) Text(l, style: theme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
