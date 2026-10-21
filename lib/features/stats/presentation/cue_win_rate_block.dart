import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/cue_performance/cue_win_rate.dart';

/// Số trận thắng/hoàn tất của một cây cơ, kèm số trận còn thiếu nếu chưa đủ
/// để so sánh. Chỉ hiển thị số liệu của [CueMatchStats]; không tự suy diễn.
class CueWinRateBlock extends StatelessWidget {
  const CueWinRateBlock({
    super.key,
    required this.stats,
    required this.isBest,
  });

  final CueMatchStats stats;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final rate = stats.winRate;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isBest)
          Text(
            Vi.cueBestBadge,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        Text(
          rate == null
              ? Vi.cueWinRateNone
              : Vi.cueWinRateLine(
                  wins: stats.wins,
                  completed: stats.completedMatches,
                  percent: (rate * 100).round(),
                ),
        ),
        if (stats.matchesNeeded > 0)
          Text(
            Vi.cueMatchesNeeded(stats.matchesNeeded),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
