import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/tournament_converters.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

void main() {
  final row = TournamentRow(
    id: 't1',
    userId: 'u1',
    name: 'Giải Q1',
    startDate: DateTime(2026, 11, 2),
    endDate: DateTime(2026, 11, 3),
    location: 'CLB A',
    gameType: 'tenBall',
    resultNote: 'Vào vòng 16',
    notes: 'n',
    createdAt: DateTime(2026, 10, 28, 9),
    updatedAt: DateTime(2026, 10, 28, 10),
    syncedAt: null,
    isDeleted: false,
  );

  test(
    'dòng Drift ra miền',
    () => expect(
      toTournament(row),
      Tournament(
        id: 't1',
        name: 'Giải Q1',
        startDate: DateTime(2026, 11, 2),
        endDate: DateTime(2026, 11, 3),
        location: 'CLB A',
        gameType: PoolGameType.tenBall,
        resultNote: 'Vào vòng 16',
        notes: 'n',
      ),
    ),
  );

  test(
    'loại bi lạ (máy mới hơn) coi là không có',
    () => expect(
      toTournament(row.copyWith(gameType: const Value('straight'))).gameType,
      isNull,
    ),
  );

  test('ngày chỉ gồm ngày: YYYY-MM-DD đi và về đúng ngày, kể cả khi máy chủ trả kèm giờ', () {
    expect(
      [
        toRemoteDate(DateTime(2026, 1, 5, 23, 30)),
        fromRemoteDate('2026-11-02'),
        fromRemoteDate('2026-11-02T00:00:00'),
      ],
      ['2026-01-05', DateTime(2026, 11, 2), DateTime(2026, 11, 2)],
    );
    expect(() => fromRemoteDate('02/11/2026'), throwsFormatException);
    expect(() => fromRemoteDate(null), throwsFormatException);
    for (final bad in ['2026-13-40', '2026-02-30', '2026-00-10', '2026-04-31']) {
      expect(() => fromRemoteDate(bad), throwsFormatException, reason: bad);
    }
    expect(fromRemoteDate('2028-02-29'), DateTime(2028, 2, 29));
  });

  test('gửi đúng các khoá của danh sách trường, không gửi chủ', () {
    final remote = toRemoteTournament(row);
    expect(
      remote.keys.toSet(),
      tournamentRemoteFields.split(',').toSet()..remove('user_created'),
    );
    expect(
      [
        remote['start_date'],
        remote['end_date'],
        remote['game_type'],
        remote['is_deleted'],
      ],
      ['2026-11-02', '2026-11-03', 'tenBall', false],
    );
    expect(
      remote['updated_at'],
      DateTime(2026, 10, 28, 10).toUtc().toIso8601String(),
    );
  });

  test('đi Directus rồi về nguyên vẹn', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.tournamentRows)
        .insert(
          tournamentFromRemote(
            {...toRemoteTournament(row), 'user_created': 'u1'},
            userId: 'u1',
            syncedAt: DateTime(2026, 10, 28, 11),
          ),
        );
    final back = await db.select(db.tournamentRows).getSingle();
    expect(toTournament(back), toTournament(row));
    expect(
      [back.updatedAt, back.syncedAt, back.isDeleted],
      [DateTime(2026, 10, 28, 10), DateTime(2026, 10, 28, 11), false],
    );
  });

  test('dòng hỏng từ máy chủ thì ném', () {
    final ok = toRemoteTournament(row);
    for (final bad in [
      {...ok, 'name': ''},
      {...ok, 'start_date': null},
      {...ok, 'is_deleted': null},
      {...ok, 'id': null},
      {...ok, 'id': ''},
      {...ok, 'end_date': 'khong-phai-ngay'},
      {...ok, 'end_date': '2026-13-40'},
    ]) {
      expect(
        () => tournamentFromRemote(
          bad,
          userId: 'u1',
          syncedAt: DateTime(2026, 10, 28),
        ),
        throwsFormatException,
      );
    }
  });
}
