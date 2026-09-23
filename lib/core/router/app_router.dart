import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_shell_scaffold.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_detail_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_session_screen.dart';
import 'package:poolcoachai/features/training/presentation/training_screen.dart';

/// Dựng router của app.
///
/// Năm tab dùng StatefulShellRoute nên mỗi tab giữ ngăn xếp riêng: đi
/// sâu ba màn trong Luyện tập, sang Thi đấu, quay lại vẫn còn nguyên.
/// Các kế hoạch sau cắm màn con vào đúng nhánh tương ứng.
///
/// Đây là hàm dựng chứ không phải biến toàn cục, vì GoRouter **mang
/// trạng thái**: nó nhớ đang đứng ở đâu. Một router dùng chung toàn
/// chương trình khiến hai màn hình không thể tồn tại độc lập, và trong
/// kiểm thử thì test trước để lại vị trí điều hướng cho test sau.
GoRouter createAppRouter() => GoRouter(
  initialLocation: Routes.home,
  // Đường dẫn lạ thì dựng màn tiếng Việt của mình, không để go_router
  // đổ trang lỗi mặc định — trang đó là tiếng Anh và in thẳng nội dung
  // ngoại lệ ra trước mặt người chơi.
  errorBuilder: (context, state) => Scaffold(
    body: PcEmptyState(
      icon: Icons.help_outline,
      title: Vi.notFoundTitle,
      body: Vi.notFoundBody,
      action: FilledButton(
        onPressed: () => context.go(Routes.home),
        child: const Text(Vi.notFoundAction),
      ),
    ),
  ),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          PcShellScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.training,
              builder: (context, state) => const TrainingScreen(),
              routes: [
                GoRoute(
                  path: 'drills/:id',
                  builder: (context, state) => DrillDetailScreen(
                    drillId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'session',
                      builder: (context, state) => DrillSessionScreen(
                        drillId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.play,
              builder: (context, state) => const PlayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.stats,
              builder: (context, state) => const StatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.coach,
      builder: (context, state) => const CoachScreen(),
    ),
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
    // Bài đọc mở đè lên shell: vào được từ AI Home và từ bài tập, nên
    // không thuộc riêng nhánh tab nào.
    GoRoute(
      path: Routes.articlePattern,
      builder: (context, state) =>
          KnowledgeScreen(articleId: state.pathParameters['id']!),
    ),
  ],
);
