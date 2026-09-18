import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

/// Màn Thông báo, mở đè lên shell từ chuông trên thanh tiêu đề.
///
/// Có Scaffold và AppBar riêng vì nó nằm ngoài shell 5 tab.
///
/// Icon trạng thái rỗng là chuông đang rung, khác chuông tĩnh ở thanh
/// tiêu đề các màn gốc — cùng một vật, nhưng ở đây nó là hình minh hoạ
/// chứ không phải nút bấm.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.notificationsTitle)),
      body: const PcEmptyState(
        icon: Icons.notifications_active_outlined,
        title: Vi.notificationsTitle,
        body: Vi.notificationsComing,
      ),
    );
  }
}
