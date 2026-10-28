import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/features/profile/presentation/certification_section.dart';

import '../../support/layout_sweep.dart';
import '../../support/route_cases.dart';
import '../../support/skill_test_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester, ProviderContainer c) async {
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CertificationSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có chứng nhận: nói thẳng và gợi ý bài gần sẵn sàng nhất', (
    tester,
  ) async {
    await pumpSection(
      tester,
      testContainer(logs: threePasses('d1', before: testToday).skip(1).toList()),
    );
    expect(find.text(Vi.certificationEmpty), findsOneWidget);
    expect(
      find.text(Vi.certificationClosest('Đường thẳng cơ bản', 2)),
      findsOneWidget,
    );
  });

  testWidgets('chưa có buổi đạt nào: không bịa gợi ý', (tester) async {
    await pumpSection(tester, testContainer(logs: [stLog('d1', 2, testToday)]));
    expect(find.text(Vi.certificationEmpty), findsOneWidget);
    expect(find.text(Vi.certificationNoProgress), findsOneWidget);
    expect(find.textContaining('Gần sẵn sàng nhất'), findsNothing);
  });

  testWidgets(
    'có chứng nhận: nhóm kỹ năng, tên bài, cấp, ngày; nhóm đủ bài là thuần thục',
    (tester) async {
      await pumpSection(
        tester,
        testContainer(skillTests: [passedTest('d1', 1, testToday)]),
      );
      expect(find.text(Vi.skill(SkillCategory.aiming)), findsOneWidget);
      expect(
        find.text(Vi.certificationEntry('Đường thẳng cơ bản', 1, testToday)),
        findsOneWidget,
      );
      expect(find.text(Vi.certificationGroupDone), findsOneWidget);
      expect(find.text(Vi.skillTestNoNextLevel), findsOneWidget);
      expect(find.text(Vi.certificationEmpty), findsNothing);
    },
  );

  testWidgets('mỗi chứng nhận nêu tiêu chí đã chấm, lấy từ ảnh chụp', (
    tester,
  ) async {
    final snapshot = SkillTest(
      id: 'snap',
      drillId: 'd1',
      drillLevel: 1,
      tableSize: passedTest('d1', 1, testToday).tableSize,
      startedAt: testToday.subtract(const Duration(minutes: 20)),
      completedAt: testToday,
      score: 9,
      attempts: 10,
      passed: true,
      // Khác tiêu chí 0.8 hiện tại của bài: dòng phải theo ảnh chụp.
      passThreshold: 0.6,
    );
    await pumpSection(tester, testContainer(skillTests: [snapshot]));
    expect(
      find.text(Vi.criterionSnapshot(0.6, null, 'lần trúng / 10')!),
      findsOneWidget,
    );
    expect(find.textContaining('80%'), findsNothing);
  });

  testWidgets('đọc lỗi: nói thẳng là chưa tải được', (tester) async {
    await pumpSection(
      tester,
      testContainer(
        skillTestsAsync: AsyncError<List<SkillTest>>(
          StateError('x'),
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text(Vi.skillTestDataError), findsOneWidget);
    expect(find.text(Vi.certificationEmpty), findsNothing);
  });

  testWidgets('đang tải: chưa hiện gì, không nói "chưa có chứng nhận"', (
    tester,
  ) async {
    final c = testContainer(
      skillTestsAsync: const AsyncLoading<List<SkillTest>>(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(body: CertificationSection()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(Vi.certificationEmpty), findsNothing);
    expect(find.text(Vi.certificationTitle), findsNothing);
  });

  testWidgets('Hồ sơ có mục Chứng nhận ngay sau thẻ Thiết bị', (tester) async {
    applyScreen(tester, const Size(800, 1600));
    final router = await pumpRoutedApp(
      tester,
      container: testContainer(skillTests: [passedTest('d1', 1, testToday)]),
    );
    router.go(Routes.profile);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text(Vi.certificationTitle)).dy,
      greaterThan(tester.getTopLeft(find.text(Vi.equipmentTitle)).dy),
    );
    expect(
      tester.getTopLeft(find.text(Vi.certificationTitle)).dy,
      lessThan(tester.getTopLeft(find.text(Vi.rankHistoryTitle)).dy),
    );
  });

  testWidgets('360×640 chữ lớn: Hồ sơ có chứng nhận không tràn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    final router = await pumpRoutedApp(
      tester,
      container: testContainer(skillTests: [passedTest('d1', 1, testToday)]),
    );
    router.go(Routes.profile);
    await tester.pumpAndSettle();
    final entry = find.text(
      Vi.certificationEntry('Đường thẳng cơ bản', 1, testToday),
    );
    await tester.dragUntilVisible(
      entry,
      find.byType(ListView),
      const Offset(0, -150),
    );
    expect(entry, findsOneWidget);
    expect(tester.takeException(), isNull);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });
}
