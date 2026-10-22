import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_layout.dart';

/// Khung bọc 5 tab và nút Huấn luyện viên dùng được ở mọi tab.
///
/// Dưới [AppLayout.mediumWidth] (điện thoại dọc): thanh tab dưới và nút
/// Coach nổi. Từ mốc đó (điện thoại ngang, máy tính bảng, máy tính): thanh
/// bên có nhãn, cuộn được, nút Coach đứng đầu thanh. Hai bố cục dùng chung
/// một [navigationShell]; go_router gắn sẵn `GlobalKey` cho nó, nên xoay
/// máy giữa chừng vẫn giữ nguyên tab đang mở, ngăn xếp và trạng thái màn.
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

  /// Khoảng nút Coach nổi chiếm ở đáy thân màn (nút 56 + lề). Màn có bảng
  /// cuộn chèn khoảng trống này ở cuối, để cuộn hết thì nút không che chữ.
  static const fabClearance = 56 + kFloatingActionButtonMargin;

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
    if (MediaQuery.sizeOf(context).width < AppLayout.mediumWidth) {
      return Scaffold(
        body: navigationShell,
        floatingActionButton: FloatingActionButton(
          tooltip: Vi.coachTitle,
          onPressed: () => context.push(Routes.coach),
          child: const Icon(Icons.psychology_outlined),
        ),
        // Nhãn thanh dưới giữ cỡ gốc: năm ô trên 360 dp không còn chỗ cho
        // chữ to hơn (Flutter tự kẹp ở 1.3, mức thấp hơn thắng).
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppLayout.navBarLabelMaxTextScale,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: [
              for (var i = 0; i < _icons.length; i++)
                NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
            ],
          ),
        ),
      );
    }

    // Thanh bên tự chừa lề an toàn phía nó; lề hai bên tai thỏ đã được gốc
    // app trừ đi rồi.
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            labelType: NavigationRailLabelType.all,
            // Máy ngang chỉ cao 360 dp: chữ lớn thì năm mục cộng nút Coach
            // dài hơn thế, nên thanh phải cuộn được.
            scrollable: true,
            leading: FloatingActionButton(
              elevation: 0,
              tooltip: Vi.coachTitle,
              onPressed: () => context.push(Routes.coach),
              child: const Icon(Icons.psychology_outlined),
            ),
            destinations: [
              for (var i = 0; i < _icons.length; i++)
                NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  label: Text(_labels[i]),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
