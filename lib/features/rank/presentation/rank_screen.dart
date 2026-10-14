import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/features/rank/presentation/rank_card.dart';

/// Chi tiết hạng và lịch sử kiểm tra (spec mục 7.1).
class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(playerRankProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.rankScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const RankCard(showDetailsLink: false),
          const SizedBox(height: AppSpacing.md),
          if (rank.hasValue && rank.value?.rank != null && canUseQuestionnaire(rank.value))
            OutlinedButton(
              onPressed: () => context.push(Routes.onboardingRank),
              child: const Text(Vi.rankRetakeQuestionnaire),
            ),
          TextButton(
            onPressed: () => context.push(Routes.rankLayouts),
            child: const Text(Vi.rankShowLayouts),
          ),
          const SizedBox(height: AppSpacing.md),
          const TestHistoryList(),
        ],
      ),
    );
  }
}
