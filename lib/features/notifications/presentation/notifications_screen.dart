import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/notification_tap_listener.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_action_tile.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_readable_width.dart';
import 'package:poolcoachai/core/widgets/pc_rebuild_at.dart';
import 'package:poolcoachai/core/widgets/pc_section_header.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
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
  /// Mục chưa đọc lúc mở màn: in đậm suốt lượt xem này dù đã đánh dấu đọc.
  final _bold = <int>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      notificationLogProvider,
      (_, next) => _markSeen(next),
      fireImmediately: true,
    );
  }

  /// Chỉ đọc nhật ký khi đã có giá trị và không đang tải lại: nhật ký cũ của
  /// tài khoản trước không được đánh dấu đọc cho tài khoản sau.
  void _markSeen(AsyncValue<List<NotificationLogEntry>> log) {
    if (!log.hasValue || log.isLoading) return;
    final now = ref.read(nowProvider)();
    final ids = [
      for (final e in inboxEntries(log.requireValue, now))
        if (e.readAt == null && !_bold.contains(e.id)) e.id,
    ];
    if (ids.isEmpty) return;
    _bold.addAll(ids);
    if (mounted) setState(() {});
    ref.read(notificationLogRepositoryProvider)?.markRead(ids, at: now);
  }

  Widget _sent() {
    final log = ref.watch(notificationLogProvider);
    final all = log.hasValue && !log.isLoading
        ? log.requireValue
        : const <NotificationLogEntry>[];
    final clock = ref.watch(nowProvider);
    return PcRebuildAt(
      clock: clock,
      nextAt: (now) => nextDelivery(all, now),
      builder: (context) {
        final current = clock();
        final entries = inboxEntries(all, current);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PcSectionHeader(title: Vi.notificationsSentTitle),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  Vi.notificationsSentEmpty,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              for (final e in entries) ...[
                PcCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Text(
                      Vi.notificationsSentAt(e.at, current),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    title: Text(
                      e.title,
                      style: TextStyle(
                        fontWeight: _bold.contains(e.id)
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(e.body),
                    onTap: () {
                      final route = notificationRoute(
                        NotificationTap(e.kind, e.key),
                      );
                      if (route != null) context.go(route);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        );
      },
    );
  }

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
          _sent(),
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
          if (granted || denied)
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
                    : Vi.notificationsPermissionDenied,
              ),
              trailing: granted
                  ? const Icon(Icons.check_circle_outline)
                  : null,
            )
          else
            // Nút xuống dưới chữ khi cột chữ hẹp (màn nhỏ, chữ lớn).
            PcActionTile(
              icon: const Icon(Icons.notifications_none),
              title: Vi.notificationsPermissionTitle,
              body: Vi.notificationsPermissionPrompt,
              actionLabel: Vi.equipmentReminderEnable,
              onAction: _enable,
            ),
          for (final note in service.schedulesInBackground
              ? const [
                  Vi.notificationsBackgroundNote,
                  Vi.notificationsRecommendationLimit,
                ]
              : [Vi.notificationsWebOnlyWhileOpen])
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                note,
                style: const TextStyle(color: AppColors.textMuted),
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
