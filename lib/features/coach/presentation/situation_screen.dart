import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/generator.dart';
import 'package:poolcoachai/domain/coach/library.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/reveal.dart';
import 'package:poolcoachai/domain/coach/rng.dart';
import 'package:poolcoachai/domain/coach/session.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/coach/presentation/coach_lines.dart';
import 'package:poolcoachai/features/coach/presentation/coach_painter.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_panel_layout.dart';
import 'package:uuid/uuid.dart';

/// Tham số đường dẫn của màn tình huống (spec mục 4.2): sinh ngẫu nhiên
/// `?topic=&d=&seed=`, hoặc thư viện `?lib=`.
class SituationRequest {
  const SituationRequest({this.topic, this.difficulty, this.seed, this.libraryId});

  factory SituationRequest.parse(Map<String, String> q) => SituationRequest(
        topic: CoachTopic.values.asNameMap()[q['topic']],
        difficulty: CoachDifficulty.values.asNameMap()[q['d']],
        seed: int.tryParse(q['seed'] ?? ''),
        libraryId: q['lib'],
      );

  final CoachTopic? topic;
  final CoachDifficulty? difficulty;
  final int? seed;
  final String? libraryId;
}

enum _Choice { pot, safety }

/// Áp phê người chơi chọn được: đúng các mức của Planner (spec mục 4.2).
const coachSpins = <SideSpin>[
  SideSpin.none(),
  SideSpin(SpinSide.left, 0.5),
  SideSpin(SpinSide.left, 1),
  SideSpin(SpinSide.right, 0.5),
  SideSpin(SpinSide.right, 1),
];

/// Màn tình huống (spec mục 4.2). Mọi câu chữ là mẫu của `Vi` điền bằng dữ
/// liệu của lõi Coach; màn này chỉ chọn câu nào hiện.
class SituationScreen extends ConsumerStatefulWidget {
  const SituationScreen({required this.request, super.key});

  static const tableKey = Key('coach-table');
  static const submitKey = Key('coach-submit');
  static const showAnswerKey = Key('coach-show-answer');
  static const nextKey = Key('coach-next');
  static const potKey = Key('coach-choice-pot');
  static const safetyKey = Key('coach-choice-safety');
  static Key pocketKey(Pocket p) => Key('coach-pocket-${p.name}');
  static Key strokeKey(Stroke s) => Key('coach-stroke-${s.name}');
  static Key powerKey(double p) => Key('coach-power-${p.round()}');
  static Key spinKey(int i) => Key('coach-spin-$i');

  final SituationRequest request;

  @override
  ConsumerState<SituationScreen> createState() => _SituationScreenState();
}

class _SituationScreenState extends ConsumerState<SituationScreen> {
  late final CoachEngine _engine;
  late CoachTopic _topic;
  late CoachDifficulty _difficulty;

  CoachGenerateJob? _gen;
  CoachSituation? _situation;
  CoachJob? _job;
  CoachSession? _session;
  bool _generateFailed = false;
  bool _noSituation = false;

  /// Câu trả lời đã gửi cho việc tính, đúng thứ tự chỉ số của nó.
  final _sent = <CoachAnswer>[];
  ZoneGridJob? _zone;
  CoachGenerateJob? _next;
  bool _saved = false;
  bool _sameAnswer = false;
  bool _scheduled = false;

  _Choice? _choice;
  Pocket? _pocket;
  Stroke? _stroke;
  double? _power;
  SideSpin _spin = const SideSpin.none();

  @override
  void initState() {
    super.initState();
    _engine = ref.read(coachEngineProvider);
    final req = widget.request;
    final pi = ref.read(playerIntelligenceProvider);
    final libId = req.libraryId;
    if (libId != null) {
      final entry = coachLibraryEntry(libId);
      _topic = entry?.topic ?? req.topic ?? CoachTopic.aiming;
      _difficulty = req.difficulty ?? coachDifficultyFor(pi?.categories[categoryOf(_topic)]);
      if (entry == null) {
        _noSituation = true;
      } else {
        _adopt(entry.situation(_difficulty), null);
      }
    } else {
      _topic = req.topic ?? ref.read(coachRecommendationProvider)?.topic ?? CoachTopic.aiming;
      _difficulty = req.difficulty ?? coachDifficultyFor(pi?.categories[categoryOf(_topic)]);
      final seed = req.seed ?? coachSeedFrom(ref.read(nowProvider)());
      final key = generatedKey(_topic, _difficulty, seed);
      _gen = ref.read(coachPregeneratedProvider).remove(key) ??
          CoachGenerateJob(
            topic: _topic,
            difficulty: _difficulty,
            seed: seed,
            aim: _engine.aim,
            safety: _engine.safety,
          );
      _takeGenerated();
    }
    _schedule();
  }

  @override
  void dispose() {
    _job?.cancel();
    _gen?.cancel();
    // Tình huống sinh sẵn chưa dùng thì bỏ.
    _next?.cancel();
    super.dispose();
  }

  void _adopt(CoachSituation situation, CoachJob? job) {
    _situation = situation;
    _job = job ?? CoachJob(situation.setup, aim: _engine.aim, safety: _engine.safety);
    _session = CoachSession(situation, startedAt: ref.read(nowProvider)());
  }

  /// Bộ sinh xong: dùng tình huống của nó, hoặc lấy thư viện khi hết lần thử.
  bool _takeGenerated() {
    final gen = _gen;
    if (gen == null || _situation != null || !gen.isDone) return false;
    final result = gen.result;
    if (result != null) {
      _adopt(result, gen.job);
      return true;
    }
    _generateFailed = true;
    final done = <String>{
      for (final a in ref.read(coachAttemptsProvider).value ?? const <CoachAttempt>[]) a.situationKey,
    };
    final entry = fallbackEntry(_topic, done);
    if (entry == null) {
      _noSituation = true;
    } else {
      _adopt(entry.situation(_difficulty), null);
    }
    return true;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      _pump();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  bool get _hasWork {
    if (_situation == null) return _gen != null && !_gen!.isDone;
    final job = _job;
    if (job != null && !job.isIdle) return true;
    final zone = _zone;
    if (zone != null && !zone.isDone && _zoneBall != null) return true;
    final next = _next;
    return next != null && !next.isDone;
  }

  void _pump() {
    if (!mounted) return;
    var changed = false;
    final budget = _engine.budget;
    if (_situation == null) {
      _gen?.step(budget: budget);
      changed = _takeGenerated();
    } else if (_job != null && !_job!.isIdle) {
      final events = _job!.step(budget: budget);
      if (events.isNotEmpty) {
        _apply(events);
        changed = true;
      }
    } else if (_zoneBall != null && _zone != null && !_zone!.isDone) {
      _zone!.step(budget: budget);
      changed = true;
    } else if (_next != null && !_next!.isDone) {
      _next!.step(budget: budget);
    }
    _prepareNext();
    if (changed) setState(() {});
    if (_hasWork) _schedule();
  }

  void _apply(List<CoachEvent> events) {
    for (final e in events) {
      switch (e) {
        case ReferenceReady(:final reference):
          _zone ??= ZoneGridJob(after: reference.after, next: reference.finder);
        case Graded(:final index, :final verdict):
          _session!.record(_sent[index], verdict);
          _maybeSave();
        case SafetyReady():
          break;
      }
    }
  }

  /// Sinh sẵn tình huống kế tiếp (spec mục 8.7), cùng nhóm và độ khó.
  void _prepareNext() {
    if (_next != null || _job?.referenceReady != true) return;
    var seed = coachSeedFrom(ref.read(nowProvider)());
    if (seed == _situation?.seed) seed = seed % (CoachRng.modulus - 2) + 1;
    _next = CoachGenerateJob(
      topic: _topic,
      difficulty: _difficulty,
      seed: seed,
      aim: _engine.aim,
      safety: _engine.safety,
    );
  }

  void _maybeSave() {
    final session = _session!;
    if (_saved || !session.ended) return;
    _saved = true;
    final repo = ref.read(coachAttemptRepositoryProvider);
    if (repo == null) return;
    final attempt = session.toAttempt(
      id: const Uuid().v4(),
      userId: repo.userId,
      finishedAt: ref.read(nowProvider)(),
    );
    if (attempt != null) unawaited(repo.record(attempt));
  }

  CoachReference? get _ref => _job?.reference;

  int? get _zoneBall {
    final ref = _ref;
    final session = _session;
    if (ref == null || session == null) return null;
    return zoneBallFor(session, ref);
  }

  CoachAnswer? get _answer => switch (_choice) {
        _Choice.safety => const SafetyAnswer(),
        _Choice.pot when _pocket != null && _stroke != null && _power != null => PotAnswer(
            ball: _situation!.ball,
            pocket: _pocket!,
            stroke: _stroke!,
            power: _power!,
            spin: _spin,
          ),
        _ => null,
      };

  bool get _grading => (_job?.pending ?? 0) > 0;

  void _submit() {
    final answer = _answer;
    final session = _session;
    if (answer == null || session == null || _grading) return;
    final check = session.check(answer);
    if (check != SubmitCheck.ok) {
      setState(() => _sameAnswer = check == SubmitCheck.sameAsLast);
      return;
    }
    _sent.add(answer);
    _job!.submit(answer);
    setState(() => _sameAnswer = false);
    _schedule();
  }

  Future<void> _showAnswer() async {
    final session = _session;
    if (session == null || session.ended) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(Vi.coachShowAnswerConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(Vi.coachShowAnswerNo)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(Vi.coachShowAnswerYes)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      session.revealEarly();
      _maybeSave();
    });
    _schedule();
  }

  void _nextSituation() {
    final next = _next;
    if (next == null) {
      context.replace(Routes.coachGenerated(_topic.name, _difficulty.name, coachSeedFrom(ref.read(nowProvider)())));
      return;
    }
    ref.read(coachPregeneratedProvider)[generatedKey(_topic, _difficulty, next.seed)] = next;
    _next = null;
    context.replace(Routes.coachGenerated(_topic.name, _difficulty.name, next.seed));
  }

  void _pickPocket(Pocket p) {
    if (_session?.ended ?? true) return;
    setState(() {
      _choice = _Choice.pot;
      _pocket = p;
      _sameAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final situation = _situation;
    return Scaffold(
      appBar: AppBar(title: Text(Vi.coachSituationTitle(_topic))),
      body: situation == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_noSituation ? Vi.coachNoSituation(_topic) : Vi.coachComputing),
              ),
            )
          : TablePanelLayout(
              table: situation.setup.table,
              tableBuilder: (layout) => _table(layout, situation),
              panel: _panel(context, situation),
            ),
    );
  }

  Widget _table(TableLayout layout, CoachSituation situation) {
    final session = _session!;
    final ref = _ref;
    final ended = session.ended;
    PlanStep? answerStep;
    if (ended && ref != null) {
      answerStep = ref.kind == PlanStepKind.safety
          ? PlanStep.safety(cbFrom: ref.step.cbFrom, ballNum: ref.ball, safety: _job!.safetyShot)
          : ref.step;
    }
    final lastTrace = session.verdicts.reversed
        .where((v) => v.playerAimed != null)
        .firstOrNull
        ?.playerAimed
        ?.trace;
    final zone = _zoneBall == null ? const <ZoneCell>[] : _zone?.cells ?? const <ZoneCell>[];
    final summary = [
      Vi.coachTableSummary(situation.setup.balls.length, situation.ball),
      if (_pocket case final p? when _choice == _Choice.pot) Vi.simPocketLine(p),
    ].join(' ');
    final reach = layout.touchReach(pocketDrawRadius) * layout.scale;
    return Stack(
      children: [
        Semantics(
          label: summary,
          container: true,
          child: GestureDetector(
            key: SituationScreen.tableKey,
            onTapUp: (d) {
              final p = pocketAt(layout.toTable(d.localPosition), layout);
              if (p != null) _pickPocket(p);
            },
            child: CustomPaint(
              size: layout.size,
              painter: CoachPainter(CoachScene(
                setup: situation.setup,
                target: situation.ball,
                pocket: _choice == _Choice.pot ? _pocket : null,
                playerTrace: lastTrace,
                answer: answerStep,
                zone: zone,
              )),
            ),
          ),
        ),
        // Mỗi lỗ là một nút cho trình đọc màn hình; chạm thật đi qua bàn ở dưới.
        for (final p in Pocket.values)
          Positioned(
            left: layout.toCanvas(layout.table.pocketPosition(p)).dx - reach,
            top: layout.toCanvas(layout.table.pocketPosition(p)).dy - reach,
            width: 2 * reach,
            height: 2 * reach,
            child: Semantics(
              button: true,
              selected: _choice == _Choice.pot && _pocket == p,
              label: Vi.coachPocketButton(p),
              onTap: () => _pickPocket(p),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }

  Widget _chips<T>(String? label, List<T> values, T? selected, String Function(T) text,
      void Function(T) onPick, Key Function(T) keyOf,
      {required bool enabled, String Function(T)? semantics}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final v in values)
              Semantics(
                label: semantics?.call(v),
                child: ChoiceChip(
                  key: keyOf(v),
                  label: Text(text(v)),
                  selected: v == selected,
                  onSelected: enabled ? (_) => onPick(v) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _panel(BuildContext context, CoachSituation situation) {
    final session = _session!;
    final ref = _ref;
    final ended = session.ended;
    final theme = Theme.of(context).textTheme;
    final enabled = !ended && !_grading;
    final last = session.lastVerdict;
    final ready = _answer != null && enabled;
    final waiting = _grading && (ref == null || _job!.searchingSafety);
    Reveal? reveal;
    if (ended && ref != null) reveal = buildReveal(ref, session.verdicts, safety: _job!.safetyShot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_generateFailed) ...[
          Text(Vi.coachGenerateFailed(_topic), style: theme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(Vi.coachPrompt(situation.ball), style: theme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                key: SituationScreen.potKey,
                label: const Text(Vi.coachChoicePot),
                selected: _choice == _Choice.pot,
                onSelected: enabled ? (_) => setState(() => _choice = _Choice.pot) : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ChoiceChip(
                key: SituationScreen.safetyKey,
                label: const Text(Vi.coachChoiceSafety),
                selected: _choice == _Choice.safety,
                onSelected: enabled ? (_) => setState(() => _choice = _Choice.safety) : null,
              ),
            ),
          ],
        ),
        if (_choice == _Choice.pot) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(Vi.coachPickPocket, style: theme.bodySmall),
          _chips<Pocket>(null, Pocket.values, _pocket, Vi.simPocket, _pickPocket, SituationScreen.pocketKey,
              enabled: enabled, semantics: Vi.coachPocketButton),
          _chips<Stroke>(Vi.coachStrokeLabel, strokeCandidates, _stroke, Vi.simStroke,
              (s) => setState(() => _stroke = s), SituationScreen.strokeKey,
              enabled: enabled),
          _chips<double>(Vi.coachPowerLabel, powerCandidates, _power, Vi.simPowerPreset,
              (p) => setState(() => _power = p), SituationScreen.powerKey,
              enabled: enabled),
          _chips<SideSpin>(Vi.simSpinLabel, coachSpins, _spin, Vi.simSpinChip,
              (s) => setState(() => _spin = s), (s) => SituationScreen.spinKey(coachSpins.indexOf(s)),
              enabled: enabled),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            FilledButton(
              key: SituationScreen.submitKey,
              onPressed: ready ? _submit : null,
              child: Text(waiting
                  ? (_job!.searchingSafety ? Vi.planSearchingSafety : Vi.coachComputing)
                  : _grading
                      ? Vi.coachComputing
                      : Vi.coachSubmit),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(Vi.coachTryCount(session.nextTry, coachMaxAnswers), style: theme.bodySmall),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: SituationScreen.showAnswerKey,
            onPressed: ended ? null : _showAnswer,
            child: const Text(Vi.coachShowAnswer),
          ),
        ),
        if (_sameAnswer) Text(Vi.coachSameAnswer, style: theme.bodyMedium),
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (last != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(Vi.coachVerdict(last), style: theme.titleSmall),
              ],
              if (ref != null && !ended)
                for (final line in hintLines(session, ref))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(line),
                  ),
            ],
          ),
        ),
        if (reveal != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(session.solved ? Vi.coachSolutionTitle : Vi.coachRevealTitle, style: theme.titleMedium),
          for (final line in revealLines(reveal,
              searchingSafety: _job!.searchingSafety, table: situation.setup.table))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(line),
            ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              key: SituationScreen.nextKey,
              onPressed: _nextSituation,
              child: const Text(Vi.coachNext),
            ),
          ),
        ] else if (ended && ref == null)
          const Text(Vi.coachComputing),
        const SizedBox(height: AppSpacing.lg),
        Text(Vi.simDisclaimer, style: theme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(Vi.coachModelNote, style: theme.bodySmall),
      ],
    );
  }
}
