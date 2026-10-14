import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_scoring.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';
import 'package:poolcoachai/features/rank/presentation/drill_inputs.dart';

/// Làm bài kiểm tra BU (spec mục 7.3). Màn chỉ đọc Drift: mỗi cú ghi xuống
/// máy ngay, stream bắn lại, màn tự sang cú / bài kế.
class TestScreen extends ConsumerStatefulWidget {
  const TestScreen({super.key});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeTestProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.buTestTitle)),
      body: SafeArea(
        child: switch (active) {
          AsyncData(value: final snap?) => _activeBody(snap),
          AsyncData() => const _PrepView(),
          AsyncError() => const Center(child: Text(Vi.buLoadFailed)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _activeBody(TestSnapshot snap) => DrillRunner(snap: snap);
}

/// Bước chuẩn bị: kích thước bàn, giới thiệu đề và nguồn, giãn cách 14 ngày.
class _PrepView extends ConsumerStatefulWidget {
  const _PrepView();

  @override
  ConsumerState<_PrepView> createState() => _PrepViewState();
}

class _PrepViewState extends ConsumerState<_PrepView> {
  TableSize _size = TableSize.nineFootPlus;
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    await ref.read(assessmentRepositoryProvider)!.startTest(_size);
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final tests = ref.watch(buTestsProvider).value ?? const <BuTest>[];
    final now = ref.watch(nowProvider)();
    final from = retestAvailableFrom(tests);
    final blocked = from != null && now.isBefore(from);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(Vi.buPrepTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const Text(Vi.buPrepIntro),
        const SizedBox(height: AppSpacing.sm),
        Text(Vi.buSourceLine, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        Text(Vi.buTableSizeLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final s in TableSize.values)
              ChoiceChip(
                label: Text(Vi.buTableSize(s)),
                selected: _size == s,
                onSelected: (_) => setState(() => _size = s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(Vi.buDoctorateNeedsNine, style: Theme.of(context).textTheme.bodySmall),
        if (blocked) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(Vi.buRetestFrom(from)),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: blocked || _starting ? null : _start,
          child: const Text(Vi.buStart),
        ),
      ],
    );
  }
}

/// Một bài đang làm: sơ đồ, hướng dẫn, nguồn, điểm hiện tại, ô nhập theo
/// kiểu chấm và nút hoàn tác (spec mục 7.3 bước 2).
class DrillRunner extends ConsumerStatefulWidget {
  const DrillRunner({required this.snap, super.key});

  final TestSnapshot snap;

  @override
  ConsumerState<DrillRunner> createState() => _DrillRunnerState();
}

class _DrillRunnerState extends ConsumerState<DrillRunner> {
  /// Đang ghi một cú: khoá ô nhập, để hai lần bấm nhanh không cùng dựa
  /// trên một bản kết quả cũ mà làm mất một cú.
  bool _busy = false;

  Future<void> _write(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;
    final drill = snap.nextDrill;
    if (drill == null) return const SizedBox.shrink();
    final version = snap.test.examIIVersion;
    final attempts = snap.attemptsOf(drill);
    final repo = ref.read(assessmentRepositoryProvider)!;
    final layout = layoutForAttempt(drill, version, attempts.length.clamp(0, drill.attemptCount - 1));
    final position = switch (attempts) {
      ShotAttempts(:final shots) when drill.kind == ScoringKind.positionLadder => ladderPosition(shots),
      _ => null,
    };
    final drills = snap.currentDrills;
    final canUndo = drills.any((d) => !snap.attemptsOf(d).isEmpty);

    Future<void> record(DrillAttempts next) =>
        _write(() => repo.recordAttempts(snap.test.id, drill.id, next));

    final input = switch (attempts) {
      final ShotAttempts a => ShotInput(drillId: drill.id, enabled: !_busy, onShot: (made) => record(a.add(made))),
      final CountAttempts a => CountInput(
          key: ValueKey('${drill.id}-${a.length}'),
          max: drill.perAttemptMax!,
          enabled: !_busy,
          onSubmit: (n) => record(a.add(n)),
        ),
      final BreakAttempts a => BreakInput(
          key: ValueKey('${drill.id}-${a.length}'),
          enabled: !_busy,
          onSubmit: (b) => record(a.add(b)),
        ),
    };


    final text = Theme.of(context).textTheme;
    // Ô nhập nằm ở khung dưới, luôn thấy mà không phải cuộn qua sơ đồ: người
    // chơi đứng ở bàn, nhập từng cú bằng một tay. Sơ đồ và hướng dẫn cuộn ở
    // khung trên.
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                  Vi.buRunnerHeader(
                      snap.currentExam, version, drills.indexOf(drill) + 1, drills.length),
                  style: text.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(Vi.buDrillTitle(drill.id), style: text.titleMedium),
              Text(Vi.buRunningScore(snap.currentExam, snap.runningScore)),
              const SizedBox(height: AppSpacing.md),
              BuLayoutView(layout: layout, highlightPosition: position),
              const SizedBox(height: AppSpacing.md),
              Text(Vi.buDrillScoring(drill.id, version)),
              const SizedBox(height: AppSpacing.sm),
              Text(Vi.buDrillSetup(drill.id, version)),
              const SizedBox(height: AppSpacing.sm),
              Text(Vi.buLayoutSource(layout.source), style: text.bodySmall),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Vi.buAttemptLabel(drill, attempts.length), style: text.titleSmall),
                if (position != null) Text(Vi.buLadderPosition(position), style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                input,
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: canUndo && !_busy
                        ? () => _write(() => repo.undoLastShot(snap.test.id))
                        : null,
                    icon: const Icon(Icons.undo),
                    label: const Text(Vi.buUndo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
