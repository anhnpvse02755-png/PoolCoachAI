import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_fab_inset.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/features/play/presentation/tournament_form.dart';

/// Danh sách giải đấu theo ba nhóm, kèm dòng so sánh giải và trận thường.
class TournamentListScreen extends ConsumerStatefulWidget {
  const TournamentListScreen({super.key});

  @override
  ConsumerState<TournamentListScreen> createState() =>
      _TournamentListScreenState();
}

class _TournamentListScreenState extends ConsumerState<TournamentListScreen> {
  bool _busy = false;

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final today = ref.read(nowProvider)();
    final draft = await showTournamentForm(context, today: today);
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(tournamentRepositoryProvider);
      if (repo == null) throw StateError('no-repo');
      await repo.create(draft);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(Vi.tournamentSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _comparison(TextTheme textTheme) {
    final comparison = ref.watch(tournamentComparisonProvider);
    return comparison.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Text(Vi.tournamentDataError),
      data: (c) => PcCard(
        key: const Key('tournament-compare'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Vi.tournamentCompareTitle, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              c.enough
                  ? Vi.tournamentCompare(
                      c.inTournaments.rackWinPercent!,
                      c.inTournaments.completedMatches,
                      c.regular.rackWinPercent!,
                      c.regular.completedMatches,
                    )
                  : Vi.tournamentCompareNotEnough,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Tournament t, TextTheme textTheme) {
    final summary = ref.watch(tournamentSummariesProvider).value?[t.id];
    final location = t.location;
    final note = t.resultNote;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PcCard(
        key: ValueKey('tournament-${t.id}'),
        onTap: () => context.go(Routes.tournament(t.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.name, style: textTheme.titleSmall),
            Text(Vi.tournamentDates(t)),
            if (location != null) Text(location),
            if (summary != null && summary.completedMatches > 0)
              Text(
                Vi.tournamentRecord(summary.matchesWon, summary.matchesLost),
              ),
            if (note != null) ...[
              Text(Vi.tournamentResultLine(note)),
              Text(Vi.tournamentSelfReported, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _group(
    TournamentStatus status,
    List<Tournament> items,
    TextTheme textTheme,
  ) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          Vi.tournamentStatusName(status),
          style: textTheme.titleMedium,
        ),
      ),
      for (final t in items) _tile(t, textTheme),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(tournamentGroupsProvider);
    final textTheme = Theme.of(context).textTheme;
    return PcRootScaffold(
      title: Vi.tournamentsTitle,
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (g) => ListView(
          padding: pcScrollPadding(context, const EdgeInsets.all(12)),
          children: [
            FilledButton.icon(
              key: const Key('tournament-add'),
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text(Vi.tournamentAdd),
            ),
            const SizedBox(height: 12),
            _comparison(textTheme),
            const SizedBox(height: 12),
            if (g.dangDienRa.isEmpty && g.sapToi.isEmpty && g.daXong.isEmpty)
              const Text(Vi.tournamentListEmpty),
            ..._group(TournamentStatus.dangDienRa, g.dangDienRa, textTheme),
            ..._group(TournamentStatus.sapToi, g.sapToi, textTheme),
            ..._group(TournamentStatus.daXong, g.daXong, textTheme),
          ],
        ),
      ),
    );
  }
}
