import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/training/presentation/training_screen.dart';

void main() {
  group('điều hướng khung app', () {
    testWidgets('mở lên là vào tab Trang chủ', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('thanh tab là NavigationBar của Material 3', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.byType(BottomNavigationBar),
        findsNothing,
        reason: 'theme đã bật Material 3 thì thanh tab phải theo M3',
      );
    });

    testWidgets('thanh tab hiện đủ 5 nhãn tiếng Việt', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(find.text(Vi.tabHome), findsOneWidget);
      expect(find.text(Vi.tabTraining), findsOneWidget);
      expect(find.text(Vi.tabPlay), findsOneWidget);
      expect(find.text(Vi.tabStats), findsOneWidget);
      expect(find.text(Vi.tabProfile), findsOneWidget);
    });

    testWidgets('bấm tab Luyện tập thì chuyển màn', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(Vi.tabTraining));
      await tester.pumpAndSettle();

      expect(find.byType(TrainingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('bấm tab Thi đấu rồi quay lại Trang chủ', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(Vi.tabPlay));
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget);

      await tester.tap(find.text(Vi.tabHome));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('nút tròn mở màn Huấn luyện viên', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(CoachScreen), findsOneWidget);
    });

    testWidgets('chuông mở màn Thông báo', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(Vi.notificationsTitle));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('mỗi tab gốc mang thanh tiêu đề của chính nó', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(Vi.homeTitle),
        ),
        findsOneWidget,
        reason: 'tab Trang chủ phải tự đặt tên mình lên thanh tiêu đề',
      );

      await tester.tap(find.text(Vi.tabTraining));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(Vi.trainingTitle),
        ),
        findsOneWidget,
        reason: 'đổi tab thì thanh tiêu đề phải đổi theo',
      );
    });

    testWidgets('thanh tiêu đề không mang tên app, và chỉ có một thanh',
        (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(
        find.text(Vi.appName),
        findsNothing,
        reason: 'tên app thuộc về màn khởi động, không phải mọi thanh tiêu đề',
      );
      expect(
        find.byType(AppBar),
        findsOneWidget,
        reason: 'shell không được giữ thanh riêng chồng lên thanh của màn',
      );
    });

    testWidgets('mở Coach từ tab vẫn chỉ thấy một thanh tiêu đề',
        (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(Vi.coachTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('đường dẫn không tồn tại ra màn tiếng Việt, không lộ ngoại lệ',
        (tester) async {
      final router = createAppRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(PoolCoachApp(router: router));
      await tester.pumpAndSettle();

      router.go('/khong-he-co-duong-dan-nay');
      await tester.pumpAndSettle();

      expect(find.text(Vi.notFoundTitle), findsOneWidget);
      expect(
        find.textContaining('Exception'),
        findsNothing,
        reason: 'không đẩy nội dung ngoại lệ ra trước mặt người dùng',
      );
    });

    testWidgets('mỗi tab giữ ngăn xếp riêng: mở Coach từ tab Luyện tập '
        'rồi quay lại vẫn ở Luyện tập', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(Vi.tabTraining));
      await tester.pumpAndSettle();
      expect(find.byType(TrainingScreen), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsOneWidget);

      // Quay lại bằng nút back của AppBar.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(TrainingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
