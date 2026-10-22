import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:uuid/uuid.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  bool _saving = false;

  Future<void> _editSlot({ScheduleSlot? existing}) async {
    final formKey = GlobalKey<FormState>();
    var day = existing?.day ?? 0;
    final savedTime = existing?.time.split(':');
    var time = savedTime == null
        ? const TimeOfDay(hour: 19, minute: 0)
        : TimeOfDay(
            hour: int.parse(savedTime[0]),
            minute: int.parse(savedTime[1]),
          );
    SkillCategory? category = existing?.cat;
    var dialogSaving = false;
    var label = existing?.label ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          // Máy ngang, bàn phím mở: hộp thoại chỉ còn ~150 px. Tiêu đề
          // cuộn cùng ô nhập, chỉ hàng nút đứng yên trên bàn phím.
          scrollable: true,
          title: Text(existing == null ? Vi.scheduleAdd : Vi.scheduleEdit),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: label,
                  decoration: const InputDecoration(
                    labelText: Vi.scheduleLabel,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSaved: (value) => label = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? Vi.scheduleLabelRequired
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(
                    labelText: Vi.scheduleChooseDay,
                  ),
                  items: [
                    for (var index = 0; index < Vi.scheduleDays.length; index++)
                      DropdownMenuItem(
                        value: index,
                        child: Text(Vi.scheduleDays[index]),
                      ),
                  ],
                  onChanged: dialogSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() => day = value);
                          }
                        },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(Vi.scheduleChooseTime),
                  trailing: TextButton(
                    onPressed: dialogSaving
                        ? null
                        : () async {
                            final selected = await showTimePicker(
                              context: dialogContext,
                              initialTime: time,
                            );
                            if (selected != null) {
                              setDialogState(() => time = selected);
                            }
                          },
                    child: Text(time.format(dialogContext)),
                  ),
                ),
                DropdownButtonFormField<SkillCategory?>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: Vi.scheduleChooseCategory,
                  ),
                  items: [
                    const DropdownMenuItem<SkillCategory?>(
                      value: null,
                      child: Text(Vi.scheduleNoCategory),
                    ),
                    ...SkillCategory.values.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(Vi.skill(value)),
                      ),
                    ),
                  ],
                  onChanged: dialogSaving
                      ? null
                      : (value) => setDialogState(() => category = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: dialogSaving
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text(Vi.scheduleCancel),
            ),
            FilledButton(
              onPressed: dialogSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      formKey.currentState!.save();
                      setDialogState(() => dialogSaving = true);
                      setState(() => _saving = true);
                      final formattedTime =
                          '${time.hour.toString().padLeft(2, '0')}:'
                          '${time.minute.toString().padLeft(2, '0')}';
                      try {
                        await ref
                            .read(scheduleRepositoryProvider)
                            .save(
                              ScheduleSlot(
                                id: existing?.id ?? const Uuid().v4(),
                                day: day,
                                time: formattedTime,
                                label: label,
                                cat: category,
                              ),
                            );
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (error) {
                        debugPrint('Schedule save failed: $error');
                        if (!context.mounted) return;
                        setDialogState(() => dialogSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(Vi.scheduleSaveFailed)),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: const Text(Vi.scheduleSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSlot(ScheduleSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(slot.label),
        content: const Text(Vi.scheduleDeleteQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Vi.scheduleKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.scheduleDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(scheduleRepositoryProvider).remove(slot.id);
    } catch (error) {
      debugPrint('Schedule delete failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(Vi.scheduleDeleteFailed)));
    }
  }

  Widget _slotTile(ScheduleSlot slot) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 52,
      child: Text(slot.time, style: Theme.of(context).textTheme.titleSmall),
    ),
    title: Text(slot.label),
    subtitle: slot.cat == null ? null : Text(Vi.skill(slot.cat!)),
    trailing: Wrap(
      children: [
        IconButton(
          tooltip: Vi.scheduleEditTooltip,
          onPressed: _saving ? null : () => _editSlot(existing: slot),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: Vi.scheduleDeleteTooltip,
          onPressed: _saving ? null : () => _removeSlot(slot),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );

  Widget _scheduleList(List<ScheduleSlot> slots) {
    if (slots.isEmpty) {
      return const Center(
        child: PcEmptyState(
          icon: Icons.calendar_month_outlined,
          title: Vi.scheduleTitle,
          body: Vi.scheduleEmpty,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        for (var day = 0; day < Vi.scheduleDays.length; day++)
          if (slots.any((slot) => slot.day == day)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                Vi.scheduleDays[day],
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...slots.where((slot) => slot.day == day).map(_slotTile),
            const Divider(height: 1),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(scheduleProvider);

    return PcRootScaffold(
      title: Vi.scheduleTitle,
      body: Stack(
        children: [
          Positioned.fill(
            child: slotsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const PcEmptyState(
                icon: Icons.cloud_off,
                title: Vi.dataErrorTitle,
                body: Vi.dataErrorBody,
              ),
              data: _scheduleList,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'schedule-add',
              onPressed: _saving ? null : () => _editSlot(),
              icon: const Icon(Icons.add),
              label: const Text(Vi.scheduleAdd),
            ),
          ),
        ],
      ),
    );
  }
}
