import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/cue_performance/cue_win_rate.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/features/play/presentation/match_analysis_sheet.dart';
import 'package:uuid/uuid.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  bool _mutating = false;

  Future<void> _startMatch() async {
    final formKey = GlobalKey<FormState>();
    var playerName = '';
    var opponentName = '';
    var gameType = PoolGameType.nineBall;
    var targetRacks = 5;
    final cues = ref.read(cueEquipmentProvider).value ?? const <CueEquipment>[];
    String? cueId = defaultMatchCueId(
      matches: ref.read(matchesProvider).value ?? const <PoolMatch>[],
      knownCueIds: {for (final cue in cues) cue.id},
    );
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          // Máy ngang, bàn phím mở: hộp thoại chỉ còn ~150 px. Tiêu đề
          // cuộn cùng ô nhập, chỉ hàng nút đứng yên trên bàn phím.
          scrollable: true,
          title: const Text(Vi.matchStart),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<PoolGameType>(
                    key: const Key('match-game-type'),
                    initialValue: gameType,
                    decoration: const InputDecoration(
                      labelText: Vi.matchGameType,
                    ),
                    items: PoolGameType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(Vi.matchGameTypeName(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => gameType = value);
                    },
                  ),
                  TextFormField(
                    key: const Key('match-player-name'),
                    initialValue: playerName,
                    decoration: const InputDecoration(
                      labelText: Vi.matchPlayerName,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSaved: (value) => playerName = value?.trim() ?? '',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? Vi.matchNameRequired
                        : null,
                  ),
                  TextFormField(
                    key: const Key('match-opponent-name'),
                    initialValue: opponentName,
                    decoration: const InputDecoration(
                      labelText: Vi.matchOpponentName,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSaved: (value) => opponentName = value?.trim() ?? '',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? Vi.matchNameRequired
                        : null,
                  ),
                  DropdownButtonFormField<int>(
                    key: const Key('match-target'),
                    initialValue: targetRacks,
                    decoration: const InputDecoration(
                      labelText: Vi.matchTarget,
                    ),
                    items: const [3, 5, 7, 9]
                        .map(
                          (target) => DropdownMenuItem(
                            value: target,
                            child: Text(Vi.matchRaceTo(target)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => targetRacks = value);
                      }
                    },
                  ),
                  if (cues.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      key: const Key('match-cue'),
                      initialValue: cueId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: Vi.matchCue),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(Vi.timerNoCue),
                        ),
                        ...cues.map(
                          (cue) => DropdownMenuItem<String?>(
                            value: cue.id,
                            child: Text(
                              '${cue.name} · ${Vi.equipmentTypeName(cue.type)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() => cueId = value),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(Vi.scheduleKeep),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text(Vi.matchStartAction),
            ),
          ],
        ),
      ),
    );

    if (create != true || !mounted) {
      return;
    }
    setState(() => _mutating = true);
    try {
      await ref
          .read(matchRepositoryProvider)
          .start(
            PoolMatch(
              id: const Uuid().v4(),
              gameType: gameType,
              playerName: playerName,
              opponentName: opponentName,
              targetRacks: targetRacks,
              rackWinners: const [],
              startedAt: ref.read(nowProvider)(),
              cueId: cueId,
            ),
          );
    } catch (error) {
      debugPrint('Pool match start failed: $error');
      if (mounted) _showMessage(Vi.matchStartFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _recordRack(PoolMatch match, RackWinner winner) async {
    setState(() => _mutating = true);
    try {
      await ref.read(matchRepositoryProvider).recordRack(match.id, winner);
    } catch (error) {
      debugPrint('Pool match rack recording failed: $error');
      if (mounted) _showMessage(Vi.matchRecordFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _undoLastRack(PoolMatch match) async {
    setState(() => _mutating = true);
    try {
      await ref.read(matchRepositoryProvider).undoLastRack(match.id);
    } catch (error) {
      debugPrint('Pool match rack undo failed: $error');
      if (mounted) _showMessage(Vi.matchRecordFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _recordShot(PoolMatch match) async {
    final formKey = GlobalKey<FormState>();
    var shooter = RackWinner.player;
    var type = MatchShotType.normal;
    var outcome = MatchShotOutcome.made;
    PositionOutcome? positionOutcome;
    var notes = '';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          // Máy ngang, bàn phím mở: hộp thoại chỉ còn ~150 px. Tiêu đề
          // cuộn cùng ô nhập, chỉ hàng nút đứng yên trên bàn phím.
          scrollable: true,
          title: const Text(Vi.matchRecordShot),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<RackWinner>(
                    key: const Key('match-shot-shooter'),
                    initialValue: shooter,
                    decoration: const InputDecoration(
                      labelText: Vi.matchShooter,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: RackWinner.player,
                        child: Text(match.playerName),
                      ),
                      DropdownMenuItem(
                        value: RackWinner.opponent,
                        child: Text(match.opponentName),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => shooter = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<MatchShotType>(
                    key: const Key('match-shot-type'),
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: Vi.matchShotType,
                    ),
                    items: MatchShotType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(Vi.matchShotTypeName(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  DropdownButtonFormField<MatchShotOutcome>(
                    key: const Key('match-shot-outcome'),
                    initialValue: outcome,
                    decoration: const InputDecoration(
                      labelText: Vi.matchShotOutcome,
                    ),
                    items: MatchShotOutcome.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(Vi.matchShotOutcomeName(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => outcome = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<PositionOutcome?>(
                    key: const Key('match-position-outcome'),
                    initialValue: positionOutcome,
                    decoration: const InputDecoration(
                      labelText: Vi.matchPositionOutcome,
                    ),
                    items: [
                      const DropdownMenuItem<PositionOutcome?>(
                        value: null,
                        child: Text(Vi.matchPositionUnknown),
                      ),
                      ...PositionOutcome.values.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(Vi.matchPositionOutcomeName(value)),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => positionOutcome = value),
                  ),
                  TextFormField(
                    key: const Key('match-shot-notes'),
                    decoration: const InputDecoration(
                      labelText: Vi.matchShotNotes,
                    ),
                    maxLength: 240,
                    onSaved: (value) => notes = value?.trim() ?? '',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(Vi.scheduleKeep),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text(Vi.matchSaveShot),
            ),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;

    final currentRack = match.rackWinners.length + 1;
    final shotNumber =
        match.shots.where((shot) => shot.rackNumber == currentRack).length + 1;
    setState(() => _mutating = true);
    try {
      await ref
          .read(matchRepositoryProvider)
          .recordShot(
            match.id,
            MatchShot(
              id: const Uuid().v4(),
              rackNumber: currentRack,
              shotNumber: shotNumber,
              shooter: shooter,
              type: type,
              outcome: outcome,
              positionOutcome: positionOutcome,
              notes: notes.isEmpty ? null : notes,
              recordedAt: ref.read(nowProvider)(),
            ),
          );
    } catch (error) {
      debugPrint('Pool match shot recording failed: $error');
      if (mounted) _showMessage(Vi.matchRecordFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _undoLastShot(PoolMatch match) async {
    setState(() => _mutating = true);
    try {
      await ref.read(matchRepositoryProvider).undoLastShot(match.id);
    } catch (error) {
      debugPrint('Pool match shot undo failed: $error');
      if (mounted) _showMessage(Vi.matchRecordFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _removeMatch(PoolMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Vi.matchDeleteTitle),
        content: const Text(Vi.matchDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Vi.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.matchDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mutating = true);
    try {
      await ref.read(matchRepositoryProvider).remove(match.id);
    } catch (error) {
      debugPrint('Pool match deletion failed: $error');
      if (mounted) _showMessage(Vi.matchDeleteFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editMatch(PoolMatch match) async {
    final formKey = GlobalKey<FormState>();
    var gameType = match.gameType;
    var targetRacks = match.targetRacks;
    var playerName = match.playerName;
    var opponentName = match.opponentName;
    final leaderWins = math.max(match.playerScore, match.opponentScore);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(Vi.matchEditTitle),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PoolGameType>(
                  key: const Key('edit-match-game-type'),
                  initialValue: gameType,
                  decoration: const InputDecoration(labelText: Vi.matchGameType),
                  items: PoolGameType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(Vi.matchGameTypeName(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) gameType = value;
                  },
                ),
                TextFormField(
                  key: const Key('edit-match-player-name'),
                  initialValue: playerName,
                  decoration: const InputDecoration(
                    labelText: Vi.matchPlayerName,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSaved: (value) => playerName = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? Vi.matchNameRequired
                      : null,
                ),
                TextFormField(
                  key: const Key('edit-match-opponent-name'),
                  initialValue: opponentName,
                  decoration: const InputDecoration(
                    labelText: Vi.matchOpponentName,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSaved: (value) => opponentName = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? Vi.matchNameRequired
                      : null,
                ),
                DropdownButtonFormField<int>(
                  key: const Key('edit-match-target'),
                  initialValue: targetRacks,
                  decoration: const InputDecoration(labelText: Vi.matchTarget),
                  items: const [3, 5, 7, 9]
                      .map(
                        (target) => DropdownMenuItem(
                          value: target,
                          child: Text(Vi.matchRaceTo(target)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) targetRacks = value;
                  },
                  validator: (value) => value != null && value < leaderWins
                      ? Vi.matchTargetBelowLeader(leaderWins)
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Vi.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text(Vi.matchSaveDetails),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;

    setState(() => _mutating = true);
    try {
      await ref
          .read(matchRepositoryProvider)
          .updateDetails(
            matchId: match.id,
            gameType: gameType,
            playerName: playerName,
            opponentName: opponentName,
            targetRacks: targetRacks,
          );
    } catch (error) {
      debugPrint('Pool match details update failed: $error');
      if (mounted) _showMessage(Vi.matchEditFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _matchCard(PoolMatch match, Map<String, String> cueNames) {
    final score = Vi.matchScore(
      match.playerName,
      match.playerScore,
      match.opponentScore,
      match.opponentName,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Vi.matchGameTypeName(match.gameType),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: Text(
                    match.isComplete ? Vi.matchCompleted : Vi.matchInProgress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: Key('edit-match-${match.id}'),
                  tooltip: Vi.matchEdit,
                  onPressed: _mutating ? null : () => _editMatch(match),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('delete-match-${match.id}'),
                  tooltip: Vi.matchDelete,
                  onPressed: _mutating ? null : () => _removeMatch(match),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(score, style: Theme.of(context).textTheme.titleLarge),
            if (match.cueId != null)
              Text(
                Vi.matchCueLine(
                  cueNames[match.cueId] ?? Vi.equipmentUnknownCue,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              '${Vi.matchRaceTo(match.targetRacks)} · '
              '${Vi.matchRackProgress(match.rackWinners.length)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (match.shots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                Vi.matchShotCount(match.shots.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final shot in match.shots.reversed.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    Vi.matchShotSummary(
                      shot,
                      shooter: shot.shooter == RackWinner.player
                          ? match.playerName
                          : match.opponentName,
                    ),
                  ),
                  subtitle: shot.positionOutcome == null && shot.notes == null
                      ? null
                      : Text(
                          [
                            if (shot.positionOutcome != null)
                              Vi.matchPositionOutcomeName(shot.positionOutcome),
                            if (shot.notes != null) shot.notes!,
                          ].join(' · '),
                        ),
                ),
            ],
            if (match.isComplete) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: Key('analyze-match-${match.id}'),
                onPressed: () => showMatchAnalysis(context, match),
                icon: const Icon(Icons.insights_outlined),
                label: const Text(Vi.matchAnalysisOpen),
              ),
            ],
            if (!match.isComplete) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _mutating ? null : () => _recordShot(match),
                icon: const Icon(Icons.sports),
                label: const Text(Vi.matchRecordShot),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _mutating
                        ? null
                        : () => _recordRack(match, RackWinner.player),
                    child: const Text(Vi.matchPlayerWinsRack),
                  ),
                  FilledButton.tonal(
                    onPressed: _mutating
                        ? null
                        : () => _recordRack(match, RackWinner.opponent),
                    child: const Text(Vi.matchOpponentWinsRack),
                  ),
                  if (match.shots.any(
                    (shot) => shot.rackNumber == match.rackWinners.length + 1,
                  ))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _mutating
                            ? null
                            : () => _undoLastShot(match),
                        icon: const Icon(Icons.undo),
                        label: const Text(Vi.matchUndoShot),
                      ),
                    ),
                ],
              ),
            ],
            if (match.rackWinners.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _mutating ? null : () => _undoLastRack(match),
                  icon: const Icon(Icons.undo),
                  label: const Text(Vi.matchUndoRack),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final cueNames = {
      for (final cue
          in ref.watch(cueEquipmentProvider).value ?? const <CueEquipment>[])
        cue.id: cue.name,
    };

    return PcRootScaffold(
      title: Vi.playTitle,
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (matches) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FilledButton.icon(
              onPressed: _mutating ? null : _startMatch,
              icon: const Icon(Icons.add),
              label: const Text(Vi.matchStart),
            ),
            const SizedBox(height: 12),
            if (matches.isEmpty)
              const PcEmptyState(
                icon: Icons.sports,
                title: Vi.playTitle,
                body: Vi.matchEmpty,
              )
            else
              ...matches.map((match) => _matchCard(match, cueNames)),
          ],
        ),
      ),
    );
  }
}
