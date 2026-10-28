import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/features/rank/presentation/rank_check_line.dart';

/// Bước hiện tại của mục tiêu trên Trang chủ, và gợi ý làm lại bài BU.
/// Gợi ý nói về hạng chứ không về mục tiêu nên vẫn hiện khi chưa có mục tiêu.
class RoadmapHomeLine extends ConsumerWidget {
  const RoadmapHomeLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(roadmapProvider).value?.currentStep;
    final hasSignal = ref.watch(rankCheckSignalProvider) != null;
    if (step == null && !hasSignal) return const SizedBox.shrink();

    final drills = ref.watch(drillsProvider).value ?? const <Drill>[];
    final drill = step == null ? null : drills.where((item) => item.id == step.drillId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text(
                  Vi.homeCurrentStep(Vi.stepTitle(step, drillName: drill?.name)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.roadmap),
              ),
            const RankCheckLine(),
          ],
        ),
      ),
    );
  }
}
