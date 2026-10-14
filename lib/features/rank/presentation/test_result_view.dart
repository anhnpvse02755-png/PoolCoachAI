import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';

/// Kết quả một lần kiểm tra đã hoàn tất (spec mục 7.3 bước 4): điểm từng
/// bài, tổng điểm BU, mức BU, Fargo tham chiếu và câu kết quả hạng.
class TestResultView extends ConsumerWidget {
  const TestResultView({required this.testId, this.outcome, super.key});

  final String testId;

  /// Có khi vừa hoàn tất trong phiên này; null khi xem lại.
  final TestCompleted? outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(testSnapshotProvider(testId)).value;
    if (snap == null || !snap.test.isCompleted) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = snap.test;
    final version = t.examIIVersion!;
    final band = bandForBuScore(t.totalScore!);
    final text = Theme.of(context).textTheme;
    final o = outcome;

    List<Widget> lines(List<BuDrill> drills) => [
          for (final d in drills)
            Text(Vi.buDrillScoreLine(d.id, snap.scoreOf([d]), d.maxScore)),
        ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(Vi.buResultTitle, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Align(alignment: Alignment.centerLeft, child: PcRankBadge(rank: band.rank, showWord: true)),
        const SizedBox(height: AppSpacing.sm),
        Text(Vi.buTotal(t.totalScore!), style: text.titleMedium),
        Text(Vi.buBand(band)),
        Text(Vi.buFargo(band)),
        if (o != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(Vi.rankOutcome(o.outcome, o.before, o.result), style: text.titleSmall),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(Vi.buExamScoreLine(BuExam.fundamentals, t.examIScore!, examIMax), style: text.titleSmall),
        ...lines(examIDrills),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buExamScoreLine(BuExam.skills, t.examIIScore!, examIIMax(version)),
            style: text.titleSmall),
        ...lines(examIIDrills(version)),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.rankDisclaimer, style: text.bodySmall),
        Text(Vi.buSourceLine, style: text.bodySmall),
      ],
    );
  }
}
