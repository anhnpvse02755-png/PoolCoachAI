/// Ba loại thông báo của app.
enum NotificationKind {
  /// Nhắc bảo dưỡng đầu cơ.
  maintenance,

  /// Nhắc trước giờ bắt đầu một khung trong lịch tập tuần.
  schedule,

  /// Nhắc giữ chuỗi ngày tập.
  streak,
}

/// Nhắc lịch tập trước giờ bắt đầu bao nhiêu phút.
const scheduleReminderLeadMinutes = 30;

/// Chuỗi tối thiểu (ngày) để đáng nhắc giữ chuỗi.
const streakReminderMinDays = 2;

/// Giờ nhắc giữ chuỗi trong ngày (giờ địa phương).
const streakReminderHour = 20;

/// Loại thông báo nào đang bật. Mặc định bật cả ba.
class NotificationPrefs {
  const NotificationPrefs({
    this.maintenance = true,
    this.schedule = true,
    this.streak = true,
  });

  final bool maintenance;
  final bool schedule;
  final bool streak;

  bool isEnabled(NotificationKind kind) => switch (kind) {
    NotificationKind.maintenance => maintenance,
    NotificationKind.schedule => schedule,
    NotificationKind.streak => streak,
  };

  NotificationPrefs toggled(NotificationKind kind, bool enabled) =>
      NotificationPrefs(
        maintenance: kind == NotificationKind.maintenance
            ? enabled
            : maintenance,
        schedule: kind == NotificationKind.schedule ? enabled : schedule,
        streak: kind == NotificationKind.streak ? enabled : streak,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.maintenance == maintenance &&
      other.schedule == schedule &&
      other.streak == streak;

  @override
  int get hashCode => Object.hash(maintenance, schedule, streak);
}
