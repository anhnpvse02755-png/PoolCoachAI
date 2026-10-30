/// Đổi một thời điểm UTC thành giờ "địa phương". Máy người dùng dùng
/// [defaultToLocal]; helper máy chủ truyền hàm riêng (giờ theo múi của thiết bị).
typedef ToLocal = DateTime Function(DateTime utc);

DateTime defaultToLocal(DateTime utc) => utc.toLocal();

/// Bỏ phần lẻ giây, như Drift khi lưu `DateTime`.
DateTime wholeSeconds(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
  d.millisecondsSinceEpoch ~/ 1000 * 1000,
  isUtc: d.isUtc,
);

String remoteString(Map<String, Object?> item, String key) {
  final value = item[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Trường $key từ server không hợp lệ');
}

String? remoteNullableString(Map<String, Object?> item, String key) {
  final value = item[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Trường $key từ server không hợp lệ');
}

/// Thời điểm UTC (metadata như `updated_at` giữ nguyên UTC).
DateTime remoteInstant(Map<String, Object?> item, String key) {
  final value = item[key];
  if (value is String) return DateTime.parse(value).toUtc();
  throw FormatException('Ngày $key từ server không hợp lệ');
}

/// Thời điểm trả về dạng "địa phương" (qua [toLocal]), hoặc `null`.
DateTime? remoteNullableInstant(
  Map<String, Object?> item,
  String key, {
  ToLocal toLocal = defaultToLocal,
}) => item[key] == null ? null : toLocal(remoteInstant(item, key));

String remoteOwner(Map<String, Object?> item) {
  final owner = item['user_created'];
  if (owner is String) return owner;
  if (owner is Map<String, Object?> && owner['id'] is String) {
    return owner['id']! as String;
  }
  throw const FormatException('Chủ bản ghi từ server không hợp lệ');
}
