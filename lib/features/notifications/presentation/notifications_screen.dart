import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

/// Màn Thông báo, mở đè lên shell từ chuông trên thanh tiêu đề.
///
/// Có Scaffold và AppBar riêng vì nó nằm ngoài shell 5 tab.
///
/// Icon của trạng thái rỗng cố ý khác icon chuông trên thanh tiêu đề:
/// trùng icon khiến test điều hướng phải phân biệt hai widget giống hệt
/// nhau, và trên màn hình thì nhìn cũng lặp.
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
