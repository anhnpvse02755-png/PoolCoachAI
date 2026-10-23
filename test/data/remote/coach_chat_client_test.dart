import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:poolcoachai/data/remote/coach_chat_client.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_coach_chat_server.dart';

void main() {
  late FakeCoachChatServer server;
  late FakeAuthRepository auth;
  late RemoteCoachChat chat;
  final ctx = fullCoachContext();

  http.Response answer(String text, {int remaining = 29}) => FakeCoachChatServer.json(200, {
        'text': text,
        'model': 'claude-opus-5',
        'remainingToday': remaining,
        'usage': {'input': 900, 'output': 120, 'cacheRead': 1800},
      });

  setUp(() {
    server = FakeCoachChatServer()..routes['POST /v1/coach-chat/blocked'] = (_) => http.Response('', 204);
    auth = FakeAuthRepository.signedIn();
    chat = RemoteCoachChat(client: server.client, baseUrl: FakeCoachChatServer.baseUrl, auth: auth);
  });

  test('gửi facts, lịch sử và câu hỏi kèm Bearer token của người chơi', () async {
    server.routes['POST /v1/coach-chat'] = (_) => answer('Hôm nay tập Phòng thủ.');
    final a = await chat.reply(
      ctx,
      const [(fromPlayer: true, text: 'Q1'), (fromPlayer: false, text: 'A1')],
      'Hôm nay tôi nên tập gì?',
    );
    final req = server.sent('POST', '/v1/coach-chat').single;
    expect(req.headers['Authorization'], 'Bearer access-u1');
    final body = jsonDecode(req.body) as Map<String, Object?>;
    expect(body['facts'], jsonDecode(jsonEncode(ctx.toFacts())));
    expect(body['history'], [
      {'fromPlayer': true, 'text': 'Q1'},
      {'fromPlayer': false, 'text': 'A1'},
    ]);
    expect(body['question'], 'Hôm nay tôi nên tập gì?');
    expect(a.reply, (text: 'Hôm nay tập Phòng thủ.', insufficient: false));
    expect(a.remainingToday, 29);
  });

  test('câu trả lời vi phạm bộ lọc: chưa đủ dữ liệu, và báo máy chủ tên luật', () async {
    server.routes['POST /v1/coach-chat'] = (_) => answer('Ngắm lệch 5° nhé.');
    final a = await chat.reply(ctx, const [], 'Hỏi');
    expect(a.reply, (text: '', insufficient: true));
    await pumpEventQueue();
    expect(jsonDecode(server.sent('POST', '/v1/coach-chat/blocked').single.body), {'rule': 'degree'});
  });

  test('Claude từ chối hoặc bị cắt: chưa đủ dữ liệu, vẫn có số lượt còn lại', () async {
    for (final code in ['refused', 'truncated']) {
      server.routes['POST /v1/coach-chat'] = (_) => FakeCoachChatServer.json(502, {'error': code, 'remainingToday': 12});
      final a = await chat.reply(ctx, const [], 'Hỏi');
      expect([a.reply.insufficient, a.remainingToday], [true, 12]);
    }
  });

  test('hết lượt: CoachChatQuotaExceeded mang resetAt', () async {
    server.routes['POST /v1/coach-chat'] =
        (_) => FakeCoachChatServer.json(429, {'error': 'quota', 'limit': 30, 'resetAt': '2026-10-22T17:00:00.000Z'});
    await expectLater(
      chat.reply(ctx, const [], 'Hỏi'),
      throwsA(isA<CoachChatQuotaExceeded>().having((e) => e.resetAt, 'resetAt', DateTime.utc(2026, 10, 22, 17))),
    );
  });

  test('401, 400, 502 upstream, 503, 500 và phản hồi hỏng: CoachChatUnavailable', () async {
    for (final r in [
      FakeCoachChatServer.json(401, {'error': 'unauthorized'}),
      FakeCoachChatServer.json(400, {'error': 'invalid', 'field': 'facts'}),
      FakeCoachChatServer.json(502, {'error': 'upstream'}),
      FakeCoachChatServer.json(503, {'error': 'busy'}),
      FakeCoachChatServer.json(500, {'error': 'internal'}),
      http.Response('<html>', 200),
    ]) {
      server.routes['POST /v1/coach-chat'] = (_) => r;
      await expectLater(chat.reply(ctx, const [], 'Hỏi'), throwsA(isA<CoachChatUnavailable>()));
    }
  });

  test('mất mạng: CoachChatUnavailable', () async {
    server.offline = true;
    await expectLater(chat.reply(ctx, const [], 'Hỏi'), throwsA(isA<CoachChatUnavailable>()));
  });

  test('phiên hết hạn: ném AuthFailure.sessionExpired, không gửi gì', () async {
    auth.tokenFailure = AuthFailure.sessionExpired;
    await expectLater(chat.reply(ctx, const [], 'Hỏi'), throwsA(AuthFailure.sessionExpired));
    expect(server.requests, isEmpty);
  });

  test('mất mạng lúc làm mới token: CoachChatUnavailable', () async {
    auth.tokenFailure = AuthFailure.network;
    await expectLater(chat.reply(ctx, const [], 'Hỏi'), throwsA(isA<CoachChatUnavailable>()));
  });

  test('remainingToday(): GET /v1/coach-chat/quota', () async {
    server.routes['GET /v1/coach-chat/quota'] =
        (_) => FakeCoachChatServer.json(200, {'limit': 30, 'used': 4, 'remainingToday': 26, 'resetAt': '2026-10-22T17:00:00.000Z'});
    expect(await chat.remainingToday(), 26);
    expect(server.requests.single.headers['Authorization'], 'Bearer access-u1');
  });
}
