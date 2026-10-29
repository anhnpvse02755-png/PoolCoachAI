import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';

/// Màn mà một thông báo mở ra. Null khi khoá hỏng (không đi đâu cả).
String? notificationRoute(NotificationTap tap) => switch (tap.kind) {
  NotificationKind.recommendation => switch (parseRecommendationKey(tap.key)) {
    final parsed? => Routes.drill(parsed.drillId),
    null => null,
  },
  NotificationKind.schedule => Routes.schedule,
  NotificationKind.maintenance => Routes.equipment,
  NotificationKind.streak => Routes.training,
};

/// Đưa người dùng tới màn đúng khi họ chạm một thông báo.
///
/// Dịch vụ giữ lần chạm tới trước khi widget này có mặt (khởi động lạnh) và
/// giao ngay khi [NotificationService.setTapHandler] được gọi.
class NotificationTapListener extends ConsumerStatefulWidget {
  const NotificationTapListener({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState
    extends ConsumerState<NotificationTapListener> {
  late final NotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(notificationServiceProvider);
    _service.setTapHandler(_onTap);
  }

  @override
  void dispose() {
    _service.setTapHandler(null);
    super.dispose();
  }

  void _onTap(NotificationTap tap) {
    final route = notificationRoute(tap);
    if (route == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) widget.router.go(route);
      })
      ..ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
