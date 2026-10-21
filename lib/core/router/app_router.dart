import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_shell_scaffold.dart';
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/forgot_password_screen.dart';
import 'package:poolcoachai/features/auth/presentation/login_screen.dart';
import 'package:poolcoachai/features/auth/presentation/register_screen.dart';
import 'package:poolcoachai/features/auth/presentation/reset_password_screen.dart';
import 'package:poolcoachai/features/coach/presentation/coach_library_screen.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';
import 'package:poolcoachai/features/coach/presentation/situation_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_library_screen.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';
import 'package:poolcoachai/features/profile/presentation/equipment_screen.dart';
import 'package:poolcoachai/features/roadmap/presentation/roadmap_screen.dart';
import 'package:poolcoachai/features/rank/presentation/layout_gallery_screen.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';
import 'package:poolcoachai/features/rank/presentation/rank_screen.dart';
import 'package:poolcoachai/features/rank/presentation/test_screen.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_detail_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_session_screen.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart';
import 'package:poolcoachai/features/training/presentation/schedule_screen.dart';
import 'package:poolcoachai/features/training/presentation/timer_screen.dart';
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
GoRouter createAppRouter({
  required AuthGate auth,
  OnboardingGate? onboarding,
}) => GoRouter(
  initialLocation: Routes.home,
  refreshListenable: onboarding == null
      ? auth
      : Listenable.merge([auth, onboarding]),
  redirect: (context, state) => authRedirect(
    auth.state,
    state.uri,
    onboarding: onboarding?.check ?? OnboardingCheck.notRequired,
  ),
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
                  path: 'simulator',
                  builder: (context, state) => const SimulatorScreen(),
                ),
                GoRoute(
                  path: 'planner',
                  builder: (context, state) => const PlannerScreen(),
                ),
                GoRoute(
                  path: 'roadmap',
                  builder: (context, state) => const RoadmapScreen(),
                ),
                GoRoute(
                  path: 'timer',
                  builder: (context, state) => const TimerScreen(),
                ),
                GoRoute(
                  path: 'schedule',
                  builder: (context, state) => const ScheduleScreen(),
                ),
                GoRoute(
                  path: 'drills/:id',
                  builder: (context, state) =>
                      DrillDetailScreen(drillId: state.pathParameters['id']!),
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
              routes: [
                GoRoute(
                  path: 'equipment',
                  builder: (context, state) => const EquipmentScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.coach,
      builder: (context, state) => const CoachScreen(),
      routes: [
        GoRoute(
          path: 'situation',
          builder: (context, state) {
            final q = state.uri.queryParameters;
            return SituationScreen(
              key: ValueKey(state.uri.toString()),
              request: SituationRequest.parse(q),
            );
          },
        ),
        GoRoute(
          path: 'library',
          builder: (context, state) => CoachLibraryScreen(
            index: int.tryParse(state.uri.queryParameters['i'] ?? ''),
          ),
        ),
      ],
    ),
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(path: Routes.rank, builder: (context, state) => const RankScreen()),
    GoRoute(
      path: Routes.rankLayouts,
      builder: (context, state) => LayoutGalleryScreen(
        index: int.tryParse(state.uri.queryParameters['i'] ?? ''),
      ),
    ),
    GoRoute(
      path: Routes.onboardingRank,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: Routes.rankTest,
      builder: (context, state) => const TestScreen(),
    ),
    // Bài đọc mở đè lên shell: vào được từ AI Home và từ bài tập, nên
    // không thuộc riêng nhánh tab nào.
    GoRoute(
      path: Routes.knowledge,
      builder: (context, state) => const KnowledgeLibraryScreen(),
    ),
    GoRoute(
      path: Routes.articlePattern,
      builder: (context, state) =>
          KnowledgeScreen(articleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) =>
          ResetPasswordScreen(token: state.uri.queryParameters['token']),
    ),
  ],
);

/// Ai được vào đâu — tách riêng để test không phải dựng router.
///
/// Chưa đăng nhập thì chỉ vào được ba màn tài khoản; đã đăng nhập thì
/// không vào lại chúng. Link đặt lại mật khẩu mở được ở cả hai trạng
/// thái. Đã đăng nhập mà tài khoản chắc chắn chưa có hạng thì vào bộ câu
/// hỏi trước (spec mục 7.1); go_router chạy lại redirect trên đích mới,
/// nên từ màn tài khoản sẽ đi Trang chủ rồi mới sang bộ câu hỏi.
String? authRedirect(
  AuthState auth,
  Uri location, {
  OnboardingCheck onboarding = OnboardingCheck.notRequired,
}) {
  final path = location.path;
  if (path == Routes.resetPassword) return null;
  final onAuthPage = Routes.signedOutOnly.contains(path);
  return switch (auth) {
    SignedOut() when !onAuthPage => Routes.login,
    SignedIn() when onAuthPage => Routes.home,
    SignedIn()
        when onboarding == OnboardingCheck.required &&
            path != Routes.onboardingRank =>
      Routes.onboardingRank,
    _ => null,
  };
}
