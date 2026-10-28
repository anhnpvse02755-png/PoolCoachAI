import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

/// Thẻ Bài kiểm tra ở chi tiết bài: mở, khoá có lý do, đã chứng nhận.
///
/// Chỉ đọc [skillTestGateProvider] (đã qua cổng). "Phong độ gần đây chưa đạt"
/// lấy từ `formSlipped` của provider, không tính lại ở giao diện.
class SkillTestCard extends ConsumerWidget {
  const SkillTestCard({required this.drill, super.key});

  final Drill drill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(skillTestGateProvider(drill.id));
    if (async.isLoading) return const SizedBox.shrink();
    if (async.hasError) {
      return _frame(context, const Text(Vi.skillTestDataError));
    }
    final state = async.value;
    if (state == null) return const SizedBox.shrink();
    final cert = ref.watch(certificationsProvider).value?[drill.id];

    final names = {for (final d in state.drills) d.id: d.name};
    final gate = state.gate;
    final theme = Theme.of(context);
    return _frame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Vi.skillTestGateLine(gate, nameOf: (id) => names[id] ?? id),
          ),
          if (gate is SkillTestOpen) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(Routes.skillTest(drill.id)),
              child: const Text(Vi.skillTestOpen),
            ),
          ],
          if (gate is AlreadyCertified && cert != null) ...[
            // Tiêu chí và điều kiện đo lấy từ lần đạt, không phải bài hiện tại.
            if (Vi.criterionSnapshot(cert.passThreshold, cert.target, drill.unit)
                case final criterion?)
              Text(criterion, style: theme.textTheme.bodySmall),
            Text(
              Vi.certificationEvidence(
                cert.tableSize,
                cert.score,
                cert.attempts,
                drill.unit,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (gate is AlreadyCertified && state.formSlipped) ...[
            const SizedBox(height: 8),
            Text(
              Vi.skillTestFormSlipped,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _frame(BuildContext context, Widget body) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Vi.skillTestCardTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    ),
  );
}
