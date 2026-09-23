import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
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

import '../support/test_data.dart';

/// Một dòng của lưới smoke: mở đường dẫn nào, phải ra màn hình nào.
typedef _RouteCase = ({String path, Type screen});

/// Mỗi đường dẫn đã đăng ký phải dựng ra đúng một màn hình.
///
/// Khoá của bảng chính là thứ nằm trong [Routes.all]. Đường dẫn có
/// tham số góp mặt bằng **khuôn** của nó, kèm một đường dẫn mẫu đã
/// thay `:id` để mở thật — nhờ vậy route có tham số cũng bị phủ y
/// như route thường, chứ không nằm ngoài lưới.
///
/// Test cuối đối chiếu khoá của bảng với [Routes.all], nên thêm route
/// mới mà quên thêm vào đây là đỏ ngay.
const _routeCases = <String, _RouteCase>{
  Routes.home: (path: Routes.home, screen: HomeScreen),
  Routes.training: (path: Routes.training, screen: TrainingScreen),
  Routes.play: (path: Routes.play, screen: PlayScreen),
  Routes.stats: (path: Routes.stats, screen: StatsScreen),
  Routes.profile: (path: Routes.profile, screen: ProfileScreen),
  Routes.coach: (path: Routes.coach, screen: CoachScreen),
  Routes.notifications: (
    path: Routes.notifications,
    screen: NotificationsScreen,
  ),
  Routes.drillPattern: (
    path: '/training/drills/d1',
    screen: DrillDetailScreen,
  ),
  Routes.drillSessionPattern: (
    path: '/training/drills/d1/session',
    screen: DrillSessionScreen,
  ),
  Routes.articlePattern: (path: '/knowledge/k1', screen: KnowledgeScreen),
};

void main() {
  /// Dựng app với dữ liệu test rồi trả router để test tự lái.
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = createAppRouter();
    addTearDown(router.dispose);
    final container = testContainer();
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

  group('smoke test mọi route', () {
    testWidgets('mở được mọi đường dẫn mà không crash', (tester) async {
      final router = await pumpApp(tester);

      for (final route in _routeCases.values) {
        router.go(route.path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'màn ${route.path} ném lỗi khi dựng',
        );
      }
    });

    testWidgets('mỗi đường dẫn dựng đúng màn hình của nó', (tester) async {
      final router = await pumpApp(tester);

      for (final route in _routeCases.values) {
        router.go(route.path);
        await tester.pumpAndSettle();

        expect(
          find.byType(route.screen),
          findsOneWidget,
          reason: 'đường dẫn ${route.path} phải dựng ${route.screen}',
        );
      }
    });

    test('bảng smoke test phủ hết mọi đường dẫn đã khai báo', () {
      expect(
        _routeCases.keys.toSet(),
        Routes.all.toSet(),
        reason: 'thêm route vào Routes.all thì phải thêm vào bảng smoke test',
      );
    });

    // Đường dẫn mẫu phải đúng khuôn của route nó đại diện. Lấy mẫu
    // sai khuôn thì smoke test vẫn xanh trong khi route thật hỏng —
    // đúng kiểu lưới trông như có mà không bắt được gì.
    test('đường dẫn mẫu khớp đúng khuôn của route', () {
      for (final entry in _routeCases.entries) {
        final patternParts = entry.key.split('/');
        final pathParts = entry.value.path.split('/');

        expect(
          pathParts.length,
          patternParts.length,
          reason: '${entry.value.path} không cùng số đoạn với ${entry.key}',
        );

        for (var i = 0; i < patternParts.length; i++) {
          if (patternParts[i].startsWith(':')) {
            expect(
              pathParts[i],
              isNotEmpty,
              reason: 'đoạn tham số ${patternParts[i]} phải có id mẫu',
            );
          } else {
            expect(
              pathParts[i],
              patternParts[i],
              reason: '${entry.value.path} lệch khuôn ${entry.key}',
            );
          }
        }
      }
    });
  });
}
