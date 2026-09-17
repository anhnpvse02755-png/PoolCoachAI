import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';
import 'package:poolcoachai/features/training/presentation/training_screen.dart';

/// Mỗi đường dẫn đã đăng ký phải dựng ra đúng một màn hình.
///
/// Các kế hoạch sau thêm route mới vào [Routes] thì cũng phải thêm một
/// dòng vào bảng này — quên là test hỏng ngay, chứ không im lặng bỏ sót.
const _screenForRoute = <String, Type>{
  Routes.home: HomeScreen,
  Routes.training: TrainingScreen,
  Routes.play: PlayScreen,
  Routes.stats: StatsScreen,
  Routes.profile: ProfileScreen,
  Routes.coach: CoachScreen,
  Routes.notifications: NotificationsScreen,
};

void main() {
  group('smoke test mọi route', () {
    testWidgets('mở được mọi đường dẫn mà không crash', (tester) async {
      final router = createAppRouter();
      await tester.pumpWidget(PoolCoachApp(router: router));
      await tester.pumpAndSettle();

      for (final path in _screenForRoute.keys) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'màn $path ném lỗi khi dựng',
        );
      }
    });

    testWidgets('mỗi đường dẫn dựng đúng màn hình của nó', (tester) async {
      final router = createAppRouter();
      await tester.pumpWidget(PoolCoachApp(router: router));
      await tester.pumpAndSettle();

      for (final entry in _screenForRoute.entries) {
        router.go(entry.key);
        await tester.pumpAndSettle();

        expect(
          find.byType(entry.value),
          findsOneWidget,
          reason: 'đường dẫn ${entry.key} phải dựng ${entry.value}',
        );
      }
    });

    test('bảng smoke test phủ hết mọi đường dẫn đã khai báo', () {
      final declared = <String>{
        ...Routes.tabs,
        Routes.coach,
        Routes.notifications,
      };

      expect(
        _screenForRoute.keys.toSet(),
        declared,
        reason: 'thêm route vào Routes thì phải thêm vào bảng smoke test',
      );
    });
  });
}
