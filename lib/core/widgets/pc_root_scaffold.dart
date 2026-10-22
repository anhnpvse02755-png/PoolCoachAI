import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_layout.dart';
import 'package:poolcoachai/core/widgets/pc_readable_width.dart';

/// Khung của một màn gốc trong shell 5 tab.
///
/// Thanh tiêu đề thuộc về từng màn chứ không thuộc shell. Shell giữ
/// thanh riêng thì màn con — ví dụ chi tiết bài tập ở kế hoạch sau —
/// sẽ đẻ ra thanh thứ hai chồng lên, kèm hai nút quay lại. Để mỗi màn
/// tự mang thanh của mình thì lúc nào cũng đúng một thanh, và tên trên
/// đó là tên người dùng đang xem.
class PcRootScaffold extends StatelessWidget {
  const PcRootScaffold({
    required this.title,
    required this.body,
    this.maxBodyWidth = AppLayout.readableMaxWidth,
    super.key,
  });

  /// Tên màn, hiện trên thanh tiêu đề.
  final String title;

  /// Nội dung màn.
  final Widget body;

  /// Thân màn rộng tối đa ngần này, đặt giữa; vô hạn là không chặn (màn có
  /// bàn bi). Thanh tiêu đề luôn rộng hết.
  final double maxBodyWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: Vi.notificationsTitle,
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      body: maxBodyWidth.isFinite
          ? PcReadableWidth(maxWidth: maxBodyWidth, child: body)
          : body,
    );
  }
}
