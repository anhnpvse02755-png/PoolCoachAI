import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_setup_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';

/// Kế hoạch dọn bàn — spec 2026-10-07 mục 6–7. Một đường dẫn, hai màn: nhập
/// bàn và từng bước. State cục bộ: không có gì để lưu (lưu bàn đã bày nằm
/// ngoài phạm vi), rời màn là mất.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    this.aim = aimShot,
    this.initialDraft = const SetupDraft(),
    this.maxSimulationsPerFrame,
  });

  @visibleForTesting
  final AimShotFn aim;

  @visibleForTesting
  final SetupDraft initialDraft;

  @visibleForTesting
  final int? maxSimulationsPerFrame;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late SetupDraft _draft = widget.initialDraft;

  /// Bàn đang lập kế hoạch; null khi ở màn nhập bàn. Về màn nhập bàn là
  /// bỏ kế hoạch (màn từng bước hủy việc tính khi bị gỡ).
  TableSetup? _planned;

  @override
  Widget build(BuildContext context) {
    final planned = _planned;
    return PcRootScaffold(
      title: Vi.planTitle,
      body: planned == null
          ? PlannerSetupView(
              draft: _draft,
              onChanged: (d) => setState(() => _draft = d),
              onPlan: () => setState(() => _planned = _draft.toSetup()),
            )
          : PlannerStepsView(
              key: ObjectKey(planned),
              setup: planned,
              aim: widget.aim,
              maxSimulationsPerFrame: widget.maxSimulationsPerFrame,
              onEditTable: () => setState(() => _planned = null),
            ),
    );
  }
}
