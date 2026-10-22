import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
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
import 'package:poolcoachai/features/profile/presentation/equipment_screen.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';
import 'package:poolcoachai/features/rank/presentation/layout_gallery_screen.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';
import 'package:poolcoachai/features/rank/presentation/rank_screen.dart';
import 'package:poolcoachai/features/rank/presentation/test_screen.dart';
import 'package:poolcoachai/features/roadmap/presentation/roadmap_screen.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_detail_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_session_screen.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_screen.dart';
import 'package:poolcoachai/features/training/presentation/schedule_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart';
import 'package:poolcoachai/features/training/presentation/timer_screen.dart';
import 'package:poolcoachai/features/training/presentation/training_screen.dart';

import 'test_data.dart';

/// Một dòng của lưới smoke: mở đường dẫn nào, phải ra màn hình nào.
typedef RouteCase = ({String path, Type screen});

/// Mỗi đường dẫn đã đăng ký phải dựng ra đúng một màn hình.
///
/// Khoá của bảng chính là thứ nằm trong [Routes.all]. Đường dẫn có
/// tham số góp mặt bằng **khuôn** của nó, kèm một đường dẫn mẫu đã
/// thay `:id` để mở thật — nhờ vậy route có tham số cũng bị phủ y
/// như route thường, chứ không nằm ngoài lưới.
///
/// Test cuối đối chiếu khoá của bảng với [Routes.all], nên thêm route
/// mới mà quên thêm vào đây là đỏ ngay.
const signedInRouteCases = <String, RouteCase>{
  Routes.home: (path: Routes.home, screen: HomeScreen),
  Routes.training: (path: Routes.training, screen: TrainingScreen),
  Routes.play: (path: Routes.play, screen: PlayScreen),
  Routes.stats: (path: Routes.stats, screen: StatsScreen),
  Routes.profile: (path: Routes.profile, screen: ProfileScreen),
  Routes.equipment: (path: Routes.equipment, screen: EquipmentScreen),
  Routes.coach: (path: Routes.coach, screen: CoachScreen),
  Routes.coachSituation: (
    path: '/coach/situation?lib=pos-rail-1',
    screen: SituationScreen,
  ),
  Routes.coachLibrary: (path: Routes.coachLibrary, screen: CoachLibraryScreen),
  Routes.notifications: (
    path: Routes.notifications,
    screen: NotificationsScreen,
  ),
  Routes.drillPattern: (path: '/training/drills/d1', screen: DrillDetailScreen),
  Routes.drillSessionPattern: (
    path: '/training/drills/d1/session',
    screen: DrillSessionScreen,
  ),
  Routes.simulator: (path: Routes.simulator, screen: SimulatorScreen),
  Routes.planner: (path: Routes.planner, screen: PlannerScreen),
  Routes.roadmap: (path: Routes.roadmap, screen: RoadmapScreen),
  Routes.timer: (path: Routes.timer, screen: TimerScreen),
  Routes.schedule: (path: Routes.schedule, screen: ScheduleScreen),
  Routes.rankLayouts: (path: Routes.rankLayouts, screen: LayoutGalleryScreen),
  Routes.onboardingRank: (
    path: Routes.onboardingRank,
    screen: OnboardingScreen,
  ),
  Routes.rankTest: (path: Routes.rankTest, screen: TestScreen),
  Routes.rank: (path: Routes.rank, screen: RankScreen),
  Routes.knowledge: (path: Routes.knowledge, screen: KnowledgeLibraryScreen),
  Routes.articlePattern: (path: '/knowledge/k1', screen: KnowledgeScreen),
};

/// Màn tài khoản chỉ mở được khi **chưa** đăng nhập, nên đi lưới riêng.
const signedOutRouteCases = <String, RouteCase>{
  Routes.login: (path: Routes.login, screen: LoginScreen),
  Routes.register: (path: Routes.register, screen: RegisterScreen),
  Routes.forgotPassword: (
    path: Routes.forgotPassword,
    screen: ForgotPasswordScreen,
  ),
  Routes.resetPassword: (
    path: '/reset-password?token=abc',
    screen: ResetPasswordScreen,
  ),
};

/// Màn có thân là `TablePanelLayout`: bàn bi và bảng điều khiển.
const tableScreens = <Type>{SimulatorScreen, PlannerScreen, SituationScreen};

/// Dựng app với [container] rồi trả router để test tự lái.
Future<GoRouter> pumpRoutedApp(
  WidgetTester tester, {
  required ProviderContainer container,
  bool signedIn = true,
}) async {
  final router = createAppRouter(
    auth: signedIn ? signedInGate() : AuthGate.fixed(const SignedOut()),
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
