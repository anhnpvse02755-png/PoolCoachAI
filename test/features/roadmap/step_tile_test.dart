import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/features/roadmap/presentation/step_tile.dart';

import '../../support/layout_sweep.dart';

void main() {
  final today = DateTime(2026, 10, 15);

  Future<void> pumpTile(
    WidgetTester tester,
    RoadmapStep step, {
    VoidCallback? onPickSkill,
  }) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                StepTile(
                  step: step,
                  drill: null,
                  today: today,
                  onPickSkill: onPickSkill,
                ),
              ],
            ),
          ),
        ),
      );

  RoadmapStep milestone({DateTime? from, bool retake = true}) => RoadmapStep(
        kind: StepKind.lamBaiBu,
        status: StepStatus.dangLam,
        reason: RankMilestone(Rank.g, from: from, retake: retake),
      );

  testWidgets('mốc đang làm, cổng mở: có nút làm bài kiểm tra', (tester) async {
    await pumpTile(tester, milestone(from: DateTime(2026, 10, 1)));
    expect(find.text('Làm lại bài BU — mốc hạng G'), findsOneWidget);
    expect(find.text(Vi.stepOpenTest), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mốc đang làm, chưa có cổng: có nút làm bài kiểm tra', (tester) async {
    await pumpTile(tester, milestone(retake: false));
    expect(find.text('Làm bài BU — mốc hạng G'), findsOneWidget);
    expect(find.text(Vi.stepOpenTest), findsOneWidget);
  });

  testWidgets('mốc đang làm, cổng đóng: hiện ngày mở, không có nút', (tester) async {
    await pumpTile(tester, milestone(from: DateTime(2026, 11, 3)));
    expect(find.text('Mở từ ngày 03/11/2026.'), findsOneWidget);
    expect(find.text(Vi.stepOpenTest), findsNothing);
  });

  testWidgets('360x640 chữ x2: tên bước mốc dài nhất không tràn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    await pumpTile(tester, milestone(from: DateTime(2026, 11, 3)));
    expect(find.text('Làm lại bài BU — mốc hạng G'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  RoadmapStep s9Step({List<String> ids = const ['S9']}) => RoadmapStep(
        kind: StepKind.buLe,
        status: StepStatus.dangLam,
        reason: LostBuPoints(6, ids),
        buDrillIds: ids,
      );

  testWidgets('bước Tập lại S9: có dòng hướng dẫn và nút chọn nhóm', (tester) async {
    var picked = 0;
    await pumpTile(tester, s9Step(), onPickSkill: () => picked++);
    expect(find.text(Vi.roadmapS9Hint), findsOneWidget);
    await tester.tap(find.text(Vi.roadmapS9Pick));
    expect(picked, 1);
  });

  testWidgets('bước nhóm thường: không có dòng S9', (tester) async {
    await pumpTile(
      tester,
      s9Step(ids: const ['S8']),
      onPickSkill: () {},
    );
    expect(find.text(Vi.roadmapS9Hint), findsNothing);
    expect(find.text(Vi.roadmapS9Pick), findsNothing);
  });

  testWidgets('360x640 chữ x1.5: dòng S9 và nút không tràn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 1.5);
    await pumpTile(tester, s9Step(), onPickSkill: () {});
    expect(find.text(Vi.roadmapS9Hint), findsOneWidget);
    expect(find.text(Vi.roadmapS9Pick), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
