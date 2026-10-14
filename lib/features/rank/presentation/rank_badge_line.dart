import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Huy hiệu + nhãn nguồn + ⓘ — cách duy nhất app hiện một hạng (spec mục 4.3).
class RankBadgeLine extends StatelessWidget {
  /// Chỉ dùng khi đã có hạng (`rank.rank` khác null).
  const RankBadgeLine({required this.rank, super.key});

  final PlayerRank rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PcRankBadge(rank: rank.rank!, showWord: true),
        const SizedBox(width: AppSpacing.sm),
        Text(Vi.rankSource(rank.source!), style: Theme.of(context).textTheme.bodySmall),
        IconButton(
          tooltip: Vi.rankInfo,
          icon: const Icon(Icons.info_outline),
          onPressed: () => showRankInfoSheet(context),
        ),
      ],
    );
  }
}

Future<void> showRankInfoSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RankInfoSheet(),
    );

/// Câu miễn trừ, bảng quy đổi BU sang hạng và dòng nguồn (spec mục 4.3).
class RankInfoSheet extends StatelessWidget {
  const RankInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(Vi.rankInfoTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const Text(Vi.rankDisclaimer),
          const SizedBox(height: AppSpacing.lg),
          Text(Vi.rankTableTitle, style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final b in buRankBands)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: PcRankBadge(rank: b.rank),
              title: Text(Vi.rankBandRange(b)),
              subtitle: Text(Vi.rankBandLevels(b)),
            ),
          const SizedBox(height: AppSpacing.sm),
          const Text(Vi.rankProNote),
          const SizedBox(height: AppSpacing.sm),
          Text(Vi.buSourceLine, style: text.bodySmall),
        ],
      ),
    );
  }
}
