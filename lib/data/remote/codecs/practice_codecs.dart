import 'dart:convert';

import 'package:poolcoachai/data/database/category_compat.dart';
import 'package:poolcoachai/data/database/match_codec.dart';
import 'package:poolcoachai/data/remote/codecs/remote_values.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

/// Buổi tập có chấm điểm kéo từ server. Giờ đi qua [toLocal].
DrillLog drillLogFromRemote(
  Map<String, Object?> json, {
  ToLocal toLocal = defaultToLocal,
}) {
  return DrillLog(
    id: json['id']! as String,
    drillId: json['drill_id']! as String,
    date: toLocal(DateTime.parse(json['date']! as String).toUtc()),
    score: (json['score']! as num).toDouble(),
    attempts: json['attempts'] as int?,
    notes: json['notes'] as String?,
    durationSec: (json['duration_sec'] as num?)?.toInt(),
  );
}

/// Buổi tập tự do kéo từ server.
TimerSession timerSessionFromRemote(
  Map<String, Object?> item, {
  ToLocal toLocal = defaultToLocal,
}) {
  final id = remoteString(item, 'id');
  final duration = item['duration_sec'];
  final cat = remoteNullableString(item, 'cat');
  if (duration is! int || duration <= 0) {
    throw const FormatException('Thời lượng buổi tập từ server không hợp lệ');
  }
  if (cat != null && !SkillCategory.values.any((c) => c.name == cat)) {
    throw const FormatException('Nhóm kỹ năng từ server không hợp lệ');
  }
  final joinedCat = joinCategoryName(cat, item['cat_ext']);
  final date = toLocal(remoteInstant(item, 'date'));
  final cueId = remoteNullableString(item, 'cue_id');
  return TimerSession(
    id: id,
    date: date,
    durationSec: duration,
    cat: joinedCat == null ? null : SkillCategory.values.byName(joinedCat),
    cueId: cueId,
  );
}

/// Ô lịch tập kéo từ server, kèm `updated_at` (UTC) và cờ xóa.
({ScheduleSlot slot, DateTime updatedAtUtc, bool isDeleted})
scheduleSlotFromRemote(Map<String, Object?> item) {
  final id = remoteString(item, 'id');
  final day = item['day'];
  final time = remoteString(item, 'time');
  final label = remoteString(item, 'label');
  final cat = remoteNullableString(item, 'cat');
  final deleted = item['is_deleted'];
  if (day is! int ||
      day < 0 ||
      day > 6 ||
      !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time) ||
      label.trim().isEmpty ||
      deleted is! bool ||
      (cat != null && !SkillCategory.values.any((c) => c.name == cat))) {
    throw const FormatException('Lịch tập từ server không hợp lệ');
  }
  final remoteUpdatedAt = remoteInstant(item, 'updated_at');
  // Chỉ tin cat_ext khi cat_ext_at == updated_at, tức là chính bản mới
  // ghi lần sửa cuối. Bản cũ sửa dòng (kể cả chỉ đổi tên) gửi cat theo
  // những gì nó thấy, nên dòng đó mang đúng nhóm bản cũ hiển thị.
  final extAt = item['cat_ext_at'];
  final extTrusted =
      extAt is String &&
      DateTime.parse(extAt).toUtc().isAtSameMomentAs(remoteUpdatedAt);
  final joinedCat = joinCategoryName(
    cat,
    extTrusted ? item['cat_ext'] : null,
  );
  return (
    slot: ScheduleSlot(
      id: id,
      day: day,
      time: time,
      label: label,
      cat: joinedCat == null ? null : SkillCategory.values.byName(joinedCat),
    ),
    updatedAtUtc: remoteUpdatedAt,
    isDeleted: deleted,
  );
}

/// Trận đấu đọc từ Directus: giữ nguyên JSON thô của rack và cú đánh để ghi
/// lại đúng cột, cộng với dữ liệu chờ đồng bộ (`updated_at`, `is_deleted`).
final class RemotePoolMatch {
  const RemotePoolMatch({
    required this.id,
    required this.gameType,
    required this.playerName,
    required this.opponentName,
    required this.targetRacks,
    required this.rackWinnersJson,
    required this.shotsJson,
    required this.cueId,
    required this.startedAt,
    required this.completedAt,
    required this.updatedAtUtc,
    required this.isDeleted,
    required this.tournamentId,
    required this.roundLabel,
  });

  final String id;
  final String gameType;
  final String playerName;
  final String opponentName;
  final int targetRacks;
  final String rackWinnersJson;
  final String shotsJson;
  final String? cueId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime updatedAtUtc;
  final bool isDeleted;
  final String? tournamentId;
  final String? roundLabel;
}

RemotePoolMatch poolMatchFromRemote(
  Map<String, Object?> item, {
  ToLocal toLocal = defaultToLocal,
}) {
  final gameType = remoteString(item, 'game_type');
  if (!PoolGameType.values.any((type) => type.name == gameType)) {
    throw const FormatException('Loại trận từ server không hợp lệ');
  }
  final player = remoteString(item, 'player_name');
  final opponent = remoteString(item, 'opponent_name');
  final target = item['target_racks'];
  if (player.trim().isEmpty ||
      opponent.trim().isEmpty ||
      target is! int ||
      target <= 0) {
    throw const FormatException('Trận từ server không hợp lệ');
  }
  final winners = item['rack_winners'];
  final shots = item['shots'];
  if (winners is! List<Object?> || shots is! List<Object?>) {
    throw const FormatException('Kết quả trận từ server không hợp lệ');
  }
  final winnersJson = jsonEncode(winners);
  final shotsJson = jsonEncode(shots);
  // Giải mã thử: hỏng thì ném, không lưu dòng hỏng.
  decodeMatchWinners(winnersJson);
  decodeMatchShots(shotsJson);
  return RemotePoolMatch(
    id: remoteString(item, 'id'),
    gameType: gameType,
    playerName: player,
    opponentName: opponent,
    targetRacks: target,
    rackWinnersJson: winnersJson,
    shotsJson: shotsJson,
    cueId: remoteNullableString(item, 'cue_id'),
    startedAt: toLocal(remoteInstant(item, 'started_at')),
    completedAt: remoteNullableInstant(item, 'completed_at', toLocal: toLocal),
    updatedAtUtc: remoteInstant(item, 'updated_at'),
    isDeleted: item['is_deleted'] == true,
    tournamentId: remoteNullableString(item, 'tournament_id'),
    roundLabel: remoteNullableString(item, 'round_label'),
  );
}
