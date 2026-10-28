import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';
import 'package:poolcoachai/domain/skill_test/certification_summary.dart';

/// Mục Chứng nhận của Hồ sơ: các bài đã được kiểm tra đạt, theo nhóm kỹ năng.
/// Chưa có chứng nhận thì nói thẳng, kèm bài gần sẵn sàng nhất nếu có thật.
class CertificationSection extends ConsumerWidget {
  const CertificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(certificationSummaryProvider);
    if (async.hasError && !async.isLoading) {
      return const Text(Vi.skillTestDataError);
    }
    final summary = async.hasValue && !async.isLoading ? async.value : null;
    if (summary == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final closest = summary.closest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Vi.certificationTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.groups.isEmpty) ...[
          const Text(Vi.certificationEmpty),
          if (closest == null)
            Text(Vi.certificationNoProgress, style: theme.textTheme.bodySmall)
          else
            // Không để dòng cụt: sẵn sàng thì tới bài kiểm tra, chưa thì tới bài tập.
            InkWell(
              onTap: () => context.go(
                closest.ready
                    ? Routes.skillTest(closest.drill.id)
                    : Routes.drill(closest.drill.id),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  closest.ready
                      ? Vi.homeSkillTestReady(closest.drill.name, 0)
                      : Vi.certificationClosest(closest.drill.name, closest.passCount),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ] else
          for (final g in summary.groups) _GroupView(group: g),
      ],
    );
  }
}

class _GroupView extends StatelessWidget {
  const _GroupView({required this.group});

  final CertificationGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PcSkillChip(category: group.cat),
          if (group.complete) ...[
            const SizedBox(height: AppSpacing.xs),
            const Text(Vi.certificationGroupDone),
            Text(Vi.skillTestNoNextLevel, style: theme.textTheme.bodySmall),
          ],
          for (final e in group.entries) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(Vi.certificationEntry(
              e.drill.name,
              e.certification.drillLevel,
              e.certification.certifiedAt,
            )),
            // Tiêu chí lấy từ ảnh chụp lúc chấm, không phải bài hiện tại.
            if (Vi.criterionSnapshot(
                  e.certification.passThreshold,
                  e.certification.target,
                  e.drill.unit,
                )
                case final criterion?)
              Text(criterion, style: theme.textTheme.bodySmall),
            Text(
              Vi.certificationEvidence(
                e.certification.tableSize,
                e.certification.score,
                e.certification.attempts,
                e.drill.unit,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
