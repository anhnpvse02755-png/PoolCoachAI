import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_panel_layout.dart';

/// Màn nhập bàn — spec 2026-10-07 mục 6. Bàn là [draft] của màn cha, nên
/// *Sửa bàn* quay lại thấy nguyên các bi.
class PlannerSetupView extends StatefulWidget {
  const PlannerSetupView({
    required this.draft,
    required this.onChanged,
    required this.onPlan,
    super.key,
  });

  static const tableKey = Key('planner-setup-table');
  static const planKey = Key('planner-plan');

  final SetupDraft draft;
  final ValueChanged<SetupDraft> onChanged;
  final VoidCallback onPlan;

  @override
  State<PlannerSetupView> createState() => _PlannerSetupViewState();
}

class _PlannerSetupViewState extends State<PlannerSetupView> {
  bool _draggingCue = false;
  int? _dragging;

  void _onPanStart(DragStartDetails d, TableLayout layout) {
    final p = layout.toTable(d.localPosition);
    final draft = widget.draft;
    final grab = layout.ballGrab;
    final cue = draft.cue;
    final ball = draft.ballAt(p, grab);
    final toCue = cue == null ? double.infinity : p.distanceTo(cue);
    final toBall = ball == null ? double.infinity : p.distanceTo(draft.placed[ball].pos);
    if (toCue <= grab && toCue <= toBall) {
      _draggingCue = true;
    } else if (ball != null) {
      _dragging = ball;
    }
  }

  void _onPanUpdate(DragUpdateDetails d, TableLayout layout) {
    final p = layout.toTable(d.localPosition);
    if (_draggingCue) {
      widget.onChanged(widget.draft.moveCue(p));
    } else if (_dragging case final i?) {
      widget.onChanged(widget.draft.move(i, p));
    }
  }

  void _onPanEnd() {
    _draggingCue = false;
    _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final text = Theme.of(context).textTheme;

    Widget chips<T>(String label, List<T> values, T selected, String Function(T) name,
            ValueChanged<T> onPick) =>
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final v in values)
                    ChoiceChip(
                      label: Text(name(v)),
                      selected: v == selected,
                      onSelected: (_) => onPick(v),
                    ),
                ],
              ),
            ],
          ),
        );

    return TablePanelLayout(
      table: draft.table,
      tableBuilder: (layout) => Semantics(
        label: Vi.planSetupSummary(hasCue: draft.cue != null, balls: draft.balls.length),
        child: GestureDetector(
          key: PlannerSetupView.tableKey,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => widget.onChanged(draft.tap(layout.toTable(d.localPosition))),
          onPanStart: (d) => _onPanStart(d, layout),
          onPanUpdate: (d) => _onPanUpdate(d, layout),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: CustomPaint(
            size: layout.size,
            painter: PlannerPainter(PlannerScene(cue: draft.cue, balls: draft.balls)),
          ),
        ),
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chips(Vi.planGameLabel, GameType.values, draft.game, Vi.planGame,
              (g) => widget.onChanged(draft.withGame(g))),
          if (draft.game == GameType.eightBall) ...[
            chips(Vi.planGroupLabel, BallGroup.values, draft.group, Vi.planGroup,
                (g) => widget.onChanged(draft.withGroup(g))),
            chips(Vi.planPlacingLabel, BallRole.values, draft.placing, Vi.planPlacing,
                (r) => widget.onChanged(draft.withPlacing(r))),
          ],
          const SizedBox(height: 12),
          if (draft.cue == null)
            Text(Vi.planCueHint, style: text.bodySmall)
          else if (draft.game != GameType.eightBall)
            Text(Vi.planOrderHint, style: text.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: draft.cue == null ? null : () => widget.onChanged(draft.undo()),
                child: const Text(Vi.planUndo),
              ),
              OutlinedButton(
                onPressed: draft.cue == null ? null : () => widget.onChanged(draft.clear()),
                child: const Text(Vi.planClear),
              ),
              FilledButton(
                key: PlannerSetupView.planKey,
                onPressed: draft.canPlan ? widget.onPlan : null,
                child: const Text(Vi.planStart),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(Vi.simDisclaimer, style: text.bodySmall),
        ],
      ),
    );
  }
}
