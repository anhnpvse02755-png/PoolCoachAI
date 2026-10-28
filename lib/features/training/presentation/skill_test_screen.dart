import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/data/repositories/skill_test_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';
import 'package:poolcoachai/domain/skill_test/certification.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

/// Màn kiểm tra kỹ năng của một bài: chuẩn bị, nhập kết quả, kết quả.
///
/// Dữ liệu chỉ đến từ [skillTestGateProvider] (đã qua cổng). Tiến trình đang
/// làm dở nằm trong State, không có dòng "đang làm" trong DB.
class SkillTestScreen extends ConsumerStatefulWidget {
  const SkillTestScreen({required this.drillId, super.key});

  final String drillId;

  @override
  ConsumerState<SkillTestScreen> createState() => _SkillTestScreenState();
}

class _SkillTestScreenState extends ConsumerState<SkillTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();
  final _attemptsController = TextEditingController();
  final _notesController = TextEditingController();

  TableSize _size = TableSize.nineFootPlus;
  DateTime? _startedAt;
  SkillTestDrillState? _frozen;
  SkillTest? _result;
  bool _busy = false;

  @override
  void dispose() {
    _scoreController.dispose();
    _attemptsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Số có thể gõ dấu phẩy thập phân ("7,5") như dấu chấm.
  double? _parseDecimal(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  /// Đã bấm Bắt đầu mà chưa có kết quả: thoát giữa chừng phải qua Huỷ.
  bool get _inProgress => _startedAt != null && _result == null;

  Future<void> _onBack() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Vi.skillTestCancelConfirmTitle),
        content: const Text(Vi.skillTestCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Vi.skillTestKeepGoing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Vi.skillTestCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && _inProgress) await _cancel();
  }

  String _nameOf(SkillTestDrillState s, String id) =>
      s.drills.where((d) => d.id == id).firstOrNull?.name ?? id;

  void _start(SkillTestDrillState state) {
    setState(() {
      _frozen = state;
      _startedAt = ref.read(nowProvider)();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = _frozen!;
    final drill = state.drill;
    final repo = ref.read(skillTestRepositoryProvider);
    if (repo == null) return;
    setState(() => _busy = true);
    try {
      final notes = _notesController.text.trim();
      final outcome = await repo.completeTest(
        drill: drill,
        drills: state.drills,
        tableSize: _size,
        startedAt: _startedAt!,
        score: _parseDecimal(_scoreController.text)!,
        attempts: drill.usesAttempts
            ? int.parse(_attemptsController.text)
            : null,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      switch (outcome) {
        case SkillTestRecorded(:final test):
          setState(() => _result = test);
        case SkillTestLocked(:final gate):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Vi.skillTestGateLine(gate, nameOf: (id) => _nameOf(state, id)),
              ),
            ),
          );
          setState(() {
            _startedAt = null;
            _frozen = null;
          });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(Vi.sessionSaveFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final state = _frozen!;
    final repo = ref.read(skillTestRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo?.cancelTest(
        drill: state.drill,
        tableSize: _size,
        startedAt: _startedAt!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(Vi.skillTestCancelled)));
      context.go(Routes.drill(widget.drillId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(Vi.sessionSaveFailed)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Quay lại của hệ thống giữa lúc làm bài hành xử như Huỷ (có xác nhận).
    return PopScope(
      canPop: !_inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Kết quả ở lại màn dù cổng đã đổi (vừa đạt thì cổng thành AlreadyCertified).
    final result = _result;
    final frozen = _frozen;
    if (result != null && frozen != null) {
      return PcRootScaffold(
        title: Vi.skillTestTitle(frozen.drill.name),
        body: _resultView(context, frozen, result),
      );
    }

    final async = ref.watch(skillTestGateProvider(widget.drillId));
    return async.when(
      loading: () => const PcRootScaffold(
        title: Vi.trainingTitle,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const PcRootScaffold(
        title: Vi.trainingTitle,
        body: PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
      ),
      data: (state) {
        if (state == null) {
          return const PcRootScaffold(
            title: Vi.trainingTitle,
            body: PcEmptyState(
              icon: Icons.help_outline,
              title: Vi.skillTestNotFoundTitle,
              body: Vi.skillTestNotFoundBody,
            ),
          );
        }
        // Đang nhập dở: giữ bài đã chụp, cổng đổi giữa chừng không đá người dùng ra.
        final live = _startedAt != null ? (_frozen ?? state) : state;
        return PcRootScaffold(
          title: Vi.skillTestTitle(live.drill.name),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _startedAt == null
                ? _prepView(context, state)
                : _entryView(context, live),
          ),
        );
      },
    );
  }

  Widget _prepView(BuildContext context, SkillTestDrillState state) {
    final drill = state.drill;
    final theme = Theme.of(context);
    final open = state.gate is SkillTestOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Vi.skillTestConditionsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(Vi.buTableSizeLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in TableSize.values)
              ChoiceChip(
                label: Text(Vi.buTableSize(s)),
                selected: _size == s,
                onSelected: (_) => setState(() => _size = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(Vi.drillStepsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...drill.steps.indexed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 12, child: Text('${entry.$1 + 1}')),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.$2)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(Vi.skillTestCriterion(drill)),
        const SizedBox(height: 16),
        if (!open) ...[
          Text(
            Vi.skillTestGateLine(
              state.gate,
              nameOf: (id) => _nameOf(state, id),
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: open ? () => _start(state) : null,
          child: const Text(Vi.skillTestStart),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go(Routes.drill(widget.drillId)),
          child: const Text(Vi.cancel),
        ),
      ],
    );
  }

  Widget _entryView(BuildContext context, SkillTestDrillState state) {
    final drill = state.drill;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Vi.skillTestCriterion(drill)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _scoreController,
            decoration: InputDecoration(
              labelText: drill.usesAttempts
                  ? Vi.sessionScoreLabelAttempts
                  : Vi.sessionScoreLabelTarget,
              hintText: drill.usesAttempts
                  ? Vi.sessionScoreHintAttempts
                  : drillProvenanceOf(drill.id) != null
                  ? Vi.sessionScoreHintShots(
                      drillProvenanceOf(drill.id)!.shots,
                    )
                  : Vi.sessionScoreHintTarget,
              suffixText: drill.unit,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => _validateScore(drill, value),
          ),
          if (drill.usesAttempts) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _attemptsController,
              decoration: const InputDecoration(
                labelText: Vi.sessionAttemptsLabel,
                hintText: Vi.sessionAttemptsHint,
              ),
              keyboardType: TextInputType.number,
              validator: (value) => _validateAttempts(drill, value),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: Vi.sessionNotesLabel,
              hintText: Vi.sessionNotesHint,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text(Vi.skillTestSubmit),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            child: const Text(Vi.skillTestCancel),
          ),
        ],
      ),
    );
  }

  String? _validateScore(Drill drill, String? value) {
    if (value == null || value.trim().isEmpty) return Vi.sessionScoreRequired;
    final score = _parseDecimal(value);
    if (score == null) return Vi.sessionScoreInvalid;
    final error = checkSkillTestInput(
      drill,
      score: score,
      attempts: int.tryParse(_attemptsController.text),
    );
    return switch (error) {
      SkillTestInputError.scoreInvalid ||
      SkillTestInputError.scoreNotWhole ||
      SkillTestInputError.scoreAboveAttempts ||
      SkillTestInputError.scoreAboveShots => Vi.skillTestInputError(error!),
      _ => null,
    };
  }

  String? _validateAttempts(Drill drill, String? value) {
    if (value == null || value.trim().isEmpty) {
      return Vi.sessionAttemptsRequired;
    }
    final attempts = int.tryParse(value);
    final error = checkSkillTestInput(drill, score: 0, attempts: attempts ?? 0);
    return switch (error) {
      SkillTestInputError.attemptsRequired ||
      SkillTestInputError.attemptsInvalid => Vi.skillTestInputError(error!),
      _ => attempts == null ? Vi.sessionAttemptsInvalid : null,
    };
  }

  Widget _resultView(
    BuildContext context,
    SkillTestDrillState state,
    SkillTest result,
  ) {
    final drill = state.drill;
    final theme = Theme.of(context);
    final criterion = Vi.skillTestGradedAgainst(result, drill.unit);
    final score = result.score;
    final mark = skillTestPassMark(result);
    final next = nextLevelDrills(drill, state.drills);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.certifies) ...[
            Text(
              Vi.skillTestPassed(drill.name, drill.level),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(Vi.shortDate(result.completedAt!)),
            const SizedBox(height: 8),
            Text(
              next.isEmpty
                  ? Vi.skillTestNoNextLevel
                  : Vi.skillTestNextLevel([for (final d in next) d.name]),
            ),
          ] else ...[
            if (score != null && mark != null)
              Text(
                Vi.skillTestFailed(score, mark),
                style: theme.textTheme.titleLarge,
              ),
            const SizedBox(height: 8),
            const Text(Vi.skillTestFailedAdvice),
            const SizedBox(height: 8),
            const Text(Vi.skillTestRetakeRule),
          ],
          if (criterion != null) ...[
            const SizedBox(height: 8),
            Text(criterion),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(Routes.drill(widget.drillId)),
            child: const Text(Vi.skillTestBackToDrill),
          ),
        ],
      ),
    );
  }
}
