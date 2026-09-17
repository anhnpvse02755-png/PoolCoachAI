import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';

/// Khung bọc 5 tab: thanh điều hướng dưới, chuông thông báo trên,
/// và nút Huấn luyện viên nổi dùng được ở mọi tab.
///
/// Nút Coach nổi trên mọi tab vì đó là điểm khác biệt của sản phẩm —
/// người chơi phải với tới được huấn luyện viên từ bất cứ đâu, không
/// phải đi tìm trong một tab riêng.
class PcShellScaffold extends StatelessWidget {
  const PcShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _icons = <IconData>[
    Icons.home_outlined,
    Icons.track_changes_outlined,
    Icons.play_circle_outline,
    Icons.bar_chart_outlined,
    Icons.person_outline,
  ];

  static const _labels = <String>[
    Vi.tabHome,
    Vi.tabTraining,
    Vi.tabPlay,
    Vi.tabStats,
    Vi.tabProfile,
  ];

  void _onTap(int index) {
    // initialLocation: true khi bấm lại chính tab đang mở sẽ đưa nhánh
    // đó về màn gốc, đúng như hành vi quen thuộc trên di động.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Vi.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: Vi.notificationsTitle,
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        tooltip: Vi.coachTitle,
        onPressed: () => context.push(Routes.coach),
        child: const Icon(Icons.sports_bar_outlined),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        backgroundColor: AppColors.bgDeep,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        items: [
          for (var i = 0; i < _icons.length; i++)
            BottomNavigationBarItem(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
