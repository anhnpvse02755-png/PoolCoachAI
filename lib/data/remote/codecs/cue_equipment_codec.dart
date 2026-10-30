import 'package:poolcoachai/data/database/category_compat.dart';
import 'package:poolcoachai/data/remote/codecs/remote_values.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Cơ kéo từ server. Ngày chỉ-ngày giữ nửa đêm địa phương; mọi mốc giờ khác
/// đi qua [toLocal].
({CueEquipment cue, bool isDeleted}) cueEquipmentFromRemote(
  Map<String, Object?> item, {
  ToLocal toLocal = defaultToLocal,
}) {
  final cue = _cueFromRemote(item, toLocal);
  return (cue: cue, isDeleted: _remoteDeleted(item));
}

CueEquipment _cueFromRemote(Map<String, Object?> item, ToLocal toLocal) {
  final type = CueType.values.firstWhere(
    (value) => value.name == remoteString(item, 'type'),
    orElse: () => throw const FormatException('Loại cơ từ server không hợp lệ'),
  );
  final hardnessName = item['tip_hardness'] as String?;
  final hardness = hardnessName == null
      ? null
      : TipHardness.values.firstWhere(
          (value) => value.name == hardnessName,
          orElse: () => throw const FormatException(
            'Độ cứng đầu cơ từ server không hợp lệ',
          ),
        );
  final categories = item['skill_categories'];
  if (categories is! List<Object?> ||
      categories.any((category) => category is! String)) {
    throw const FormatException('Nhóm kỹ năng từ server không hợp lệ');
  }
  // Trường cũ vẫn parse nghiêm: tên lạ ở đây là dữ liệu hỏng, không phải
  // nhóm của bản sau (nhóm của bản sau chỉ đi trong skill_categories_ext).
  final legacyNames = [
    for (final category in categories)
      SkillCategory.values
          .firstWhere(
            (value) => value.name == category! as String,
            orElse: () => throw const FormatException(
              'Nhóm kỹ năng từ server không hợp lệ',
            ),
          )
          .name,
  ];
  final skills = joinCategoryNames(
    legacyNames,
    item['skill_categories_ext'],
  ).map(SkillCategory.values.byName).toList(growable: false);
  final weight = item['weight_grams'];
  final diameter = item['tip_diameter_mm'];
  if (weight != null && (weight is! int || weight <= 0)) {
    throw const FormatException('Trọng lượng cơ từ server không hợp lệ');
  }
  if (diameter != null &&
      (diameter is! num || !diameter.isFinite || diameter <= 0)) {
    throw const FormatException('Size ngọn từ server không hợp lệ');
  }
  final name = remoteString(item, 'name');
  if (name.trim().isEmpty) {
    throw const FormatException('Tên cơ từ server không hợp lệ');
  }
  final cue = CueEquipment(
    id: remoteString(item, 'id'),
    name: name,
    type: type,
    weightGrams: (weight as num?)?.toInt(),
    shaftBrand: remoteNullableString(item, 'shaft_brand'),
    shaftDiameterMm: (diameter as num?)?.toDouble(),
    tipBrand: remoteNullableString(item, 'tip_brand'),
    tipHardness: hardness,
    buttBrand: remoteNullableString(item, 'butt_brand'),
    skillCategories: skills,
    lastTipMaintenance: _nullableDate(item, 'last_tip_maintenance', toLocal),
    tipMaintenanceDueDate: _nullableDate(
      item,
      'tip_maintenance_due_date',
      toLocal,
    ),
    updatedAt: remoteInstant(item, 'updated_at'),
  );
  if (!isMaintenanceDueDateValid(
    lastMaintenance: cue.lastTipMaintenance,
    dueDate: cue.tipMaintenanceDueDate,
  )) {
    throw const FormatException('Ngày bảo dưỡng cơ từ server không hợp lệ');
  }
  return cue;
}

bool _remoteDeleted(Map<String, Object?> item) {
  final value = item['is_deleted'];
  if (value is bool) return value;
  throw const FormatException('Trạng thái xóa cơ từ server không hợp lệ');
}

DateTime? _nullableDate(
  Map<String, Object?> item,
  String key,
  ToLocal toLocal,
) {
  final value = item[key];
  if (value == null) return null;
  if (value is String) {
    final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (dateOnly != null) {
      final year = int.parse(dateOnly[1]!);
      final month = int.parse(dateOnly[2]!);
      final day = int.parse(dateOnly[3]!);
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        throw FormatException('Ngày $key từ server không hợp lệ');
      }
      return date;
    }
    return toLocal(DateTime.parse(value).toUtc());
  }
  throw FormatException('Ngày $key từ server không hợp lệ');
}
