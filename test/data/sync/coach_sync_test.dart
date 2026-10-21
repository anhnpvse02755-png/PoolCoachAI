import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/coach_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/coach_attempt_repository.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/data/sync/coach_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

final _at = DateTime(2026, 10, 21, 9);

CoachAttempt sample(String id, {String userId = 'u1', DateTime? finishedAt}) => CoachAttempt(
      id: id,
      userId: userId,
      situationKey: 'gen-v1-position-easy-42',
      topic: CoachTopic.position,
      difficulty: CoachDifficulty.easy,
      answers: const [
        CoachAnswerRecord(
          kind: CoachAnswerKind.pot,
          pocket: Pocket.bottomMiddle,
          stroke: Stroke.draw,
          power: 30,
          outcome: CoachOutcome.wrong,
          fault: CoachFault.strokeWorse,
        ),
        CoachAnswerRecord(
          kind: CoachAnswerKind.pot,
          pocket: Pocket.bottomMiddle,
          stroke: Stroke.stun,
          power: 45,
          spinSide: SpinSide.left,
          spinTips: 0.5,
          outcome: CoachOutcome.wrong,
          fault: CoachFault.spinUnneeded,
        ),
        CoachAnswerRecord(kind: CoachAnswerKind.safety, outcome: CoachOutcome.undecided),
      ],
      outcome: CoachAttemptOutcome.revealed,
      firstFault: CoachFault.strokeWorse,
      scoringVersion: 1,
      startedAt: _at,
      finishedAt: finishedAt ?? _at.add(const Duration(minutes: 2)),
    );

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  final now = DateTime(2026, 10, 21, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
  });
  tearDown(() => db.close());

  CoachSyncService build() {
    final s = CoachSyncService(
      db: db,
      auth: FakeAuthRepository.signedIn(),
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => now,
    );
    addTearDown(s.dispose);
    return s;
  }

  void serve({List<Map<String, Object?>> attempts = const []}) {
    server.routes['GET /items/coach_attempts'] = (_) => FakeDirectus.ok(attempts);
    server.routes['POST /items/coach_attempts'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  }

  group('bộ mã hoá', () {
    test('câu trả lời chạy hai chiều; khoá null không ghi', () {
      final a = sample('x');
      expect(decodeCoachAnswers(encodeCoachAnswers(a.answers)), a.answers);
      final safety = coachAnswerToJson(a.answers.last);
      expect(safety.keys, ['kind', 'outcome']);
    });

    test('lần làm chạy hai chiều qua dòng Drift và qua JSON máy chủ', () {
      final a = sample('x');
      final row = toCoachAttemptRow(a);
      final back = toCoachAttempt(row);
      expect(back.answers, a.answers);
      expect(back.outcome, a.outcome);
      expect(back.firstFault, a.firstFault);
      expect(back.topic, a.topic);
      final remote = toRemoteCoachAttempt(row);
      expect(remote['answers'], isA<List<Object?>>());
      final pulled = coachAttemptFromRemote(jsonDecode(jsonEncode(remote)) as Map<String, Object?>,
          userId: 'u1', syncedAt: now);
      expect(toCoachAttempt(pulled).answers, a.answers);
      expect(pulled.finishedAt, row.finishedAt);
      expect(pulled.syncedAt, now);
    });
  });

  test('repository: chỉ thêm, chỉ của người này, mới nhất trước', () async {
    final repo = CoachAttemptRepository(db, userId: 'u1');
    await repo.record(sample('a', finishedAt: _at));
    await repo.record(sample('b', finishedAt: _at.add(const Duration(hours: 1))));
    await repo.record(sample('a', finishedAt: _at.add(const Duration(days: 1)))); // trùng id: bỏ qua
    await CoachAttemptRepository(db, userId: 'u2').record(sample('c', userId: 'u2'));
    final list = await repo.watchAttempts().first;
    expect(list.map((a) => a.id), ['b', 'a']);
    expect(await pendingCoachCount(db, 'u1'), 2);
  });

  test('đẩy dòng chờ lên; trùng trên máy chủ vẫn coi là đã đồng bộ', () async {
    serve();
    var first = true;
    server.routes['POST /items/coach_attempts'] = (req) {
      if (first) {
        first = false;
        return FakeDirectus.ok(jsonDecode(req.body));
      }
      return FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
    };
    final repo = CoachAttemptRepository(db, userId: 'u1');
    await repo.record(sample('a'));
    await repo.record(sample('b'));
    expect(await build().syncNow(), SyncOutcome.done);
    expect(server.sent('POST', '/items/coach_attempts'), hasLength(2));
    final body = FakeDirectus.body(server.sent('POST', '/items/coach_attempts').first);
    expect(body['situation_key'], 'gen-v1-position-easy-42');
    expect(body.containsKey('user_id'), isFalse);
    expect((await db.select(db.coachAttemptRows).get()).every((r) => r.syncedAt == now), isTrue);
  });

  test('máy chủ từ chối (4xx khác) thì dòng nằm chờ, không chặn lượt', () async {
    serve();
    server.routes['POST /items/coach_attempts'] = (_) => FakeDirectus.error(403, 'FORBIDDEN');
    await CoachAttemptRepository(db, userId: 'u1').record(sample('a'));
    expect(await build().syncNow(), SyncOutcome.done);
    expect((await db.select(db.coachAttemptRows).getSingle()).syncedAt, isNull);
  });

  test('kéo về khi đăng nhập: thêm dòng còn thiếu', () async {
    serve(attempts: [toRemoteCoachAttempt(toCoachAttemptRow(sample('far')))]);
    await build().syncNow();
    final row = await db.select(db.coachAttemptRows).getSingle();
    expect(row.id, 'far');
    expect(row.userId, 'u1');
    expect(row.syncedAt, now);
  });

  test('mất mạng: không ném, trả offline', () async {
    serve();
    server.offline = true;
    await CoachAttemptRepository(db, userId: 'u1').record(sample('a'));
    expect(await build().syncNow(), SyncOutcome.offline);
    expect(await watchPendingCoach(db).first, 1);
  });

  test('đăng xuất và quên: xoá lần làm Coach của người này, giữ của người khác', () async {
    await CoachAttemptRepository(db, userId: 'u1').record(sample('a'));
    await CoachAttemptRepository(db, userId: 'u2').record(sample('b', userId: 'u2'));
    await signOutAndForget(db: db, auth: FakeAuthRepository.signedIn(), userId: 'u1');
    expect((await db.select(db.coachAttemptRows).get()).map((r) => r.id), ['b']);
  });
}
