import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_fab_inset.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/cue_performance/cue_win_rate.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/domain/tournament/tournament_goal.dart';
import 'package:poolcoachai/domain/tournament/tournament_lists.dart';
import 'package:poolcoachai/domain/tournament/tournament_results.dart';
import 'package:poolcoachai/features/play/presentation/match_analysis_sheet.dart';
import 'package:poolcoachai/features/play/presentation/match_dialogs.dart';
import 'package:poolcoachai/features/play/presentation/tournament_form.dart';
import 'package:poolcoachai/features/stats/presentation/match_analysis_card.dart';

/// Chi tiết một giải: thông tin, tổng kết, các trận và phân tích các trận đó.
class TournamentDetailScreen extends ConsumerStatefulWidget {
  const TournamentDetailScreen({required this.tournamentId, super.key});

  final String tournamentId;

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends ConsumerState<TournamentDetailScreen> {
  bool _busy = false;

  /// Đã xóa giải xong và đang chờ rời màn: luồng dữ liệu báo "giải đã mất"
  /// trước khi route đổi, nên màn giữ nội dung cuối thay vì hiện "không tìm
  /// thấy" một khung hình.
  bool _deleting = false;
  TournamentView? _lastView;

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit(Tournament t) async {
    final draft = await showTournamentForm(
      context,
      existing: t,
      today: ref.read(nowProvider)(),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(tournamentRepositoryProvider);
      if (repo == null) throw StateError('no-repo');
      await repo.update(t.id, draft);
    } on Object {
      if (mounted) _message(Vi.tournamentSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Tournament t) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Vi.tournamentDeleteTitle),
        content: const Text(Vi.tournamentDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Vi.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(Vi.tournamentDeleteConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() {
      _busy = true;
      _deleting = true;
    });
    try {
      final repo = ref.read(tournamentRepositoryProvider);
      if (repo == null) throw StateError('no-repo');
      await repo.remove(t.id);
    } on Object {
      if (mounted) {
        _message(Vi.tournamentDeleteFailed);
        setState(() {
          _busy = false;
          _deleting = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(Routes.tournaments);
  }

  Future<void> _startMatch(Tournament t) async {
    // Nút chỉ bật khi nguồn đã sẵn sàng; không có thì thôi, không đoán.
    final inputs = ref.read(startMatchInputsProvider).value;
    if (inputs == null) return;
    final cues = inputs.cues;
    final form = await showStartMatchDialog(
      context,
      cues: cues,
      defaultCueId: defaultMatchCueId(
        matches: inputs.matches,
        knownCueIds: {for (final cue in cues) cue.id},
      ),
      tournaments: pickableForNewMatch(
        inputs.tournamentsById.values,
        ref.read(nowProvider)(),
        include: t.id,
      ),
      preselected: t,
    );
    if (form == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await startMatchFromForm(ref, form);
    } on Object catch (error) {
      debugPrint('Tournament match start failed: $error');
      if (mounted) {
        _message(Vi.matchStartFailed);
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(Routes.play);
  }

  Future<void> _prepare(Tournament t, TournamentGoalView goal) async {
    final current = goal.currentKind;
    if (goal.state == TournamentGoalState.otherGoal && current != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(Vi.tournamentReplaceGoalTitle),
          content: Text(Vi.tournamentReplaceGoalBody(Vi.goalKind(current))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(Vi.goalCancelChange),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(Vi.goalChange),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(roadmapRepositoryProvider);
      if (repo == null) throw StateError('no-repo');
      if (goal.state == TournamentGoalState.linkOnly) {
        await repo.linkTournament(t.id);
      } else {
        await repo.setGoal(
          kind: GoalKind.chuanBiGiai,
          eventDate: t.startDate,
          tournamentId: t.id,
        );
      }
    } on Object {
      if (mounted) _message(Vi.tournamentGoalFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _info(Tournament t, TournamentStatus status, TextTheme textTheme) {
    final location = t.location;
    final gameType = t.gameType;
    final note = t.resultNote;
    final notes = t.notes;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.name, style: textTheme.titleLarge)),
              IconButton(
                key: const Key('tournament-edit'),
                tooltip: Vi.tournamentEdit,
                icon: const Icon(Icons.edit),
                onPressed: _busy ? null : () => _edit(t),
              ),
              IconButton(
                key: const Key('tournament-delete'),
                tooltip: Vi.tournamentDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy ? null : () => _delete(t),
              ),
            ],
          ),
          Text(Vi.tournamentStatusDates(status, t)),
          if (location != null) Text(location),
          if (gameType != null) Text(Vi.matchGameTypeName(gameType)),
          if (note != null) ...[
            Text(Vi.tournamentResultLine(note)),
            Text(Vi.tournamentSelfReported, style: textTheme.bodySmall),
          ],
          if (notes != null) Text(notes),
        ],
      ),
    );
  }

  Widget _actions(
    Tournament t,
    TournamentStatus status,
    TournamentGoalView? goal,
    bool canStart,
  ) {
    final state = goal?.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status != TournamentStatus.sapToi)
          FilledButton.icon(
            key: const Key('tournament-start-match'),
            onPressed: _busy || !canStart ? null : () => _startMatch(t),
            icon: const Icon(Icons.sports_score),
            label: const Text(Vi.tournamentStartMatch),
          ),
        if (goal != null &&
            (state == TournamentGoalState.noGoal ||
                state == TournamentGoalState.linkOnly ||
                state == TournamentGoalState.otherGoal))
          OutlinedButton(
            key: const Key('tournament-prepare'),
            onPressed: _busy ? null : () => _prepare(t, goal),
            child: const Text(Vi.tournamentPrepare),
          ),
        if (state == TournamentGoalState.linked) ...[
          const Text(Vi.tournamentPreparing),
          TextButton(
            key: const Key('tournament-open-roadmap'),
            onPressed: () => context.go(Routes.roadmap),
            child: const Text(Vi.tournamentOpenRoadmap),
          ),
        ],
      ],
    );
  }

  Widget _summary(TournamentView view, TextTheme textTheme) {
    final s = view.summary;
    final percent = s.rackWinPercent;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Vi.tournamentSummaryTitle, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          if (s.completedMatches == 0 || percent == null)
            const Text(Vi.tournamentSummaryEmpty)
          else ...[
            Text(Vi.tournamentRecord(s.matchesWon, s.matchesLost)),
            Text(Vi.tournamentRacks(s.racksWon, s.racksLost)),
            Text(Vi.tournamentRackRate(percent)),
          ],
        ],
      ),
    );
  }

  Widget _matchTile(PoolMatch m, TextTheme textTheme) {
    final status = m.isComplete
        ? (playerWon(m) ? Vi.tournamentMatchWon : Vi.tournamentMatchLost)
        : Vi.matchInProgress;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PcCard(
        key: ValueKey('tournament-match-${m.id}'),
        onTap: () => m.isComplete
            ? showMatchAnalysis(context, m)
            : context.go(Routes.play),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Vi.tournamentMatchTitle(m.roundLabel, m.opponentName),
              style: textTheme.titleSmall,
            ),
            Text(
              Vi.matchScore(
                m.playerName,
                m.playerScore,
                m.opponentScore,
                m.opponentName,
              ),
            ),
            Text(status),
          ],
        ),
      ),
    );
  }

  Widget _body(TournamentView view) {
    final textTheme = Theme.of(context).textTheme;
    final t = view.tournament;
    final status = ref.watch(tournamentStatusProvider(t.id)).value;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final goal = ref.watch(tournamentGoalStateProvider(t.id)).value;
    final canStart = ref.watch(startMatchInputsProvider).hasValue;
    return ListView(
      padding: pcScrollPadding(context, const EdgeInsets.all(12)),
      children: [
        _info(t, status, textTheme),
        const SizedBox(height: 12),
        _actions(t, status, goal, canStart),
        const SizedBox(height: 12),
        _summary(view, textTheme),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(Vi.tournamentMatchesTitle, style: textTheme.titleMedium),
        ),
        if (view.matches.isEmpty) const Text(Vi.tournamentMatchesEmpty),
        for (final m in view.matches) _matchTile(m, textTheme),
        const SizedBox(height: 4),
        MatchAnalysisCard(
          analysis: analyzeMatches(view.matches, limit: view.matches.length),
          title: Vi.tournamentAnalysisTitle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tournamentViewProvider(widget.tournamentId));
    return PcRootScaffold(
      title: Vi.tournamentsTitle,
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (v) {
          if (v != null) _lastView = v;
          final last = _lastView;
          if (v == null && _deleting && last != null) return _body(last);
          return v == null
              ? PcEmptyState(
                  icon: Icons.search_off,
                  title: Vi.tournamentNotFoundTitle,
                  body: Vi.tournamentNotFoundBody,
                  action: FilledButton(
                    onPressed: () => context.go(Routes.tournaments),
                    child: const Text(Vi.tournamentBackToList),
                  ),
                )
              : _body(v);
        },
      ),
    );
  }
}
