import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:uuid/uuid.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  bool _saving = false;

  Future<void> _requestMaintenanceNotifications() async {
    final service = ref.read(maintenanceReminderServiceProvider);
    await service.requestPermission();
    if (mounted) setState(() {});
  }

  String _dateLabel(DateTime? value) =>
      value == null ? Vi.equipmentNoDate : _formatDate(value);

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  String? _positiveNumberValidator(String? value, {required bool integer}) {
    if (value == null || value.trim().isEmpty) return null;
    final number = integer ? int.tryParse(value) : double.tryParse(value);
    if (number == null ||
        number <= 0 ||
        (number is double && !number.isFinite)) {
      return integer
          ? Vi.equipmentWeightInvalid
          : Vi.equipmentTipDiameterInvalid;
    }
    return null;
  }

  Future<void> _editCue({CueEquipment? existing}) async {
    final formKey = GlobalKey<FormState>();
    var type = existing?.type ?? CueType.playing;
    var hardness = existing?.tipHardness;
    final skills = {...?existing?.skillCategories};
    var lastMaintenance = existing?.lastTipMaintenance;
    var dueDate = existing?.tipMaintenanceDueDate;
    var name = existing?.name ?? '';
    var weight = existing?.weightGrams?.toString() ?? '';
    var diameter = existing?.tipDiameterMm?.toString() ?? '';
    var dialogSaving = false;
    final currentDate = ref.read(nowProvider)();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? Vi.equipmentAdd : Vi.equipmentEdit),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(
                        labelText: Vi.equipmentName,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSaved: (value) => name = value?.trim() ?? '',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? Vi.equipmentNameRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CueType>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: Vi.equipmentType,
                      ),
                      items: CueType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(Vi.equipmentTypeName(value)),
                            ),
                          )
                          .toList(),
                      onChanged: dialogSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => type = value);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: weight,
                      decoration: const InputDecoration(
                        labelText: Vi.equipmentWeight,
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) => weight = value?.trim() ?? '',
                      validator: (value) =>
                          _positiveNumberValidator(value, integer: true),
                    ),
                    TextFormField(
                      initialValue: diameter,
                      decoration: const InputDecoration(
                        labelText: Vi.equipmentTipDiameter,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onSaved: (value) => diameter = value?.trim() ?? '',
                      validator: (value) =>
                          _positiveNumberValidator(value, integer: false),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TipHardness?>(
                      initialValue: hardness,
                      decoration: const InputDecoration(
                        labelText: Vi.equipmentTipHardness,
                      ),
                      items: [
                        const DropdownMenuItem<TipHardness?>(
                          value: null,
                          child: Text(Vi.equipmentNoHardness),
                        ),
                        ...TipHardness.values.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(Vi.equipmentHardnessName(value)),
                          ),
                        ),
                      ],
                      onChanged: dialogSaving
                          ? null
                          : (value) => setDialogState(() => hardness = value),
                    ),
                    const SizedBox(height: 12),
                    const Text(Vi.equipmentSkills),
                    Wrap(
                      spacing: 6,
                      children: SkillCategory.values
                          .map(
                            (skill) => FilterChip(
                              label: Text(Vi.skill(skill)),
                              selected: skills.contains(skill),
                              onSelected: dialogSaving
                                  ? null
                                  : (selected) => setDialogState(() {
                                      if (selected) {
                                        skills.add(skill);
                                      } else {
                                        skills.remove(skill);
                                      }
                                    }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _MaintenanceDateField(
                      label: Vi.equipmentLastMaintenance,
                      value: lastMaintenance,
                      currentDate: currentDate,
                      formatDate: _formatDate,
                      onChanged: (value) =>
                          setDialogState(() => lastMaintenance = value),
                    ),
                    _MaintenanceDateField(
                      label: Vi.equipmentDueDate,
                      value: dueDate,
                      currentDate: currentDate,
                      formatDate: _formatDate,
                      onChanged: (value) =>
                          setDialogState(() => dueDate = value),
                    ),
                  ],
                ),
              ),
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
                      if (lastMaintenance != null &&
                          dueDate != null &&
                          !isMaintenanceDueDateValid(
                            lastMaintenance: lastMaintenance,
                            dueDate: dueDate,
                          )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(Vi.equipmentDueDateInvalid),
                          ),
                        );
                        return;
                      }
                      formKey.currentState!.save();
                      setDialogState(() => dialogSaving = true);
                      setState(() => _saving = true);
                      final cue = CueEquipment(
                        id: existing?.id ?? const Uuid().v4(),
                        name: name,
                        type: type,
                        weightGrams: weight.isEmpty ? null : int.parse(weight),
                        tipDiameterMm: diameter.isEmpty
                            ? null
                            : double.parse(diameter),
                        tipHardness: hardness,
                        skillCategories: skills.toList(growable: false),
                        lastTipMaintenance: lastMaintenance,
                        tipMaintenanceDueDate: dueDate,
                      );
                      try {
                        await ref
                            .read(cueEquipmentRepositoryProvider)
                            .save(cue);
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (error) {
                        debugPrint('Cue equipment save failed: $error');
                        if (!context.mounted) return;
                        setDialogState(() => dialogSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(Vi.equipmentSaveFailed)),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: const Text(Vi.equipmentSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeCue(CueEquipment cue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cue.name),
        content: const Text(
          '${Vi.equipmentDeleteQuestion}\n${Vi.equipmentDeleteWarning}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Vi.scheduleKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.equipmentDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(cueEquipmentRepositoryProvider).remove(cue.id);
    } catch (error) {
      debugPrint('Cue equipment delete failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Vi.equipmentDeleteFailed)));
    }
  }

  bool _isDueSoon(DateTime dueDate, DateTime now) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return !due.isBefore(today) && due.difference(today).inDays <= 7;
  }

  Widget _cueCard(CueEquipment cue, DateTime now, List<TimerSession> sessions) {
    final dueDate = cue.tipMaintenanceDueDate;
    final overdue =
        dueDate != null &&
        DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        ).isBefore(DateTime(now.year, now.month, now.day));
    final dueSoon = dueDate != null && _isDueSoon(dueDate, now);
    final details = <String>[
      Vi.equipmentTypeName(cue.type),
      if (cue.weightGrams != null) Vi.equipmentWeightValue(cue.weightGrams!),
      if (cue.tipDiameterMm != null)
        Vi.equipmentDiameterValue(cue.tipDiameterMm!),
      if (cue.tipHardness != null) Vi.equipmentHardnessName(cue.tipHardness!),
    ];
    final skills = cue.skillCategories.map(Vi.skill).join(', ');
    final cueSessions = sessions.where((session) => session.cueId == cue.id);
    final practiceSeconds = cueSessions.fold<int>(
      0,
      (total, session) => total + session.durationSec,
    );
    final lastUsed = cueSessions.isEmpty
        ? null
        : cueSessions.reduce(
            (latest, session) =>
                session.date.isAfter(latest.date) ? session : latest,
          );

    return Card(
      child: ListTile(
        leading: Icon(
          overdue || dueSoon ? Icons.build_circle_outlined : Icons.sports,
          color: overdue
              ? Theme.of(context).colorScheme.error
              : dueSoon
              ? Theme.of(context).colorScheme.tertiary
              : null,
        ),
        title: Text(cue.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details.join(' · ')),
            if (skills.isNotEmpty) Text(skills),
            Text(
              '${Vi.equipmentLastMaintenance}: '
              '${_dateLabel(cue.lastTipMaintenance)}',
            ),
            if (lastUsed == null)
              const Text(Vi.equipmentNoRecordedPractice)
            else ...[
              Text(
                '${Vi.equipmentPracticeTime}: '
                '${Vi.statsDuration(practiceSeconds)}',
              ),
              Text('${Vi.equipmentLastUsed}: ${_formatDate(lastUsed.date)}'),
            ],
            if (dueDate != null)
              Text(
                '${overdue
                    ? Vi.equipmentDue
                    : dueSoon
                    ? Vi.equipmentDueSoon
                    : Vi.equipmentDueDate}: '
                '${_formatDate(dueDate)}',
                style: overdue || dueSoon
                    ? TextStyle(
                        color: overdue
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.tertiary,
                      )
                    : null,
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !_saving,
          onSelected: (action) {
            if (action == 'edit') _editCue(existing: cue);
            if (action == 'delete') _removeCue(cue);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text(Vi.equipmentEdit)),
            const PopupMenuItem(
              value: 'delete',
              child: Text(Vi.equipmentDelete),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipmentAsync = ref.watch(cueEquipmentProvider);
    final sessionsAsync = ref.watch(timerSessionsProvider);
    final now = ref.watch(nowProvider)();

    return PcRootScaffold(
      title: Vi.equipmentTitle,
      body: Stack(
        children: [
          Positioned.fill(
            child: equipmentAsync.hasError || sessionsAsync.hasError
                ? const PcEmptyState(
                    icon: Icons.cloud_off,
                    title: Vi.dataErrorTitle,
                    body: Vi.dataErrorBody,
                  )
                : !equipmentAsync.hasValue || !sessionsAsync.hasValue
                ? const Center(child: CircularProgressIndicator())
                : _equipmentList(
                    equipmentAsync.requireValue,
                    sessionsAsync.requireValue,
                    now,
                  ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'equipment-add',
              onPressed: _saving ? null : () => _editCue(),
              icon: const Icon(Icons.add),
              label: const Text(Vi.equipmentAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipmentList(
    List<CueEquipment> cues,
    List<TimerSession> sessions,
    DateTime now,
  ) {
    final sortedCues = [...cues]
      ..sort((a, b) {
        final priorityA = _maintenancePriority(a.tipMaintenanceDueDate, now);
        final priorityB = _maintenancePriority(b.tipMaintenanceDueDate, now);
        final priorityComparison = priorityA.compareTo(priorityB);
        if (priorityComparison != 0) return priorityComparison;

        if (priorityA == 1) {
          final dueDateComparison = a.tipMaintenanceDueDate!.compareTo(
            b.tipMaintenanceDueDate!,
          );
          if (dueDateComparison != 0) return dueDateComparison;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return Column(
      children: [
        _maintenanceReminderCard(),
        Expanded(
          child: cues.isEmpty
              ? const Center(
                  child: PcEmptyState(
                    icon: Icons.sports,
                    title: Vi.equipmentTitle,
                    body: Vi.equipmentEmpty,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: sortedCues
                      .map((cue) => _cueCard(cue, now, sessions))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _maintenanceReminderCard() {
    final reminders = ref.watch(maintenanceReminderServiceProvider);
    if (!reminders.isSupported) return const SizedBox.shrink();
    final permission = reminders.permission;
    final message = permission == 'granted'
        ? Vi.equipmentReminderEnabled
        : permission == 'denied'
        ? Vi.equipmentReminderDenied
        : Vi.equipmentReminderPrompt;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: const Text(Vi.equipmentReminderTitle),
        subtitle: Text(message),
        trailing:
            permission != 'granted' &&
                permission != 'denied'
            ? TextButton(
                onPressed: _requestMaintenanceNotifications,
                child: const Text(Vi.equipmentReminderEnable),
              )
            : permission == 'granted'
            ? const Icon(Icons.check_circle_outline)
            : null,
      ),
    );
  }

  int _maintenancePriority(DateTime? dueDate, DateTime now) {
    if (dueDate == null) return 2;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    if (due.isBefore(today)) return 0;
    if (due.difference(today).inDays <= 7) return 1;
    return 2;
  }
}

class _MaintenanceDateField extends StatelessWidget {
  const _MaintenanceDateField({
    required this.label,
    required this.value,
    required this.currentDate,
    required this.formatDate,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final DateTime currentDate;
  final String Function(DateTime) formatDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value == null ? Vi.equipmentNoDate : formatDate(value!)),
    trailing: Wrap(
      children: [
        IconButton(
          tooltip: Vi.equipmentSelectDate,
          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: value ?? currentDate,
              currentDate: currentDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (selected != null) onChanged(selected);
          },
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        if (value != null)
          IconButton(
            tooltip: Vi.equipmentClearDate,
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );
}
