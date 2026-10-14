import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/features/rank/presentation/rank_badge_line.dart';

/// Thẻ hạng của Hồ sơ (spec mục 7.4).
class RankCard extends ConsumerWidget {
  const RankCard({this.showDetailsLink = true, super.key});

  final bool showDetailsLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(playerRankProvider).value;
    final tests = ref.watch(buTestsProvider).value ?? const <BuTest>[];
    final active = ref.watch(activeTestProvider).value;
    final now = ref.watch(nowProvider)();
    BuTest? last;
    for (final t in tests) {
      if (t.isCompleted && (last == null || t.completedAt!.isAfter(last.completedAt!))) last = t;
    }
    final from = retestAvailableFrom(tests);
    final hasRank = rank?.rank != null;
    const tall = Size.fromHeight(48);

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasRank) RankBadgeLine(rank: rank!) else const Text(Vi.rankNone),
          if (rank?.warningRank != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(Vi.rankWarning(rank!.warningRank!),
                style: const TextStyle(color: AppColors.warning)),
          ],
          if (last != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(Vi.rankLastTest(last.completedAt!, last.totalScore!, last.resultRank!)),
          ],
          if (from != null && now.isBefore(from)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(Vi.buRetestFrom(from)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (active != null)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: tall),
              onPressed: () => context.push(Routes.rankTest),
              child: const Text(Vi.rankContinueTest),
            )
          else ...[
            if (!hasRank) ...[
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: tall),
                onPressed: () => context.push(Routes.onboardingRank),
                child: const Text(Vi.rankDetermine),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: tall),
              onPressed: () => context.push(Routes.rankTest),
              child: const Text(Vi.rankTakeTest),
            ),
          ],
          if (showDetailsLink)
            TextButton(
              onPressed: () => context.push(Routes.rank),
              child: const Text(Vi.rankDetails),
            ),
        ],
      ),
    );
  }
}

/// Lịch sử các lần kiểm tra đã xong (hoàn tất hoặc hủy), mới nhất trước.
class TestHistoryList extends ConsumerWidget {
  const TestHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = [
      for (final t in ref.watch(buTestsProvider).value ?? const <BuTest>[])
        if (!t.isActive) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Vi.rankHistoryTitle, style: Theme.of(context).textTheme.titleSmall),
        if (tests.isEmpty) const Text(Vi.rankHistoryEmpty),
        for (final t in tests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(t.isCompleted ? Icons.verified_outlined : Icons.cancel_outlined),
            title: Text(t.isCompleted
                ? Vi.rankHistoryCompleted(t.completedAt!, t.totalScore!, t.resultRank!)
                : Vi.rankHistoryCancelled(t.cancelledAt!)),
          ),
      ],
    );
  }
}

/// Đầu Trang chủ: huy hiệu nhỏ, hoặc thẻ *Xác định hạng của bạn* (spec mục 7.4).
class HomeRankHeader extends ConsumerWidget {
  const HomeRankHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playerRankProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final rank = async.value;
    if (rank?.rank != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: RankBadgeLine(rank: rank!),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      // Gọn một hàng: Trang chủ là chỗ của buổi tập hôm nay, thẻ hạng không
      // được đẩy chúng xuống dưới màn hình.
      child: PcCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Vi.homeRankCardTitle, style: Theme.of(context).textTheme.titleSmall),
                  Text(Vi.homeRankCardBody, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: () => context.push(Routes.onboardingRank),
              child: const Text(Vi.rankDetermine),
            ),
          ],
        ),
      ),
    );
  }
}
