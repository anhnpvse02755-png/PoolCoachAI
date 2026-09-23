import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:uuid/uuid.dart';

/// Màn nhập kết quả buổi tập — mục 6.4 của thiết kế.
class DrillSessionScreen extends ConsumerStatefulWidget {
  const DrillSessionScreen({required this.drillId, super.key});

  final String drillId;

  @override
  ConsumerState<DrillSessionScreen> createState() => _DrillSessionScreenState();
}

class _DrillSessionScreenState extends ConsumerState<DrillSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();
  final _attemptsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _scoreController.dispose();
    _attemptsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save(Drill drill) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Đồng hồ tiêm vào, không gọi DateTime.now() thẳng: buổi tập
      // phải rơi đúng vào cái "hôm nay" mà gợi ý đang tính, nếu không
      // chuỗi ngày tập và luật "đã tập hôm nay" đều lệch.
      final now = ref.read(nowProvider)();
      final attempts = _attemptsController.text.isNotEmpty
          ? int.parse(_attemptsController.text)
          : null;
      final log = DrillLog(
        // UUID v4: duy nhất giữa mọi người dùng trên server chung, và
        // không trùng nhau kể cả khi đồng hồ tiêm vào đứng yên trong test.
        id: const Uuid().v4(),
        drillId: drill.id,
        date: now,
        score: num.parse(_scoreController.text),
        attempts: attempts,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await ref.read(drillLogRepositoryProvider).add(log);
      if (!mounted) return;

      final ratio = drillRatio(drill, log);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ratio == null
                ? Vi.sessionSaved
                : Vi.sessionSavedRatio(Vi.drillRatioPercent(ratio)),
          ),
        ),
      );
      context.go(Routes.training);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Vi.sessionSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drillsAsync = ref.watch(drillsProvider);

    return drillsAsync.when(
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
      data: (drills) {
        final drill = drills.where((d) => d.id == widget.drillId).firstOrNull;
        if (drill == null) {
          return PcRootScaffold(
            title: Vi.trainingTitle,
            body: PcEmptyState(
              icon: Icons.help_outline,
              title: Vi.notFoundTitle,
              body: Vi.notFoundBody,
              action: FilledButton(
                onPressed: () => context.go(Routes.training),
                child: const Text(Vi.notFoundAction),
              ),
            ),
          );
        }

        return PcRootScaffold(
          title: Vi.sessionTitle(drill.name),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    drill.goal,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _scoreController,
                    decoration: InputDecoration(
                      labelText: drill.usesAttempts
                          ? Vi.sessionScoreLabelAttempts
                          : Vi.sessionScoreLabelTarget,
                      hintText: drill.usesAttempts
                          ? Vi.sessionScoreHintAttempts
                          : Vi.sessionScoreHintTarget,
                      suffixText: drill.unit,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return Vi.sessionScoreRequired;
                      }
                      if (double.tryParse(value) == null) {
                        return Vi.sessionScoreInvalid;
                      }
                      return null;
                    },
                  ),
                  // Bài chấm theo mục tiêu tuyệt đối không có số lần
                  // thử — hỏi thêm là mời người chơi ghi một log méo.
                  if (drill.usesAttempts) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _attemptsController,
                      decoration: const InputDecoration(
                        labelText: Vi.sessionAttemptsLabel,
                        hintText: Vi.sessionAttemptsHint,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return Vi.sessionAttemptsRequired;
                        }
                        final parsed = int.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return Vi.sessionAttemptsInvalid;
                        }
                        return null;
                      },
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
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(drill),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(Vi.sessionSaveAction),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
