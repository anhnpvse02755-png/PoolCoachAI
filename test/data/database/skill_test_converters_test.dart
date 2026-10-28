import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/skill_test_converters.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

void main() {
  final t = SkillTest(
    id: 'st',
    drillId: 'a1',
    drillLevel: 1,
    tableSize: TableSize.eightFoot,
    startedAt: DateTime(2026, 10, 28, 9, 40),
    completedAt: DateTime(2026, 10, 28, 10),
    score: 9,
    attempts: 10,
    passed: true,
    notes: 'n',
    passThreshold: 0.8,
  );
  final sync = DateTime(2026, 10, 28, 11);

  SkillTest? back(Map<String, Object?> remote) {
    final r = skillTestFromRemote(remote, userId: 'u1', syncedAt: sync);
    return r == null ? null : toSkillTest(r);
  }

  test('qua dòng Drift, Directus rồi về nguyên vẹn; không gửi chủ', () {
    final row = toSkillTestRow(t, userId: 'u1');
    expect(toSkillTest(row), t);
    final remote = toRemoteSkillTest(row);
    expect(remote.containsKey('user_created'), isFalse);
    expect(remote.containsKey('user_id'), isFalse);
    expect(
      remote['completed_at'],
      DateTime(2026, 10, 28, 10).toUtc().toIso8601String(),
    );
    final r = skillTestFromRemote(remote, userId: 'u1', syncedAt: sync)!;
    expect([toSkillTest(r), r.userId, r.syncedAt], [t, 'u1', sync]);
  });

  test('điểm số nguyên từ máy chủ đọc thành số thực; bài mục tiêu giữ số lẻ và ảnh chụp mục tiêu', () {
    final remote = toRemoteSkillTest(toSkillTestRow(t, userId: 'u1'))
      ..['score'] = 9;
    expect(
      skillTestFromRemote(remote, userId: 'u1', syncedAt: sync)!.score,
      9.0,
    );
    final target = SkillTest(
      id: 'tg',
      drillId: 't2',
      drillLevel: 2,
      tableSize: TableSize.sevenFoot,
      startedAt: DateTime(2026, 10, 28, 9),
      completedAt: DateTime(2026, 10, 28, 9, 30),
      score: 22.5,
      passed: false,
      target: 25,
    );
    final row = toSkillTestRow(target, userId: 'u1');
    expect([row.target, row.passThreshold], [25.0, null]);
    expect(back(toRemoteSkillTest(row)), target);
    final remote2 = toRemoteSkillTest(row)..['target'] = 25;
    expect(back(remote2), target);
  });

  test('lần huỷ đi hết vòng, không có kết quả', () {
    final c = SkillTest(
      id: 'c',
      drillId: 'a1',
      drillLevel: 1,
      tableSize: TableSize.nineFootPlus,
      startedAt: DateTime(2026, 10, 28, 9),
      cancelledAt: DateTime(2026, 10, 28, 9, 5),
    );
    expect(back(toRemoteSkillTest(toSkillTestRow(c, userId: 'u1'))), c);
  });

  test('table_size lạ: dòng Drift và dòng máy chủ bị bỏ (null), không ném', () {
    final row = toSkillTestRow(t, userId: 'u1');
    final odd = SkillTestRow(
      id: 'odd',
      userId: 'u1',
      drillId: 'a1',
      drillLevel: 1,
      tableSize: 'zzz',
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      score: 9,
      attempts: 10,
      passed: true,
      passThreshold: 0.8,
    );
    expect(toSkillTest(odd), isNull);
    final remote = toRemoteSkillTest(row)..['table_size'] = 'zzz';
    expect(skillTestFromRemote(remote, userId: 'u1', syncedAt: sync), isNull);
  });

  test('trường hỏng: kiểu sai, thiếu, hay cả hai tiêu chí đều cho null, dòng khác vẫn qua', () {
    final good = toRemoteSkillTest(toSkillTestRow(t, userId: 'u1'));
    final bad = <Map<String, Object?>>[
      {...good, 'started_at': 'không phải ngày'},
      {...good, 'started_at': null},
      {...good, 'id': null},
      {...good, 'drill_level': 'một'},
      {...good, 'score': 'chín'},
      {...good, 'attempts': 'mười'},
      {...good, 'passed': 'có'},
      {...good, 'target': 25}, // cả hai tiêu chí
      {...good, 'pass_threshold': null}, // hoàn tất có điểm mà thiếu ảnh chụp
    ];
    for (final j in bad) {
      expect(
        skillTestFromRemote(j, userId: 'u1', syncedAt: sync),
        isNull,
        reason: '$j',
      );
    }
    final mixed = [...bad, good]
        .map((j) => skillTestFromRemote(j, userId: 'u1', syncedAt: sync))
        .whereType<SkillTestRow>();
    expect(mixed.map((r) => r.id), ['st']);
  });

  test('dòng hoàn tất thiếu passed vẫn đọc được, passed là null', () {
    final j = toRemoteSkillTest(toSkillTestRow(t, userId: 'u1'))
      ..['passed'] = null;
    final r = back(j)!;
    expect([r.passed, r.certifies, r.failed], [null, false, false]);
  });
}
