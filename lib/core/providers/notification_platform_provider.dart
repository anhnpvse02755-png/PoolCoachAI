import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';

final notificationPlatformProvider = Provider<NotificationPlatform>(
  (ref) => createNotificationPlatform(),
);
