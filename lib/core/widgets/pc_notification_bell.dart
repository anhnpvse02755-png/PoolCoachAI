import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_rebuild_at.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';

/// Chuông Thông báo trên thanh tiêu đề, kèm số mục chưa đọc.
///
/// Chỉ đọc nhật ký khi đã có giá trị và không đang tải lại (đổi tài khoản):
/// giá trị cũ của tài khoản trước không được hiện cho tài khoản sau.
class PcNotificationBell extends ConsumerWidget {
  const PcNotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(notificationLogProvider);
    final ready = log.hasValue && !log.isLoading;
    final all = ready ? log.requireValue : const <NotificationLogEntry>[];
    final clock = ref.watch(nowProvider);
    return PcRebuildAt(
      clock: clock,
      nextAt: (now) => nextDelivery(all, now),
      builder: (context) {
        final n = unreadCount(all, clock());
        return IconButton(
          tooltip: Vi.notificationsBellTooltip(n),
          icon: Badge(
            isLabelVisible: n > 0,
            // Chữ lớn làm huy hiệu rộng ra phía phải; kéo vào để không chạm mép.
            offset: const Offset(-6, 0),
            label: Text(Vi.notificationsUnreadBadge(n)),
            child: const Icon(Icons.notifications_none),
          ),
          onPressed: () => context.push(Routes.notifications),
        );
      },
    );
  }
}
