import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';

/// Số ngày thông báo còn nằm trong hộp thư (và trong nhật ký).
const notificationInboxDays = 30;

/// Một dòng nhật ký thông báo: đã lập (giờ còn ở tương lai) hoặc đã tới giờ.
final class NotificationLogEntry {
  const NotificationLogEntry({
    required this.id,
    required this.kind,
    required this.key,
    required this.at,
    required this.title,
    required this.body,
    this.readAt,
  });

  final int id;
  final NotificationKind kind;
  final String key;
  final DateTime at;
  final String title;
  final String body;
  final DateTime? readAt;
}

/// Mục hộp thư: đã tới giờ và trong 30 ngày gần nhất, mới nhất trước.
List<NotificationLogEntry> inboxEntries(
  List<NotificationLogEntry> all,
  DateTime now,
) {
  final oldest = now.subtract(const Duration(days: notificationInboxDays));
  final inbox = [
    for (final e in all)
      if (!e.at.isAfter(now) && e.at.isAfter(oldest)) e,
  ];
  inbox.sort((a, b) {
    final byTime = b.at.compareTo(a.at);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
  return inbox;
}

/// Số mục hộp thư chưa đọc.
int unreadCount(List<NotificationLogEntry> all, DateTime now) =>
    inboxEntries(all, now).where((e) => e.readAt == null).length;

/// Giờ giao kế tiếp: mục tương lai sớm nhất; null khi không còn mục nào.
DateTime? nextDelivery(List<NotificationLogEntry> all, DateTime now) {
  DateTime? next;
  for (final e in all) {
    if (e.at.isAfter(now) && (next == null || e.at.isBefore(next))) {
      next = e.at;
    }
  }
  return next;
}

/// Mốc "đã thấy" để so với gợi ý mới: cái mới nhất theo giờ giữa cặp đã hiện
/// trên Trang chủ và mọi gợi ý đã giao trong nhật ký (khoá hỏng bị bỏ).
SeenRecommendation? recommendationBaseline({
  SeenRecommendation? shownOnHome,
  required List<NotificationLogEntry> log,
  required DateTime now,
}) {
  var best = shownOnHome;
  for (final e in log) {
    if (e.kind != NotificationKind.recommendation || e.at.isAfter(now)) {
      continue;
    }
    final parsed = parseRecommendationKey(e.key);
    if (parsed == null) continue;
    if (best == null || e.at.isAfter(best.at)) {
      best = SeenRecommendation(
        cat: parsed.cat,
        drillId: parsed.drillId,
        at: e.at,
      );
    }
  }
  return best;
}
