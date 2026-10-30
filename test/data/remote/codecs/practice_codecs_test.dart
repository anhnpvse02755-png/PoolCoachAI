import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/match_codec.dart';
import 'package:poolcoachai/data/remote/codecs/practice_codecs.dart';
import 'package:poolcoachai/data/remote/codecs/remote_values.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';

DateTime plus7(DateTime utc) => utc.add(const Duration(hours: 7));

Map<String, Object?> timer([Map<String, Object?> over = const {}]) => {
  'id': 't1',
  'date': '2026-10-13T01:02:03.987Z',
  'duration_sec': 600,
  'cat': 'aiming',
  'cat_ext': null,
  'cue_id': 'c1',
  ...over,
};

Map<String, Object?> slot([Map<String, Object?> over = const {}]) => {
  'id': 's1',
  'day': 2,
  'time': '07:30',
  'label': 'Tập đường cơ',
  'cat': null,
  'cat_ext': 'kick',
  'cat_ext_at': '2026-10-12T00:00:00.000Z',
  'updated_at': '2026-10-12T00:00:00.000Z',
  'is_deleted': false,
  ...over,
};

Map<String, Object?> match([Map<String, Object?> over = const {}]) => {
  'id': 'm1',
  'game_type': 'nineBall',
  'player_name': 'An',
  'opponent_name': 'Bình',
  'target_racks': 5,
  'rack_winners': ['player', 'opponent'],
  'shots': [
    {
      'id': 'x1',
      'rackNumber': 1,
      'shotNumber': 1,
      'shooter': 'player',
      'type': 'breakShot',
      'outcome': 'made',
      'positionOutcome': null,
      'notes': null,
      'recordedAt': '2026-10-13T01:02:03.000',
    },
  ],
  'cue_id': null,
  'started_at': '2026-10-13T01:02:03.987Z',
  'completed_at': '2026-10-13T02:00:00.000Z',
  'updated_at': '2026-10-13T03:00:00.000Z',
  'is_deleted': false,
  'tournament_id': null,
  'round_label': null,
  ...over,
};

void main() {
  test('buổi tập: đọc đúng trường, giờ qua toLocal được tiêm', () {
    final log = drillLogFromRemote({
      'id': 'd1',
      'drill_id': 'dr',
      'date': '2026-10-13T01:02:03.987Z',
      'score': 7,
      'attempts': 10,
      'notes': 'ok',
      'duration_sec': 120,
    }, toLocal: plus7);
    expect(log.date, DateTime.utc(2026, 10, 13, 8, 2, 3, 987));
    expect(log.score, 7.0);
    expect(log.attempts, 10);
    expect(log.notes, 'ok');
    expect(log.durationSec, 120);
    expect(
      drillLogFromRemote({
        'id': 'd1',
        'drill_id': 'dr',
        'date': '2026-10-13T01:02:03.000Z',
        'score': 7.5,
      }).durationSec,
      isNull,
    );
  });

  test('wholeSeconds: bỏ phần lẻ giây như Drift', () {
    expect(
      wholeSeconds(DateTime.utc(2026, 10, 13, 1, 2, 3, 987, 456)),
      DateTime.utc(2026, 10, 13, 1, 2, 3),
    );
    expect(wholeSeconds(DateTime.utc(2026, 10, 13, 1, 2, 3)).isUtc, isTrue);
  });

  test('buổi tập tự do: nhóm _ext lạ bị bỏ, cat lạ hay thời lượng ≤ 0 ném FormatException', () {
    final s = timerSessionFromRemote(timer(), toLocal: plus7);
    expect(s.id, 't1');
    expect(s.date, DateTime.utc(2026, 10, 13, 8, 2, 3, 987));
    expect(s.durationSec, 600);
    expect(s.cat, SkillCategory.aiming);
    expect(s.cueId, 'c1');
    expect(
      timerSessionFromRemote(
        timer({'cat': null, 'cat_ext': 'nhom_cua_ban_sau'}),
      ).cat,
      isNull,
    );
    expect(
      () => timerSessionFromRemote(timer({'cat': 'la'})),
      throwsFormatException,
    );
    expect(
      () => timerSessionFromRemote(timer({'duration_sec': 0})),
      throwsFormatException,
    );
  });

  test('lịch tập: cat_ext chỉ tin khi cat_ext_at bằng updated_at; giờ sai dạng ném', () {
    final trusted = scheduleSlotFromRemote(slot());
    expect(trusted.slot.cat, SkillCategory.kick);
    expect(trusted.updatedAtUtc, DateTime.utc(2026, 10, 12));
    expect(trusted.isDeleted, isFalse);
    final stale = scheduleSlotFromRemote(
      slot({'cat_ext_at': '2026-10-11T00:00:00.000Z'}),
    );
    expect(stale.slot.cat, isNull);
    expect(
      () => scheduleSlotFromRemote(slot({'time': '7:30'})),
      throwsFormatException,
    );
  });

  test('trận: giữ nguyên JSON thô của rack và cú đánh; JSON hỏng ném; poolMatchFromColumns đọc lại đúng', () {
    final m = poolMatchFromRemote(match(), toLocal: plus7);
    expect(m.rackWinnersJson, jsonEncode(['player', 'opponent']));
    expect(m.shotsJson, jsonEncode(match()['shots']));
    expect(m.startedAt, DateTime.utc(2026, 10, 13, 8, 2, 3, 987));
    expect(m.completedAt, DateTime.utc(2026, 10, 13, 9));
    expect(m.updatedAtUtc, DateTime.utc(2026, 10, 13, 3));
    expect(m.isDeleted, isFalse);
    expect(
      () => poolMatchFromRemote(match({'rack_winners': ['ai_do']})),
      throwsFormatException,
    );
    expect(
      () => poolMatchFromRemote(match({'shots': 'x'})),
      throwsFormatException,
    );
    final domain = poolMatchFromColumns(
      id: m.id,
      gameType: m.gameType,
      playerName: m.playerName,
      opponentName: m.opponentName,
      targetRacks: m.targetRacks,
      rackWinnersJson: m.rackWinnersJson,
      shotsJson: m.shotsJson,
      startedAt: m.startedAt,
      completedAt: m.completedAt,
      cueId: m.cueId,
      tournamentId: m.tournamentId,
      roundLabel: m.roundLabel,
    );
    expect(domain.gameType, PoolGameType.nineBall);
    expect(domain.rackWinners, [RackWinner.player, RackWinner.opponent]);
    expect(domain.shots.single.id, 'x1');
  });
}
