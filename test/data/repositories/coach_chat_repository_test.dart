import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final t0 = DateTime(2026, 10, 22, 9);
  Future<void> exchange(CoachChatRepository r, String q, {bool blocked = false}) => r.addExchange(
        question: q,
        askedAt: t0,
        reply: blocked ? (text: '', insufficient: true) : (text: 'Đáp $q', insufficient: false),
        answeredAt: t0,
      );

  test('câu hỏi rồi câu trả lời, đúng thứ tự dù cùng thời điểm', () async {
    final r = CoachChatRepository(db, userId: 'u1');
    await exchange(r, 'Q1');
    await exchange(r, 'Q2');
    expect((await r.recentTurns(10)).map((e) => e.text), ['Q1', 'Đáp Q1', 'Q2', 'Đáp Q2']);
    expect((await r.watchTurns().first).map((e) => e.fromPlayer), [true, false, true, false]);
  });

  test('lượt bị chặn: text rỗng, insufficient', () async {
    final r = CoachChatRepository(db, userId: 'u1');
    await exchange(r, 'Q', blocked: true);
    expect(
      (await r.recentTurns(1)).single,
      isA<CoachChatEntry>().having((e) => [e.text, e.insufficient], 'turn', ['', true]),
    );
  });

  test('recentTurns(n): n lượt cuối, cũ trước', () async {
    final r = CoachChatRepository(db, userId: 'u1');
    for (var i = 0; i < 6; i++) {
      await exchange(r, 'Q$i');
    }
    expect((await r.recentTurns(3)).map((e) => e.text), ['Đáp Q4', 'Q5', 'Đáp Q5']);
  });

  test('giữ 200 lượt mới nhất mỗi tài khoản, không đụng tài khoản khác; xoá chỉ của mình', () async {
    final a = CoachChatRepository(db, userId: 'u1'), b = CoachChatRepository(db, userId: 'u2');
    await exchange(b, 'B');
    for (var i = 0; i < 101; i++) {
      await exchange(a, 'Q$i');
    }
    final kept = await a.recentTurns(1000);
    expect([kept.length, kept.first.text], [200, 'Q1']);
    expect(await b.recentTurns(10), hasLength(2));
    await a.clear();
    expect([(await a.recentTurns(10)).length, (await b.recentTurns(10)).length], [0, 2]);
  });
}
