import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:uuid/uuid.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  Timer? _ticker;
  SkillCategory? _category;
  String? _cueId;
  bool _countDown = false;
  int _targetSeconds = 15 * 60;
  int _elapsedSeconds = 0;
  DateTime? _sessionDate;
  DateTime? _runningSince;
  bool _saving = false;

  bool get _active => _sessionDate != null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _currentElapsed() {
    final started = _runningSince;
    if (started == null) return _elapsedSeconds;
    return _elapsedSeconds +
        ref.read(nowProvider)().difference(started).inSeconds;
  }

  void _start() {
    final now = ref.read(nowProvider)();
    setState(() {
      _sessionDate ??= now;
      _runningSince = now;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _currentElapsed();
      if (mounted) setState(() {});
      if (_countDown && elapsed >= _targetSeconds) {
        unawaited(_finish());
      }
    });
  }

  void _pause() {
    final elapsed = _currentElapsed();
    _ticker?.cancel();
    setState(() {
      _elapsedSeconds = elapsed;
      _runningSince = null;
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _sessionDate = null;
      _runningSince = null;
      _saving = false;
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    final elapsed = _currentElapsed();
    final sessionDate = _sessionDate;
    _ticker?.cancel();
    if (mounted) {
      setState(() {
        _elapsedSeconds = elapsed;
        _runningSince = null;
        _saving = true;
      });
    }
    if (sessionDate == null || elapsed <= 0) {
      if (mounted) _reset();
      return;
    }

    try {
      await ref
          .read(timerSessionRepositoryProvider)
          .add(
            TimerSession(
              id: const Uuid().v4(),
              date: sessionDate,
              durationSec: elapsed,
              cat: _category,
              cueId: _cueId,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(Vi.timerSaved)));
      _reset();
    } catch (error) {
      debugPrint('Timer session save failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(Vi.timerSaveFailed)));
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(timerSessionsProvider);
    final equipmentAsync = ref.watch(cueEquipmentProvider);
    final cues = equipmentAsync.value ?? const <CueEquipment>[];
    final cueNames = {for (final cue in cues) cue.id: cue.name};
    final elapsed = _currentElapsed();
    final shownSeconds = _countDown
        ? (_targetSeconds - elapsed).clamp(0, _targetSeconds)
        : elapsed;

    return PcRootScaffold(
      title: Vi.timerTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text(Vi.timerCountUp)),
              ButtonSegment(value: true, label: Text(Vi.timerCountDown)),
            ],
            selected: {_countDown},
            onSelectionChanged: _active || _saving
                ? null
                : (selection) => setState(() => _countDown = selection.first),
          ),
          if (_countDown) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _targetSeconds,
              decoration: const InputDecoration(
                labelText: Vi.timerGoalDuration,
              ),
              items: const [15, 30, 45, 60]
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes * 60,
                      child: Text(Vi.timerTargetMinutes(minutes)),
                    ),
                  )
                  .toList(),
              onChanged: _active || _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _targetSeconds = value);
                    },
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<SkillCategory?>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: Vi.timerChooseCategory,
            ),
            items: [
              const DropdownMenuItem<SkillCategory?>(
                value: null,
                child: Text(Vi.timerNoCategory),
              ),
              ...SkillCategory.values.map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(Vi.skill(category)),
                ),
              ),
            ],
            onChanged: _active || _saving
                ? null
                : (category) => setState(() => _category = category),
          ),
          const SizedBox(height: 8),
          if (equipmentAsync.hasError)
            const Text(Vi.dataErrorBody)
          else
            DropdownButtonFormField<String?>(
              initialValue: _cueId,
              // Tên cơ do người dùng gõ, có thể rất dài: ô chọn chiếm đúng
              // bề ngang, tên quá dài thì cắt bằng dấu ba chấm.
              isExpanded: true,
              decoration: const InputDecoration(labelText: Vi.timerChooseCue),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(Vi.timerNoCue),
                ),
                ...cues.map(
                  (cue) => DropdownMenuItem(
                    value: cue.id,
                    child: Text(
                      '${cue.name} · ${Vi.equipmentTypeName(cue.type)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _active || _saving
                  ? null
                  : (cueId) => setState(() => _cueId = cueId),
            ),
          const SizedBox(height: 28),
          Center(
            child: Semantics(
              label: _formatDuration(shownSeconds),
              child: Text(
                _formatDuration(shownSeconds),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!_active)
                FilledButton.icon(
                  onPressed: _saving ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _elapsedSeconds == 0 ? Vi.timerStart : Vi.timerResume,
                  ),
                )
              else if (_runningSince != null)
                FilledButton.tonalIcon(
                  onPressed: _saving ? null : _pause,
                  icon: const Icon(Icons.pause),
                  label: const Text(Vi.timerPause),
                ),
              if (_active)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _finish,
                  icon: const Icon(Icons.stop),
                  label: const Text(Vi.timerFinish),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            Vi.timerHistoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const PcEmptyState(
              icon: Icons.cloud_off,
              title: Vi.dataErrorTitle,
              body: Vi.dataErrorBody,
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(Vi.timerEmptyHistory),
                );
              }
              return Column(
                children: sessions.take(10).map((session) {
                  final category = session.cat == null
                      ? ''
                      : ' · ${Vi.skill(session.cat!)}';
                  final cue = session.cueId == null
                      ? ''
                      : ' · ${cueNames[session.cueId] ?? Vi.equipmentUnknownCue}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sports),
                    title: Text(
                      '${_formatDuration(session.durationSec)}$category$cue',
                    ),
                    subtitle: Text(
                      '${session.date.day.toString().padLeft(2, '0')}/'
                      '${session.date.month.toString().padLeft(2, '0')}/'
                      '${session.date.year}',
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
