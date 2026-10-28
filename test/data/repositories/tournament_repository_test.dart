import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

void main() {
  late AppDatabase db;
  late TournamentRepository repo;
  var now = DateTime(2026, 10, 28, 10);
  var n = 0;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 28, 10);
    n = 0;
    repo = TournamentRepository(
      db,
      userId: 'u1',
      now: () => now,
      newId: () => 't${++n}',
    );
  });
  tearDown(() => db.close());

  TournamentDraft d({
    String name = 'Giải Q1',
    DateTime? end,
    String? location,
  }) => TournamentDraft(
    name: name,
    startDate: DateTime(2026, 11, 2, 18),
    endDate: end,
    location: location,
    gameType: PoolGameType.nineBall,
  );

  test('tạo: cắt khoảng trắng, chỉ giữ ngày, chưa đồng bộ', () async {
    expect(await repo.create(d(name: '  Giải Q1  ', location: '   ')), 't1');
    final r = await db.select(db.tournamentRows).getSingle();
    expect(
      [
        r.userId,
        r.name,
        r.startDate,
        r.location,
        r.gameType,
        r.createdAt,
        r.updatedAt,
        r.syncedAt,
        r.isDeleted,
      ],
      [
        'u1',
        'Giải Q1',
        DateTime(2026, 11, 2),
        null,
        'nineBall',
        DateTime(2026, 10, 28, 10),
        DateTime(2026, 10, 28, 10),
        null,
        false,
      ],
    );
  });

  test('dữ liệu sai thì ném, không ghi', () async {
    await expectLater(repo.create(d(name: ' ')), throwsArgumentError);
    await expectLater(
      repo.create(d(end: DateTime(2026, 11, 1))),
      throwsArgumentError,
    );
    expect(await db.select(db.tournamentRows).get(), isEmpty);
  });

  test(
    'sửa: xoá được ngày kết thúc và địa điểm, đổi updatedAt, chờ đồng bộ lại',
    () async {
      await repo.create(d(end: DateTime(2026, 11, 3), location: 'CLB A'));
      await (db.update(db.tournamentRows)).write(
        TournamentRowsCompanion(syncedAt: Value(DateTime(2026, 10, 28, 10))),
      );
      now = DateTime(2026, 10, 28, 11);
      await repo.update('t1', d());
      final r = await db.select(db.tournamentRows).getSingle();
      expect(
        [r.endDate, r.location, r.updatedAt, r.syncedAt],
        [null, null, DateTime(2026, 10, 28, 11), null],
      );
    },
  );

  test('sửa dữ liệu sai thì ném, giữ nguyên dòng', () async {
    await repo.create(d());
    await expectLater(repo.update('t1', d(name: '')), throwsArgumentError);
    expect((await db.select(db.tournamentRows).getSingle()).name, 'Giải Q1');
  });

  test('xóa mềm: ẩn khỏi danh sách, trận của giải giữ tournament_id', () async {
    await repo.create(d());
    await db
        .into(db.poolMatchRows)
        .insert(
          PoolMatchRowsCompanion.insert(
            id: 'm1',
            userId: 'u1',
            gameType: 'nineBall',
            playerName: 'An',
            opponentName: 'Bình',
            targetRacks: 3,
            rackWinners: '[]',
            startedAt: DateTime(2026, 11, 2),
            tournamentId: const Value('t1'),
          ),
        );
    await repo.remove('t1');
    final r = await db.select(db.tournamentRows).getSingle();
    expect([r.isDeleted, r.syncedAt], [true, null]);
    expect(await repo.watchAll().first, isEmpty);
    expect((await db.select(db.poolMatchRows).getSingle()).tournamentId, 't1');
    await expectLater(repo.remove('t1'), throwsStateError);
  });

  test('chỉ thấy và sửa được giải của mình, mới nhất trước', () async {
    await repo.create(d());
    await repo.create(
      TournamentDraft(name: 'Giải sau', startDate: DateTime(2026, 12, 1)),
    );
    final other = TournamentRepository(
      db,
      userId: 'u2',
      now: () => now,
      newId: () => 'x',
    );
    await other.create(d());
    expect((await repo.watchAll().first).map((t) => t.id), ['t2', 't1']);
    await expectLater(other.update('t1', d()), throwsStateError);
    await expectLater(other.remove('t1'), throwsStateError);
  });
}
