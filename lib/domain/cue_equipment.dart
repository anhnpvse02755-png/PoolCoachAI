import 'package:poolcoachai/domain/skill_category.dart';

enum CueType { playing, breakCue, jump, breakJump }

enum TipHardness { soft, medium, hard }

class CueEquipment {
  const CueEquipment({
    required this.id,
    required this.name,
    required this.type,
    required this.skillCategories,
    this.weightGrams,
    this.shaftBrand,
    this.shaftDiameterMm,
    this.tipBrand,
    this.tipHardness,
    this.buttBrand,
    this.lastTipMaintenance,
    this.tipMaintenanceDueDate,
    this.updatedAt,
  });

  final String id;
  final String name;
  final CueType type;
  final int? weightGrams;

  /// Hãng ngọn (nhập tự do).
  final String? shaftBrand;

  /// Size ngọn: đường kính ngọn, tính bằng mm.
  final double? shaftDiameterMm;

  /// Hãng đầu tẩy (nhập tự do).
  final String? tipBrand;
  final TipHardness? tipHardness;

  /// Hãng chuôi (nhập tự do).
  final String? buttBrand;
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
