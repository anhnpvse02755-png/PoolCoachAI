import 'package:poolcoachai/domain/skill_category.dart';

/// Sáu tên mọi bản đã phát hành đọc được. Đóng băng: không bao giờ thêm tên vào đây.
const legacyCategoryNames = <String>{
  'aiming',
  'position',
  'breakShot',
  'safety',
  'kick',
  'bank',
};

const _invalid = FormatException('Nhóm kỹ năng mở rộng từ server không hợp lệ');

/// Tên cũ đi trường cũ, mọi tên khác đi trường `_ext`.
({String? legacy, String? ext}) splitCategoryName(String? name) {
  if (name == null) return (legacy: null, ext: null);
  return legacyCategoryNames.contains(name)
      ? (legacy: name, ext: null)
      : (legacy: null, ext: name);
}

/// Trường cũ thắng; không có thì lấy `_ext` nếu bản này biết tên đó, tên lạ bị bỏ qua.
String? joinCategoryName(String? legacy, Object? ext) {
  if (legacy != null) return legacy;
  if (ext == null) return null;
  if (ext is! String) throw _invalid;
  return SkillCategory.values.any((c) => c.name == ext) ? ext : null;
}

({List<String> legacy, List<String> ext}) splitCategoryNames(
  Iterable<String> names,
) => (
  legacy: names.where(legacyCategoryNames.contains).toList(),
  ext: names.where((n) => !legacyCategoryNames.contains(n)).toList(),
);

/// Hợp của hai danh sách theo thứ tự enum, không trùng, bỏ tên lạ trong `_ext`.
List<String> joinCategoryNames(List<String> legacy, Object? ext) {
  if (ext != null && (ext is! List<Object?> || ext.any((e) => e is! String))) {
    throw _invalid;
  }
  final all = {...legacy, ...?(ext as List<Object?>?)?.cast<String>()};
  return [
    for (final c in SkillCategory.values)
      if (all.contains(c.name)) c.name,
  ];
}
