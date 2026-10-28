import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';

/// Thẻ "Giải đấu" đầu màn Thi đấu: giải đang diễn ra, không có thì giải sắp
/// tới gần nhất, kèm trạng thái do provider đưa ra. Bấm để mở danh sách.
class TournamentPlayCard extends ConsumerWidget {
  const TournamentPlayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredTournamentProvider);
    final textTheme = Theme.of(context).textTheme;
    return PcCard(
      key: const Key('play-tournament-card'),
      onTap: () => context.go(Routes.tournaments),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(Vi.tournamentsTitle, style: textTheme.titleMedium),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          ...featured.when(
            loading: () => const <Widget>[],
            error: (_, _) => const [Text(Vi.tournamentDataError)],
            data: (f) {
              final t = f.tournament;
              final status = f.status;
              if (t == null || status == null) {
                return [
                  Text(f.hasAny ? Vi.tournamentNoneActive : Vi.tournamentNone),
                ];
              }
              return [
                const SizedBox(height: 8),
                Text(t.name, style: textTheme.titleSmall),
                Text(Vi.tournamentStatusDates(status, t)),
              ];
            },
          ),
        ],
      ),
    );
  }
}
