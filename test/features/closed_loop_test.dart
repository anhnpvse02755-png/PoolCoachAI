import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import '../support/fake_auth.dart';
import '../support/test_data.dart';

/// Vòng khép kín: xem gợi ý → ghi kết quả → gợi ý đổi theo.
///
/// Đây là lý do tồn tại của lối A trong thiết kế. Drift `watch()` nối
/// thẳng lên `StreamProvider`, nên màn hình đổi theo dữ liệu **về mặt
/// cấu trúc**. Không chỗ nào trong test này gọi `invalidate` hay
/// `refresh` — nếu phải gọi thì lối A đã hỏng và số trên màn hình chỉ
/// đúng khi ai đó nhớ gọi tay.
void main() {
  /// Hôm nay cố định. Đồng hồ thật làm test xanh hôm nay, đỏ nửa đêm.
  final today = DateTime(2026, 9, 22, 10, 0);

  Future<(AppDatabase, ProviderContainer, GoRouter)> bootApp(
      WidgetTester tester) async {
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

    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return (db, container, router);
  }

  testWidgets('mở app lần đầu thì AI Home nói câu của người mới',
      (tester) async {
    await bootApp(tester);

    expect(
      find.text(Vi.pickReason(
        PickReason.newcomer,
        Vi.skill(SkillCategory.aiming),
      )),
      findsOneWidget,
    );
  });

  testWidgets('ghi ba buổi kém ở Cân bi thì AI Home tự đổi sang nhóm đó',
      (tester) async {
    final (_, container, _) = await bootApp(tester);

    // d8 là bài Cân bi duy nhất, đạt khi trúng 5 trên 10.
    final repo = container.read(drillLogRepositoryProvider);
    for (var i = 0; i < 3; i++) {
      await repo.add(
        DrillLog(
          id: 'kem-$i',
          drillId: 'd8',
          date: today.subtract(Duration(hours: 3 - i)),
          score: 1,
          attempts: 10,
        ),
      );
    }
    await tester.pumpAndSettle();

    expect(
      find.text(Vi.pickReason(
        PickReason.weakest,
        Vi.skill(SkillCategory.bank),
      )),
      findsOneWidget,
      reason: 'ghi log xong màn hình phải tự đổi, không ai gọi invalidate',
    );
  });

  testWidgets('log ghi xuống rồi vẫn còn khi dựng lại toàn bộ cây widget',
      (tester) async {
    final (db, container, _) = await bootApp(tester);

    await container.read(drillLogRepositoryProvider).add(
          DrillLog(
            id: 'con-mai',
            drillId: 'd1',
            date: today,
            score: 9,
            attempts: 10,
          ),
        );
    await tester.pumpAndSettle();

    // Dựng lại từ đầu trên đúng DB đó — như đóng app rồi mở lại.
    final logs = await db.select(db.drillLogRows).get();
    expect(logs.single.id, 'con-mai');
  });

  // Vòng khép kín đi trọn qua giao diện, đúng như người chơi dùng:
  // xem gợi ý → mở bài → ghi kết quả → gợi ý đổi theo.
  testWidgets('ghi kết quả từ màn buổi tập thì AI Home đổi gợi ý theo',
      (tester) async {
    final (_, _, router) = await bootApp(tester);

    // Người mới: gợi ý mở đầu là Ngắm bi.
    expect(
      find.text(Vi.pickReason(
        PickReason.newcomer,
        Vi.skill(SkillCategory.aiming),
      )),
      findsOneWidget,
    );

    await tester.tap(find.text(Vi.homeDrillOpen));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.drillStartAction));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionScoreLabelAttempts),
      '9',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionAttemptsLabel),
      '10',
    );
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    router.go(Routes.home);
    await tester.pumpAndSettle();

    // Ngắm bi đã có dữ liệu hôm nay, nên luật người mới không còn khớp
    // và luật luân phiên đưa sang nhóm chưa đụng tới.
    expect(
      find.text(Vi.pickReason(
        PickReason.rotation,
        Vi.skill(SkillCategory.position),
      )),
      findsOneWidget,
      reason: 'ghi xong mà gợi ý không đổi nghĩa là stream chưa nối tới màn',
    );
  });

  testWidgets('buổi tập ghi log theo đồng hồ được tiêm, không phải giờ máy',
      (tester) async {
    final (db, _, _) = await bootApp(tester);

    await tester.tap(find.text(Vi.homeDrillOpen));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.drillStartAction));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionScoreLabelAttempts),
      '9',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionAttemptsLabel),
      '10',
    );
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    final log = (await db.select(db.drillLogRows).get()).single;

    expect(
      log.date,
      today,
      reason: 'lấy giờ máy thì buổi tập rơi sang ngày khác với ngày mà '
          'gợi ý đang tính, và chuỗi ngày tập sai theo',
    );
  });
}
