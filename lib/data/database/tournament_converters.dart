import 'package:drift/drift.dart' show Value;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

/// Loại bi lạ (máy chủ mới hơn) coi là không có: không ném, giải vẫn dùng được.
PoolGameType? _gameTypeOrNull(String? name) =>
    name == null ? null : PoolGameType.values.asNameMap()[name];

Tournament toTournament(TournamentRow r) => Tournament(
  id: r.id,
  name: r.name,
  startDate: r.startDate,
  endDate: r.endDate,
  location: r.location,
  gameType: _gameTypeOrNull(r.gameType),
  resultNote: r.resultNote,
  notes: r.notes,
);

String _two(int n) => n.toString().padLeft(2, '0');

/// Ngày thuần `YYYY-MM-DD` theo năm, tháng, ngày địa phương của [d].
String toRemoteDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// Đọc ngày từ máy chủ; phần giờ phía sau (nếu có) bị bỏ qua.
DateTime fromRemoteDate(Object? value) {
  if (value is! String) {
    throw FormatException('Ngày không phải chuỗi', value);
  }
  final m = _datePattern.firstMatch(value);
  if (m == null) throw FormatException('Ngày sai dạng YYYY-MM-DD', value);
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  // DateTime tự cuốn ngày/tháng vượt khoảng (2026-02-30 thành 2026-03-02):
  // đi vòng lại để bắt ngày không có thật.
  if (date.year != y || date.month != mo || date.day != d) {
    throw FormatException('Ngày không tồn tại', value);
  }
  return date;
}

/// Danh sách trường yêu cầu khi kéo giải về; `user_created` là chủ dòng.
const tournamentRemoteFields =
    'id,user_created,name,start_date,end_date,location,game_type,result_note,notes,created_at,updated_at,is_deleted';

/// Các khoá của [tournamentRemoteFields] trừ `user_created` (máy chủ tự gắn chủ).
Map<String, Object?> toRemoteTournament(TournamentRow r) => {
  'id': r.id,
  'name': r.name,
  'start_date': toRemoteDate(r.startDate),
  'end_date': r.endDate == null ? null : toRemoteDate(r.endDate!),
  'location': r.location,
  'game_type': r.gameType,
  'result_note': r.resultNote,
  'notes': r.notes,
  'created_at': r.createdAt.toUtc().toIso8601String(),
  'updated_at': r.updatedAt.toUtc().toIso8601String(),
  'is_deleted': r.isDeleted,
};

String _requiredText(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is! String || v.isEmpty) {
    throw FormatException('Giải thiếu $key', v);
  }
  return v;
}

DateTime _requiredStamp(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is! String) throw FormatException('Giải thiếu $key', v);
  return DateTime.parse(v).toLocal();
}

String? _optionalText(Object? v) => v is String ? v : null;

/// Dòng Drift từ bản ghi máy chủ. Ghi đủ mọi cột (kể cả `Value(null)`) để
/// bản cục bộ cũ bị ghi đè hoàn toàn. Dòng hỏng thì ném [FormatException].
TournamentRowsCompanion tournamentFromRemote(
  Map<String, Object?> j, {
  required String userId,
  required DateTime syncedAt,
}) {
  final id = _requiredText(j, 'id');
  final name = _requiredText(j, 'name');
  final start = fromRemoteDate(j['start_date']);
  final endRaw = j['end_date'];
  final isDeleted = j['is_deleted'];
  if (isDeleted is! bool) {
    throw FormatException('Giải thiếu is_deleted', isDeleted);
  }
  return TournamentRowsCompanion(
    id: Value(id),
    userId: Value(userId),
    name: Value(name),
    startDate: Value(start),
    endDate: Value(endRaw == null ? null : fromRemoteDate(endRaw)),
    location: Value(_optionalText(j['location'])),
    gameType: Value(_optionalText(j['game_type'])),
    resultNote: Value(_optionalText(j['result_note'])),
    notes: Value(_optionalText(j['notes'])),
    createdAt: Value(_requiredStamp(j, 'created_at')),
    updatedAt: Value(_requiredStamp(j, 'updated_at')),
    syncedAt: Value(syncedAt),
    isDeleted: Value(isDeleted),
  );
}
