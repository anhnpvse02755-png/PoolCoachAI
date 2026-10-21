import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Chọn 1 trong 3 loại mục tiêu.
class GoalPicker extends ConsumerStatefulWidget {
  const GoalPicker({required this.onPicked, this.onCancel, super.key});

  final VoidCallback onPicked;
  final VoidCallback? onCancel;

  @override
  ConsumerState<GoalPicker> createState() => _GoalPickerState();
}

class _GoalPickerState extends ConsumerState<GoalPicker> {
  bool _pickingCategory = false;

  Future<void> _set(
    GoalKind kind, {
    SkillCategory? category,
    DateTime? eventDate,
  }) async {
    await ref
        .read(roadmapRepositoryProvider)!
        .setGoal(kind: kind, category: category, eventDate: eventDate);
    if (mounted) widget.onPicked();
  }

  Future<void> _pickDate() async {
    final today = ref.read(nowProvider)();
    final first = DateTime(today.year, today.month, today.day + 1);
    final date = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: DateTime(first.year + 1, first.month, first.day),
      helpText: Vi.goalPickDate,
    );
    if (date == null || !goalDateValid(date, today)) return;
    await _set(GoalKind.chuanBiGiai, eventDate: date);
  }

  @override
  Widget build(BuildContext context) {
    final block = lenHangBlock(ref.watch(playerRankProvider).value);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(Vi.goalPickTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        PcCard(
          child: ListTile(
            enabled: block == null,
            title: Text(Vi.goalKind(GoalKind.lenHang)),
            subtitle: Text(
              block == null
                  ? Vi.goalKindBody(GoalKind.lenHang)
                  : Vi.goalBlocked(block),
            ),
            onTap: block == null ? () => _set(GoalKind.lenHang) : null,
            trailing: block == LenHangBlock.noRank
                ? TextButton(
                    onPressed: () => context.push(Routes.onboardingRank),
                    child: const Text(Vi.goalNeedRank),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        PcCard(
          child: ListTile(
            title: Text(Vi.goalKind(GoalKind.thuanThucKyNang)),
            subtitle: Text(Vi.goalKindBody(GoalKind.thuanThucKyNang)),
            onTap: () => setState(() => _pickingCategory = !_pickingCategory),
          ),
        ),
        if (_pickingCategory)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in SkillCategory.values)
                  ActionChip(
                    label: Text(Vi.skill(category)),
                    onPressed: () => _set(
                      GoalKind.thuanThucKyNang,
                      category: category,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        PcCard(
          child: ListTile(
            title: Text(Vi.goalKind(GoalKind.chuanBiGiai)),
            subtitle: Text(Vi.goalKindBody(GoalKind.chuanBiGiai)),
            onTap: _pickDate,
          ),
        ),
        if (widget.onCancel != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text(Vi.goalCancelChange),
            ),
          ),
      ],
    );
  }
}
