import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_readable_width.dart';
import 'package:poolcoachai/core/widgets/pc_section_header.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Màn Thông báo, mở đè lên shell từ chuông trên thanh tiêu đề.
///
/// Có Scaffold và AppBar riêng vì nó nằm ngoài shell 5 tab. Ba phần:
/// quyền thông báo, loại thông báo bật/tắt, và danh sách sẽ gửi trong
/// 7 ngày tới — chính kế hoạch mà dịch vụ gửi, không phải bản sao.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _enable() async {
    await ref.read(notificationServiceProvider).requestPermission();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final prefs =
        ref.watch(notificationPrefsProvider).value ?? const NotificationPrefs();
    final upcoming = ref.watch(upcomingNotificationsProvider);
    final now = ref.watch(nowProvider)();

    return Scaffold(
      appBar: AppBar(title: const Text(Vi.notificationsTitle)),
      body: PcReadableWidth(child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _permissionCard(),
          const PcSectionHeader(title: Vi.notificationsSettingsTitle),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final kind in NotificationKind.values)
                  SwitchListTile(
                    title: Text(Vi.notificationKind(kind)),
                    subtitle: Text(Vi.notificationKindHint(kind)),
                    value: prefs.isEnabled(kind),
                    onChanged: (enabled) => ref
                        .read(notificationPrefsProvider.notifier)
                        .setEnabled(kind, enabled),
                  ),
              ],
            ),
          ),
          const PcSectionHeader(title: Vi.notificationsUpcomingTitle),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                Vi.notificationsUpcomingEmpty,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ..._grouped(upcoming, now),
        ],
      )),
    );
  }

  Widget _permissionCard() {
    final service = ref.watch(notificationServiceProvider);
    if (!service.isSupported) {
      return const PcCard(
        child: ListTile(
          leading: Icon(Icons.notifications_off_outlined),
          title: Text(Vi.notificationsPermissionTitle),
          subtitle: Text(Vi.notificationsPermissionUnsupported),
        ),
      );
    }
    final permission = service.permission;
    final granted = permission == 'granted';
    final denied = permission == 'denied';
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              granted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none,
            ),
            title: const Text(Vi.notificationsPermissionTitle),
            subtitle: Text(
              granted
                  ? Vi.notificationsPermissionGranted
                  : denied
                  ? Vi.notificationsPermissionDenied
                  : Vi.notificationsPermissionPrompt,
            ),
            trailing: granted
                ? const Icon(Icons.check_circle_outline)
                : denied
                ? null
                : TextButton(
                    onPressed: _enable,
                    child: const Text(Vi.equipmentReminderEnable),
                  ),
          ),
          if (!service.schedulesInBackground)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                Vi.notificationsWebOnlyWhileOpen,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _grouped(List<PlannedNotification> upcoming, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final widgets = <Widget>[];
    DateTime? currentDay;
    for (final n in upcoming) {
      final day = DateTime(n.at.year, n.at.month, n.at.day);
      if (day != currentDay) {
        currentDay = day;
        final offset = DateTime(day.year, day.month, day.day)
            .difference(today)
            .inDays;
        widgets.add(
          PcSectionHeader(
            title: switch (offset) {
              0 => Vi.notificationsToday,
              1 => Vi.notificationsTomorrow,
              _ => Vi.notificationsDay(day),
            },
          ),
        );
      }
      widgets.add(
        PcCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Text(
              Vi.notificationsTime(n.at),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            title: Text(n.title),
            subtitle: Text(n.body),
          ),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    return widgets;
  }
}
