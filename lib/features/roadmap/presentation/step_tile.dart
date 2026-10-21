import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';

/// Một bước của Lộ trình: tên, trạng thái, tiến độ, lý do và việc làm ngay.
class StepTile extends StatelessWidget {
  const StepTile({
    required this.step,
    required this.drill,
    required this.today,
    super.key,
  });

  final RoadmapStep step;
  final Drill? drill;
  final DateTime today;

  Widget? _action(BuildContext context) {
    switch (step.kind) {
      case StepKind.nhom || StepKind.baiTap
          when step.drillId != null && step.status != StepStatus.xong:
        return FilledButton(
          onPressed: () => context.go(Routes.drillSession(step.drillId!)),
          child: const Text(Vi.stepTrain),
        );
      case StepKind.lamBaiBu:
        final from = (step.reason as RetestFrom).from;
        if (from != null && today.isBefore(from)) return null;
        return FilledButton(
          onPressed: () => context.push(Routes.rankTest),
          child: const Text(Vi.stepOpenTest),
        );
      case StepKind.xacDinhHang:
        return FilledButton(
          onPressed: () => context.push(Routes.onboardingRank),
          child: const Text(Vi.goalNeedRank),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = _action(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Vi.stepTitle(step, drillName: drill?.name),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  Vi.stepStatus(step.status),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            if (step.kind == StepKind.nhom)
              Text(Vi.stepProgress(step.mastery, step.passStreak)),
            if (step.kind == StepKind.baiTap)
              Text(Vi.stepStreak(step.passStreak)),
            Text(Vi.stepReason(step.reason), style: theme.textTheme.bodySmall),
            if (step.estimate case final estimate?)
              Text(
                Vi.estimateLine(estimate),
                style: theme.textTheme.bodySmall,
              ),
            if (action != null)
              Align(
                alignment: Alignment.centerRight,
                child: action,
              ),
          ],
        ),
      ),
    );
  }
}
