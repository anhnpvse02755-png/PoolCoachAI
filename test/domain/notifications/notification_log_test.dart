import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final now = DateTime(2026, 10, 13, 9);

  NotificationLogEntry entry(
    int id,
    DateTime at, {
    NotificationKind kind = NotificationKind.streak,
    String key = 'k',
    DateTime? readAt,
  }) => NotificationLogEntry(
    id: id,
    kind: kind,
    key: key,
    at: at,
    title: 't$id',
    body: 'b$id',
    readAt: readAt,
  );

  test('hộp thư: chỉ mục đã tới giờ trong 30 ngày, mới nhất trước', () {
    final all = [
      entry(1, DateTime(2026, 10, 12, 8)),
      entry(2, DateTime(2026, 10, 13, 8)),
      entry(3, DateTime(2026, 10, 13, 8)),
      entry(4, DateTime(2026, 10, 14, 8)), // tương lai
      entry(5, now.subtract(const Duration(days: 30))), // đúng 30 ngày: ra
      entry(6, now), // đúng bây giờ: vào
    ];
    expect(inboxEntries(all, now).map((e) => e.id), [6, 3, 2, 1]);
  });

  test('đếm chưa đọc bỏ mục tương lai và mục đã đọc', () {
    final all = [
      entry(1, DateTime(2026, 10, 12, 8)),
      entry(2, DateTime(2026, 10, 12, 9), readAt: DateTime(2026, 10, 12, 10)),
      entry(3, DateTime(2026, 10, 14, 8)),
    ];
    expect(unreadCount(all, now), 1);
  });

  test('đã tới giờ trong hôm nay: bỏ mục tương lai và mục hôm trước', () {
    final all = [
      entry(1, DateTime(2026, 10, 12, 23, 59)), // hôm qua
      entry(2, DateTime(2026, 10, 13)), // nửa đêm hôm nay
      entry(3, DateTime(2026, 10, 13, 8)),
      entry(4, now), // đúng bây giờ
      entry(5, DateTime(2026, 10, 13, 9, 1)), // tương lai
    ];
    expect(dueEarlierToday(all, now), {2, 3, 4});
  });

  test('lần giao kế tiếp là mục tương lai sớm nhất', () {
    final all = [
      entry(1, DateTime(2026, 10, 12, 8)),
      entry(2, DateTime(2026, 10, 15, 8)),
      entry(3, DateTime(2026, 10, 14, 8)),
    ];
    expect(nextDelivery(all, now), DateTime(2026, 10, 14, 8));
    expect(nextDelivery([entry(1, DateTime(2026, 10, 12))], now), isNull);
  });

  test('mốc đã thấy: mới hơn giữa Trang chủ và gợi ý đã giao; bỏ khoá hỏng và mục tương lai', () {
    final home = SeenRecommendation(
      cat: SkillCategory.aiming,
      drillId: 'd1',
      at: DateTime(2026, 10, 11, 9),
    );
    final delivered = entry(
      1,
      DateTime(2026, 10, 12, 8),
      kind: NotificationKind.recommendation,
      key: recommendationKey(
        DateTime(2026, 10, 12),
        SkillCategory.bank,
        'b1',
      ),
    );
    final broken = entry(
      2,
      DateTime(2026, 10, 12, 9),
      kind: NotificationKind.recommendation,
      key: 'hong',
    );
    final future = entry(
      3,
      DateTime(2026, 10, 14, 8),
      kind: NotificationKind.recommendation,
      key: recommendationKey(
        DateTime(2026, 10, 14),
        SkillCategory.aiming,
        'd9',
      ),
    );
    final other = entry(4, DateTime(2026, 10, 12, 9, 30));
    final got = recommendationBaseline(
      shownOnHome: home,
      log: [delivered, broken, future, other],
      now: now,
    );
    expect(got!.cat, SkillCategory.bank);
    expect(got.drillId, 'b1');
    expect(got.at, DateTime(2026, 10, 12, 8));

    expect(
      recommendationBaseline(shownOnHome: home, log: [broken, future], now: now),
      home,
    );
    expect(recommendationBaseline(log: const [], now: now), isNull);
    final newerHome = SeenRecommendation(
      cat: SkillCategory.aiming,
      drillId: 'd1',
      at: DateTime(2026, 10, 13, 8),
    );
    expect(
      recommendationBaseline(shownOnHome: newerHome, log: [delivered], now: now),
      newerHome,
    );
  });
}
