import 'package:poolcoachai/domain/skill_category.dart';

enum CueType { playing, breakCue, jump }

enum TipHardness { soft, medium, hard }

class CueEquipment {
  const CueEquipment({
    required this.id,
    required this.name,
    required this.type,
    required this.skillCategories,
    this.weightGrams,
    this.tipDiameterMm,
    this.tipHardness,
    this.lastTipMaintenance,
    this.tipMaintenanceDueDate,
    this.updatedAt,
  });

  final String id;
  final String name;
  final CueType type;
  final int? weightGrams;
  final double? tipDiameterMm;
  final TipHardness? tipHardness;
  final List<SkillCategory> skillCategories;
  final DateTime? lastTipMaintenance;
  final DateTime? tipMaintenanceDueDate;
  final DateTime? updatedAt;
}

bool isMaintenanceDueDateValid({
  required DateTime? lastMaintenance,
  required DateTime? dueDate,
}) {
  if (lastMaintenance == null || dueDate == null) return true;

  return DateTime(dueDate.year, dueDate.month, dueDate.day).isAfter(
    DateTime(lastMaintenance.year, lastMaintenance.month, lastMaintenance.day),
  );
}
