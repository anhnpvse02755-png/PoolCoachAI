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

  test(
    'đồng hồ máy chạy lùi: vẫn đúng thứ tự chèn (id), và _trim xoá lượt chèn '
    'sớm nhất chứ không phải lượt có createdAt nhỏ nhất (ruling R18)',
    () async {
      final r = CoachChatRepository(db, userId: 'u1');
      final base = DateTime(2026, 10, 22, 9);

      // Mỗi lượt trao đổi sau có createdAt NHỎ HƠN lượt trước (đồng hồ máy
      // chạy lùi) — id (thứ tự chèn) và createdAt đi ngược hướng nhau, nên
      // mọi test dưới đây chỉ "qua" nếu code thật sự sắp theo id.
      Future<void> exchangeAt(int i) {
        final createdAt = base.subtract(Duration(hours: i));
        return r.addExchange(
          question: 'Q$i',
          askedAt: createdAt,
          reply: (text: 'Đáp Q$i', insufficient: false),
          answeredAt: createdAt,
        );
      }

      // Ba lượt đầu: kiểm tra thứ tự đọc là thứ tự CHÈN (Q0 trước Q1 trước
      // Q2), dù createdAt của Q0 lớn nhất (chèn trước, đồng hồ lùi).
      for (var i = 0; i < 3; i++) {
        await exchangeAt(i);
      }
      expect((await r.recentTurns(10)).map((e) => e.text), ['Q0', 'Đáp Q0', 'Q1', 'Đáp Q1', 'Q2', 'Đáp Q2']);
      expect((await r.watchTurns().first).map((e) => e.text), ['Q0', 'Đáp Q0', 'Q1', 'Đáp Q1', 'Q2', 'Đáp Q2']);

      // Thêm 98 lượt nữa (tổng 101 lượt trao đổi = 202 dòng, vượt
      // coachChatKeptTurns=200 đúng 2 dòng) — createdAt tiếp tục giảm, nên
      // lượt chèn sớm nhất (Q0, id nhỏ nhất) cũng là lượt có createdAt LỚN
      // NHẤT. Nếu _trim lỡ sắp theo createdAt, nó sẽ xoá lượt chèn muộn
      // nhất (Q100) chứ không phải Q0 — ngược với luật R18.
      for (var i = 3; i < 101; i++) {
        await exchangeAt(i);
      }

      final kept = await r.recentTurns(1000);
      expect(kept, hasLength(200));
      // Q0 và câu trả lời của nó (2 dòng chèn sớm nhất, id nhỏ nhất) đã bị
      // _trim xoá; lượt cũ nhất còn lại phải là Q1 (id kế tiếp), không phải
      // Q100 (lượt có createdAt nhỏ nhất).
      expect(kept.first.text, 'Q1');
      expect(kept.map((e) => e.text), isNot(contains('Q0')));
      expect(kept.map((e) => e.text), contains('Q100'));
    },
  );

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
