import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:uuid/uuid.dart';

/// Dữ liệu người chơi nhập khi bắt đầu một trận.
typedef MatchStartForm = ({
  PoolGameType gameType,
  String playerName,
  String opponentName,
  int targetRacks,
  String? cueId,
  String? tournamentId,
  String? roundLabel,
});

/// Dữ liệu người chơi nhập khi sửa chi tiết một trận.
typedef MatchDetailsForm = ({
  PoolGameType gameType,
  String playerName,
  String opponentName,
  int targetRacks,
  String? tournamentId,
  String? roundLabel,
});

/// Hộp thoại bắt đầu trận; null khi người chơi bỏ qua.
Future<MatchStartForm?> showStartMatchDialog(
  BuildContext context, {
  required List<CueEquipment> cues,
  required String? defaultCueId,
  required List<Tournament> tournaments,
  Tournament? preselected,
}) => showDialog<MatchStartForm>(
  context: context,
  builder: (_) => _StartMatchDialog(
    cues: cues,
    defaultCueId: defaultCueId,
    tournaments: tournaments,
    preselected: preselected,
  ),
);

/// Hộp thoại sửa chi tiết trận; null khi người chơi bỏ qua.
Future<MatchDetailsForm?> showEditMatchDialog(
  BuildContext context, {
  required PoolMatch match,
  required List<Tournament> tournaments,
}) => showDialog<MatchDetailsForm>(
  context: context,
  builder: (_) => _EditMatchDialog(match: match, tournaments: tournaments),
);

/// Tạo trận từ [form] và lưu qua repository.
Future<void> startMatchFromForm(WidgetRef ref, MatchStartForm form) {
  return ref
      .read(matchRepositoryProvider)
      .start(
        PoolMatch(
          id: const Uuid().v4(),
          gameType: form.gameType,
          playerName: form.playerName,
          opponentName: form.opponentName,
          targetRacks: form.targetRacks,
          rackWinners: const [],
          startedAt: ref.read(nowProvider)(),
          cueId: form.cueId,
          tournamentId: form.tournamentId,
          roundLabel: form.roundLabel,
        ),
      );
}

/// Ô chọn giải; `null` là không thuộc giải nào.
Widget _tournamentField({
  required Key fieldKey,
  required String? value,
  required List<Tournament> tournaments,
  required ValueChanged<String?> onChanged,
}) {
  return DropdownButtonFormField<String?>(
    key: fieldKey,
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: Vi.matchTournament),
    items: [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text(Vi.matchNoTournament),
      ),
      ...tournaments.map(
        (t) => DropdownMenuItem<String?>(
          value: t.id,
          child: Text(t.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: onChanged,
  );
}

/// Ô vòng đấu kèm các chip gợi ý.
Widget _roundFields({
  required Key fieldKey,
  required String chipKeyPrefix,
  required TextEditingController controller,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        key: fieldKey,
        controller: controller,
        decoration: const InputDecoration(labelText: Vi.matchRound),
        maxLength: TournamentConstants.roundLabelMaxLength,
        validator: (v) => roundLabelValid(v) ? null : Vi.matchRoundTooLong,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < Vi.tournamentRoundSuggestions.length; i++)
            ActionChip(
              key: Key('$chipKeyPrefix-$i'),
              label: Text(Vi.tournamentRoundSuggestions[i]),
              onPressed: () =>
                  controller.text = Vi.tournamentRoundSuggestions[i],
            ),
        ],
      ),
    ],
  );
}

class _StartMatchDialog extends StatefulWidget {
  const _StartMatchDialog({
    required this.cues,
    required this.defaultCueId,
    required this.tournaments,
    required this.preselected,
  });

  final List<CueEquipment> cues;
  final String? defaultCueId;
  final List<Tournament> tournaments;
  final Tournament? preselected;

  @override
  State<_StartMatchDialog> createState() => _StartMatchDialogState();
}

class _StartMatchDialogState extends State<_StartMatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _round = TextEditingController();
  var _playerName = '';
  var _opponentName = '';
  var _targetRacks = 5;
  late PoolGameType _gameType;
  late String? _cueId;
  String? _tournamentId;
  // Đổi số này để ô loại bi dựng lại và áp lại `initialValue`.
  var _gameTypeRevision = 0;

  @override
  void initState() {
    super.initState();
    _gameType = widget.preselected?.gameType ?? PoolGameType.nineBall;
    _cueId = widget.defaultCueId;
    final id = widget.preselected?.id;
    if (id != null && widget.tournaments.any((t) => t.id == id)) {
      _tournamentId = id;
    }
  }

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }

  void _pickTournament(String? id) {
    setState(() {
      _tournamentId = id;
      final type = widget.tournaments
          .where((t) => t.id == id)
          .firstOrNull
          ?.gameType;
      if (type != null && type != _gameType) {
        _gameType = type;
        _gameTypeRevision++;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    Navigator.pop<MatchStartForm>(context, (
      gameType: _gameType,
      playerName: _playerName,
      opponentName: _opponentName,
      targetRacks: _targetRacks,
      cueId: _cueId,
      tournamentId: _tournamentId,
      roundLabel: _tournamentId == null ? null : trimmedOrNull(_round.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cues = widget.cues;
    return AlertDialog(
      // Máy ngang, bàn phím mở: hộp thoại chỉ còn ~150 px. Tiêu đề
      // cuộn cùng ô nhập, chỉ hàng nút đứng yên trên bàn phím.
      scrollable: true,
      title: const Text(Vi.matchStart),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tournaments.isNotEmpty)
                _tournamentField(
                  fieldKey: const Key('match-tournament'),
                  value: _tournamentId,
                  tournaments: widget.tournaments,
                  onChanged: _pickTournament,
                ),
              if (_tournamentId != null)
                _roundFields(
                  fieldKey: const Key('match-round'),
                  chipKeyPrefix: 'match-round',
                  controller: _round,
                ),
              KeyedSubtree(
                key: ValueKey(_gameTypeRevision),
                child: DropdownButtonFormField<PoolGameType>(
                  key: const Key('match-game-type'),
                  initialValue: _gameType,
                  isExpanded: true,
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
                    if (value != null) setState(() => _gameType = value);
                  },
                ),
              ),
              TextFormField(
                key: const Key('match-player-name'),
                initialValue: _playerName,
                decoration: const InputDecoration(
                  labelText: Vi.matchPlayerName,
                ),
                textCapitalization: TextCapitalization.words,
                onSaved: (value) => _playerName = value?.trim() ?? '',
                validator: (value) => value == null || value.trim().isEmpty
                    ? Vi.matchNameRequired
                    : null,
              ),
              TextFormField(
                key: const Key('match-opponent-name'),
                initialValue: _opponentName,
                decoration: const InputDecoration(
                  labelText: Vi.matchOpponentName,
                ),
                textCapitalization: TextCapitalization.words,
                onSaved: (value) => _opponentName = value?.trim() ?? '',
                validator: (value) => value == null || value.trim().isEmpty
                    ? Vi.matchNameRequired
                    : null,
              ),
              DropdownButtonFormField<int>(
                key: const Key('match-target'),
                initialValue: _targetRacks,
                isExpanded: true,
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
                  if (value != null) setState(() => _targetRacks = value);
                },
              ),
              if (cues.isNotEmpty)
                DropdownButtonFormField<String?>(
                  key: const Key('match-cue'),
                  initialValue: _cueId,
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
                  onChanged: (value) => setState(() => _cueId = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Vi.scheduleKeep),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(Vi.matchStartAction),
        ),
      ],
    );
  }
}

class _EditMatchDialog extends StatefulWidget {
  const _EditMatchDialog({required this.match, required this.tournaments});

  final PoolMatch match;
  final List<Tournament> tournaments;

  @override
  State<_EditMatchDialog> createState() => _EditMatchDialogState();
}

class _EditMatchDialogState extends State<_EditMatchDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _round;
  late PoolGameType _gameType;
  late int _targetRacks;
  late String _playerName;
  late String _opponentName;
  late String? _tournamentId;
  var _touched = false;

  bool _isLive(String? id) =>
      id != null && widget.tournaments.any((t) => t.id == id);

  @override
  void initState() {
    super.initState();
    final m = widget.match;
    _gameType = m.gameType;
    _targetRacks = m.targetRacks;
    _playerName = m.playerName;
    _opponentName = m.opponentName;
    _tournamentId = _isLive(m.tournamentId) ? m.tournamentId : null;
    _round = TextEditingController(
      text: _tournamentId == null ? '' : m.roundLabel,
    );
  }

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final m = widget.match;
    // Giải của trận đã bị xóa mà người chơi không đụng tới ô giải: giữ nguyên.
    final keepOriginal = !_touched && _tournamentId == null;
    Navigator.pop<MatchDetailsForm>(context, (
      gameType: _gameType,
      playerName: _playerName,
      opponentName: _opponentName,
      targetRacks: _targetRacks,
      tournamentId: keepOriginal ? m.tournamentId : _tournamentId,
      roundLabel: keepOriginal
          ? m.roundLabel
          : (_tournamentId == null ? null : trimmedOrNull(_round.text)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final leaderWins = widget.match.playerScore > widget.match.opponentScore
        ? widget.match.playerScore
        : widget.match.opponentScore;
    return AlertDialog(
      scrollable: true,
      title: const Text(Vi.matchEditTitle),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tournaments.isNotEmpty ||
                  widget.match.tournamentId != null)
                _tournamentField(
                  fieldKey: const Key('edit-match-tournament'),
                  value: _tournamentId,
                  tournaments: widget.tournaments,
                  onChanged: (id) => setState(() {
                    _touched = true;
                    _tournamentId = id;
                  }),
                ),
              if (_tournamentId != null)
                _roundFields(
                  fieldKey: const Key('edit-match-round'),
                  chipKeyPrefix: 'edit-match-round',
                  controller: _round,
                ),
              DropdownButtonFormField<PoolGameType>(
                key: const Key('edit-match-game-type'),
                initialValue: _gameType,
                isExpanded: true,
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
                  if (value != null) _gameType = value;
                },
              ),
              TextFormField(
                key: const Key('edit-match-player-name'),
                initialValue: _playerName,
                decoration: const InputDecoration(
                  labelText: Vi.matchPlayerName,
                ),
                textCapitalization: TextCapitalization.words,
                onSaved: (value) => _playerName = value?.trim() ?? '',
                validator: (value) => value == null || value.trim().isEmpty
                    ? Vi.matchNameRequired
                    : null,
              ),
              TextFormField(
                key: const Key('edit-match-opponent-name'),
                initialValue: _opponentName,
                decoration: const InputDecoration(
                  labelText: Vi.matchOpponentName,
                ),
                textCapitalization: TextCapitalization.words,
                onSaved: (value) => _opponentName = value?.trim() ?? '',
                validator: (value) => value == null || value.trim().isEmpty
                    ? Vi.matchNameRequired
                    : null,
              ),
              DropdownButtonFormField<int>(
                key: const Key('edit-match-target'),
                initialValue: _targetRacks,
                isExpanded: true,
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
                  if (value != null) _targetRacks = value;
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
          onPressed: () => Navigator.pop(context),
          child: const Text(Vi.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(Vi.matchSaveDetails),
        ),
      ],
    );
  }
}
