import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/assessment_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late List<(String, RankFetch)> fetches;
  final now = DateTime(2026, 10, 14, 10);
  final older = DateTime(2026, 10, 1, 9);
  final newer = DateTime(2026, 10, 9, 9);

  AssessmentSyncService build() {
    final s = AssessmentSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => now,
      onRankFetch: (u, f) => fetches.add((u, f)),
    );
    addTearDown(s.dispose);
    return s;
  }

  void serve({
    List<Map<String, Object?>> ranks = const [],
    List<Map<String, Object?>> tests = const [],
    List<Map<String, Object?>> results = const [],
  }) {
    server.routes['GET /items/player_ranks'] = (_) => FakeDirectus.ok(ranks);
    server.routes['POST /items/player_ranks'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['PATCH /items/player_ranks/u1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['GET /items/bu_tests'] = (_) => FakeDirectus.ok(tests);
    server.routes['GET /items/bu_drill_results'] = (_) => FakeDirectus.ok(results);
    server.routes['POST /items/bu_tests'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['POST /items/bu_drill_results'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  }

  Map<String, Object?> remoteRank(Rank? rank, RankSource? source, DateTime at) => {
        'id': 'u1',
        'rank': rank?.name,
        'source': source?.name,
        'bu_score': source == RankSource.verified ? 130 : null,
        'test_id': source == RankSource.verified ? 'tv' : null,
        'warning_rank': null,
        'warning_test_id': null,
        'questionnaire_answers': [0, 0, 0, 0, 2, 4, 0, 0],
        'onboarding_state': rank == null ? 'skipped' : 'done',
        'updated_at': at.toUtc().toIso8601String(),
      };

  Future<void> localRank(Rank? rank, RankSource? source, DateTime at, {DateTime? syncedAt}) =>
      db.into(db.playerRankRows).insertOnConflictUpdate(toPlayerRankRow(
            PlayerRank(
              rank: rank,
              source: source,
              buScore: source == RankSource.verified ? 100 : null,
              testId: source == RankSource.verified ? 'tl' : null,
              onboardingState: rank == null ? OnboardingState.skipped : OnboardingState.done,
              updatedAt: at,
            ),
            userId: 'u1',
            syncedAt: syncedAt,
          ));

  Future<PlayerRankRow> rankRow() => db.select(db.playerRankRows).getSingle();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
    auth = FakeAuthRepository.signedIn();
    fetches = [];
  });
  tearDown(() => db.close());

  test('chưa có hạng ở đâu: báo máy chủ chưa có, không gửi gì', () async {
    serve();
    expect(await build().syncNow(), SyncOutcome.done);
    expect(fetches, [('u1', RankFetch.foundNone)]);
    expect(server.sent('POST', '/items/player_ranks'), isEmpty);
    expect(await db.select(db.playerRankRows).get(), isEmpty);
  });

  test('máy có hạng chưa đồng bộ, máy chủ chưa có: POST rồi đánh dấu', () async {
    serve();
    await localRank(Rank.h, RankSource.estimated, older);
    await build().syncNow();
    final body = FakeDirectus.body(server.sent('POST', '/items/player_ranks').single);
    expect(body['id'], 'u1');
    expect(body['rank'], 'h');
    expect(body.containsKey('user_created'), isFalse);
    expect((await rankRow()).syncedAt, now);
  });

  test('máy chủ có hạng đã kiểm chứng, máy này tự khai mới hơn: máy chủ thắng, không gửi PATCH',
      () async {
    serve(ranks: [remoteRank(Rank.e, RankSource.verified, older)]);
    await localRank(Rank.pro, RankSource.selfDeclared, newer);
    await build().syncNow();
    expect(fetches, [('u1', RankFetch.found)]);
    expect(server.sent('PATCH', '/items/player_ranks/u1'), isEmpty);
    final row = await rankRow();
    expect(row.rank, 'e');
    expect(row.source, 'verified');
    expect(row.syncedAt, now);
  });

  test('máy này đã kiểm chứng, máy chủ ước lượng mới hơn: gửi PATCH, máy giữ nguyên', () async {
    serve(ranks: [remoteRank(Rank.c, RankSource.estimated, newer)]);
    await localRank(Rank.f, RankSource.verified, older);
    await build().syncNow();
    final body = FakeDirectus.body(server.sent('PATCH', '/items/player_ranks/u1').single);
    expect(body['rank'], 'f');
    expect(body.containsKey('id'), isFalse, reason: 'không sửa khoá chính');
    expect((await rankRow()).rank, 'f');
    expect((await rankRow()).syncedAt, now);
  });

  test('Để sau trên máy mới (mất mạng lúc đó) không xoá hạng của máy chủ', () async {
    serve(ranks: [remoteRank(Rank.h, RankSource.estimated, older)]);
    await localRank(null, null, newer);
    await build().syncNow();
    expect(server.sent('PATCH', '/items/player_ranks/u1'), isEmpty);
    expect((await rankRow()).rank, 'h');
  });

  test('chỉ đẩy lần đã xong cùng kết quả; lần đang dở nằm yên', () async {
    serve();
    for (final (id, done) in [('xong', true), ('do', false)]) {
      await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
            id: id,
            userId: 'u1',
            startedAt: older,
            tableSize: 'nineFootPlus',
            completedAt: Value(done ? newer : null),
            totalScore: Value(done ? 137 : null),
            resultRank: Value(done ? 'd' : null),
          ));
      await db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
            id: 'r-$id',
            testId: id,
            drillId: 'F1',
            attempts: '{"shots":[true,true,true,true,true,true,true,true]}',
            score: const Value(10),
            recordedAt: older,
          ));
    }
    await build().syncNow();

    final tests = server.sent('POST', '/items/bu_tests').map(FakeDirectus.body).toList();
    expect(tests.map((b) => b['id']), ['xong']);
    final results = server.sent('POST', '/items/bu_drill_results').map(FakeDirectus.body).toList();
    expect(results.map((b) => b['id']), ['r-xong']);
    expect(results.single['attempts'], isA<Map<String, Object?>>(),
        reason: 'gửi JSON thật, không gửi chuỗi');
    final rows = await db.select(db.buTestRows).get();
    expect(rows.firstWhere((r) => r.id == 'xong').syncedAt, now);
    expect(rows.firstWhere((r) => r.id == 'do').syncedAt, isNull);
  });

  test('kéo lần kiểm tra và kết quả từ máy chủ về', () async {
    serve(tests: [
      {
        'id': 't9', 'started_at': older.toUtc().toIso8601String(),
        'completed_at': newer.toUtc().toIso8601String(), 'cancelled_at': null,
        'table_size': 'eightFoot', 'exam_i_score': 100, 'exam_ii_version': 'masters',
        'exam_ii_score': 77, 'total_score': 177, 'result_rank': 'a',
      },
    ], results: [
      {
        'id': 'r9', 'test_id': 't9', 'drill_id': 'S10',
        'attempts': {'breaks': [[true, true, true, true, true]]}, 'score': null,
        'recorded_at': newer.toUtc().toIso8601String(),
      },
    ]);
    await build().syncNow();
    final t = await db.select(db.buTestRows).getSingle();
    expect(t.userId, 'u1');
    expect(t.totalScore, 177);
    expect(t.syncedAt, now);
    final r = await db.select(db.buDrillResultRows).getSingle();
    expect(jsonDecode(r.attempts), {'breaks': [[true, true, true, true, true]]});
  });

  test('mất mạng thì báo RankFetch.failed', () async {
    serve();
    server.offline = true;
    expect(await build().syncNow(), SyncOutcome.offline);
    expect(fetches, [('u1', RankFetch.failed)]);
  });

  test('chưa đăng nhập thì không gọi máy chủ, không báo gì', () async {
    serve();
    auth = FakeAuthRepository();
    expect(await build().syncNow(), SyncOutcome.signedOut);
    expect(server.requests, isEmpty);
    expect(fetches, isEmpty);
  });

  test('có lần mới hoàn tất trên máy thì tự đồng bộ', () async {
    serve();
    build().start();
    await pumpEventQueue();
    server.requests.clear();
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 'moi', userId: 'u1', startedAt: older, tableSize: 'nineFootPlus',
          cancelledAt: Value(newer)));
    await pumpEventQueue(times: 50);
    expect(server.sent('POST', '/items/bu_tests'), hasLength(1));
  });

  test('hai máy cùng kiểm chứng khác hạng: hạng cao hơn giữ, lần thấp hơn mới hơn thành cảnh báo (D4)',
      () async {
    // Máy chủ: B đã kiểm chứng lúc older (lần 'tv'). Máy này, mất mạng, vừa
    // kiểm chứng D lúc newer (lần 'tl').
    serve(ranks: [remoteRank(Rank.b, RankSource.verified, older)]);
    await localRank(Rank.d, RankSource.verified, newer);
    await build().syncNow();

    final row = await rankRow();
    expect(row.rank, 'b', reason: 'app không tự hạ hạng (Q5)');
    expect(row.testId, 'tv');
    expect(row.warningRank, 'd');
    expect(row.warningTestId, 'tl');
    expect(row.syncedAt, now);
    final body = FakeDirectus.body(server.sent('PATCH', '/items/player_ranks/u1').single);
    expect(body['rank'], 'b');
    expect(body['warning_rank'], 'd');
    expect(body['warning_test_id'], 'tl');
  });

  test('máy này kiểm chứng cao hơn, máy chủ thấp hơn mới hơn: máy giữ hạng, nhận cảnh báo (D4)',
      () async {
    serve(ranks: [remoteRank(Rank.d, RankSource.verified, newer)]);
    await localRank(Rank.b, RankSource.verified, older, syncedAt: older);
    await build().syncNow();

    final row = await rankRow();
    expect(row.rank, 'b');
    expect(row.testId, 'tl');
    expect(row.warningRank, 'd');
    expect(row.warningTestId, 'tv');
    final body = FakeDirectus.body(server.sent('PATCH', '/items/player_ranks/u1').single);
    expect(body['rank'], 'b');
    expect(body['warning_test_id'], 'tv');
  });

  test('máy chủ đã có lần kiểm tra và kết quả (RECORD_NOT_UNIQUE): coi như đã đồng bộ', () async {
    // Directus thật trả 400 RECORD_NOT_UNIQUE khi gửi lại cùng id (verify.mjs, 14/10/2026).
    serve();
    server.routes['POST /items/bu_tests'] = (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
    server.routes['POST /items/bu_drill_results'] =
        (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 'xong', userId: 'u1', startedAt: older, tableSize: 'nineFootPlus',
          completedAt: Value(newer), totalScore: const Value(137), resultRank: const Value('d')));
    await db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
          id: 'r-xong', testId: 'xong', drillId: 'F1', attempts: '{"shots":[]}', recordedAt: older));

    expect(await build().syncNow(), SyncOutcome.done);
    expect((await db.select(db.buTestRows).getSingle()).syncedAt, now);
    expect((await db.select(db.buDrillResultRows).getSingle()).syncedAt, now);
  });
}
