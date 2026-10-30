import 'dart:convert';

import 'package:poolcoachai/domain/pool_match.dart';

/// Mã hóa/giải mã cột JSON của trận đấu. Dùng chung cho kho lưu trữ và đồng
/// bộ để hai nơi đọc cùng một định dạng. Hỏng thì ném, không trả rỗng.

String encodeMatchWinners(List<RackWinner> winners) =>
    jsonEncode(winners.map((winner) => winner.name).toList());

String encodeMatchShots(List<MatchShot> shots) => jsonEncode([
  for (final shot in shots)
    {
      'id': shot.id,
      'rackNumber': shot.rackNumber,
      'shotNumber': shot.shotNumber,
      'shooter': shot.shooter.name,
      'type': shot.type.name,
      'outcome': shot.outcome.name,
      'positionOutcome': shot.positionOutcome?.name,
      'notes': shot.notes,
      'recordedAt': shot.recordedAt.toIso8601String(),
    },
]);

List<MatchShot> decodeMatchShots(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw FormatException('Danh sách cú đánh không hợp lệ', json);
  }
  return decoded
      .map((value) {
        if (value is! Map<String, dynamic>) {
          throw FormatException('Thông tin cú đánh không hợp lệ', json);
        }
        final shooterName = value['shooter'];
        final typeName = value['type'];
        final outcomeName = value['outcome'];
        final positionName = value['positionOutcome'];
        final id = value['id'];
        final notes = value['notes'];
        final rackNumber = value['rackNumber'];
        final shotNumber = value['shotNumber'];
        final recordedAt = value['recordedAt'];
        if (id is! String ||
            rackNumber is! int ||
            shotNumber is! int ||
            shooterName is! String ||
            typeName is! String ||
            outcomeName is! String ||
            (positionName != null && positionName is! String) ||
            (notes != null && notes is! String) ||
            recordedAt is! String) {
          throw FormatException(
            'Thông tin cú đánh thiếu trường bắt buộc',
            json,
          );
        }
        return MatchShot(
          id: id,
          rackNumber: rackNumber,
          shotNumber: shotNumber,
          shooter: RackWinner.values.firstWhere(
            (winner) => winner.name == shooterName,
            orElse: () =>
                throw FormatException('Unknown RackWinner: $shooterName'),
          ),
          type: MatchShotType.values.firstWhere(
            (type) => type.name == typeName,
            orElse: () =>
                throw FormatException('Unknown MatchShotType: $typeName'),
          ),
          outcome: MatchShotOutcome.values.firstWhere(
            (outcome) => outcome.name == outcomeName,
            orElse: () => throw FormatException(
              'Unknown MatchShotOutcome: $outcomeName',
            ),
          ),
          positionOutcome: positionName == null
              ? null
              : PositionOutcome.values.firstWhere(
                  (position) => position.name == positionName,
                  orElse: () => throw FormatException(
                    'Unknown PositionOutcome: $positionName',
                  ),
                ),
          notes: notes as String?,
          recordedAt: DateTime.parse(recordedAt),
        );
      })
      .toList(growable: true);
}

/// Dựng [PoolMatch] từ các cột của một dòng trận. Kho lưu trữ và helper máy
/// chủ cùng gọi hàm này nên hai nơi đọc một dòng giống hệt nhau.
PoolMatch poolMatchFromColumns({
  required String id,
  required String gameType,
  required String playerName,
  required String opponentName,
  required int targetRacks,
  required String rackWinnersJson,
  required String shotsJson,
  required DateTime startedAt,
  DateTime? completedAt,
  String? cueId,
  String? tournamentId,
  String? roundLabel,
}) => PoolMatch(
  id: id,
  gameType: PoolGameType.values.firstWhere(
    (type) => type.name == gameType,
    orElse: () => throw FormatException('Unknown PoolGameType: $gameType'),
  ),
  playerName: playerName,
  opponentName: opponentName,
  targetRacks: targetRacks,
  rackWinners: decodeMatchWinners(rackWinnersJson),
  startedAt: startedAt,
  shots: decodeMatchShots(shotsJson),
  completedAt: completedAt,
  cueId: cueId,
  tournamentId: tournamentId,
  roundLabel: roundLabel,
);

List<RackWinner> decodeMatchWinners(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List || decoded.any((winner) => winner is! String)) {
    throw FormatException('Danh sách người thắng rack không hợp lệ', json);
  }
  return decoded
      .cast<String>()
      .map(
        (name) => RackWinner.values.firstWhere(
          (winner) => winner.name == name,
          orElse: () => throw FormatException('Unknown RackWinner: $name'),
        ),
      )
      .toList(growable: true);
}
