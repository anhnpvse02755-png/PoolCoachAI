import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';

/// Khung bọc 5 tab: thanh điều hướng dưới và nút Huấn luyện viên nổi
/// dùng được ở mọi tab.
///
/// Nút Coach nổi trên mọi tab vì đó là điểm khác biệt của sản phẩm —
/// người chơi phải với tới được huấn luyện viên từ bất cứ đâu, không
/// phải đi tìm trong một tab riêng.
///
/// Khung này **không** giữ thanh tiêu đề. Mỗi màn tự mang thanh của
/// mình qua [PcRootScaffold], vì màn con ở các kế hoạch sau cần tiêu đề
/// và nút quay lại riêng — shell giữ thanh thì sẽ thành hai thanh chồng
/// lên nhau. Màu thanh tab dưới cũng để [AppTheme] lo, không đặt lại ở
/// đây: đặt hai nơi thì sửa một nơi sẽ âm thầm không ăn.
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
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        tooltip: Vi.coachTitle,
        onPressed: () => context.push(Routes.coach),
        child: const Icon(Icons.psychology_outlined),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          for (var i = 0; i < _icons.length; i++)
            NavigationDestination(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
