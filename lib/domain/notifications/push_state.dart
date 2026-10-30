import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Kênh push của thiết bị này.
enum PushChannel { web, fcm }

/// Hợp đồng với máy chủ: trong lúc [activeAt], máy chủ lo các loại
/// [serverKinds] cho [userId] trên thiết bị [deviceId].
final class PushLease {
  const PushLease({
    required this.userId,
    required this.deviceId,
    required this.serverKinds,
    required this.until,
  });

  final String userId;
  final String deviceId;
  final Set<NotificationKind> serverKinds;
  final DateTime until;

  bool activeAt(DateTime now) => now.isBefore(until);
}

/// Trạng thái push của thiết bị.
sealed class PushState {
  const PushState();
}

/// Không push được ở đây: trình duyệt thiếu hỗ trợ hoặc khoá VAPID rỗng.
final class PushUnavailable extends PushState {
  const PushUnavailable();
}

/// Push được nhưng lúc này không dùng: app tự nhắc.
final class PushLocal extends PushState {
  const PushLocal();
}

/// Máy chủ đang nhắc thay app theo [lease].
final class PushServer extends PushState {
  const PushServer(this.lease);

  final PushLease lease;
}

/// Prefs mà bộ nhắc cục bộ dùng: tắt các loại máy chủ đang lo, và chỉ khi
/// lease còn hạn và là của đúng người đang đăng nhập.
NotificationPrefs localPrefsUnder(
  NotificationPrefs prefs,
  PushState? state, {
  required String? userId,
  required DateTime now,
}) {
  if (state is! PushServer) return prefs;
  final lease = state.lease;
  if (userId == null || lease.userId != userId || !lease.activeAt(now)) {
    return prefs;
  }
  var out = prefs;
  for (final kind in lease.serverKinds) {
    out = out.toggled(kind, false);
  }
  return out;
}
