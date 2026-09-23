import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/test/support/fake_auth.dart';

/// Màn nhập kết quả buổi tập — mục 6.4 của thiết kế.
///
/// Ràng buộc đến thẳng từ kiểu miền: bài có `passThreshold` bắt buộc
/// nhập `attempts`, bài có `target` thì không hỏi. Dữ liệu vào không
/// hợp lệ bị chặn **tại nút lưu**, chứ không lưu một log méo rồi để
/// `drillRatio()` trả null ở màn khác — lúc đó chẳng ai truy ra nữa.
void main() {
  final today = DateTime(2026, 9, 22, 10, 0);

  Future<(AppDatabase, GoRouter)> openSession(
    WidgetTester tester,
    String drillId,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await upsertSeed(db);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => today),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      ],
    );
    addTearDown(container.dispose);

    final router = createAppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.drillSession(drillId));
    await tester.pumpAndSettle();
    return (db, router);
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, label),
      value,
    );
  }

  testWidgets('bài chấm theo tỉ lệ thì hỏi cả kết quả lẫn số lần thử',
      (tester) async {
    await openSession(tester, 'd1');

    expect(find.text(Vi.sessionScoreLabelAttempts), findsOneWidget);
    expect(find.text(Vi.sessionAttemptsLabel), findsOneWidget);
  });

  testWidgets('bài chấm theo mục tiêu tuyệt đối thì không hỏi số lần thử',
      (tester) async {
    await openSession(tester, 'd4');

    expect(find.text(Vi.sessionScoreLabelTarget), findsOneWidget);
    expect(find.text(Vi.sessionAttemptsLabel), findsNothing);
  });

  testWidgets('bỏ trống kết quả thì chặn tại nút lưu, không ghi gì xuống',
      (tester) async {
    final (db, _) = await openSession(tester, 'd1');

    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    expect(find.text(Vi.sessionScoreRequired), findsOneWidget);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
  });

  testWidgets('thiếu số lần thử ở bài chấm theo tỉ lệ thì chặn',
      (tester) async {
    final (db, _) = await openSession(tester, 'd1');

    await fill(tester, Vi.sessionScoreLabelAttempts, '7');
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    expect(find.text(Vi.sessionAttemptsRequired), findsOneWidget);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
  });

  testWidgets('số lần thử bằng 0 thì chặn, không để chia cho 0', (tester) async {
    final (db, _) = await openSession(tester, 'd1');

    await fill(tester, Vi.sessionScoreLabelAttempts, '7');
    await fill(tester, Vi.sessionAttemptsLabel, '0');
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    expect(find.text(Vi.sessionAttemptsInvalid), findsOneWidget);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
  });

  testWidgets('lưu xong nói ngay buổi này đạt bao nhiêu phần mục tiêu',
      (tester) async {
    await openSession(tester, 'd1');

    await fill(tester, Vi.sessionScoreLabelAttempts, '9');
    await fill(tester, Vi.sessionAttemptsLabel, '10');
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    // d1 đạt khi trúng 8 trên 10 → trúng 9 là 113% mục tiêu.
    expect(find.text(Vi.sessionSavedRatio('113%')), findsOneWidget);
  });

  testWidgets('hai buổi tập ghi liên tiếp ra hai log riêng, không đè nhau',
      (tester) async {
    final (db, router) = await openSession(tester, 'd1');

    for (final score in ['7', '9']) {
      router.go(Routes.drillSession('d1'));
      await tester.pumpAndSettle();
      await fill(tester, Vi.sessionScoreLabelAttempts, score);
      await fill(tester, Vi.sessionAttemptsLabel, '10');
      await tester.tap(find.text(Vi.sessionSaveAction));
      await tester.pumpAndSettle();
    }

    final logs = await db.select(db.drillLogRows).get();
    expect(logs.length, 2);
    expect(logs.map((l) => l.id).toSet().length, 2);
  });

  testWidgets('buổi tập mới mang id UUID v4', (tester) async {
    final (db, _) = await openSession(tester, 'd1');

    await fill(tester, Vi.sessionScoreLabelAttempts, '7');
    await fill(tester, Vi.sessionAttemptsLabel, '10');
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    final id = (await db.select(db.drillLogRows).get()).single.id;
    expect(
      id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });
}
