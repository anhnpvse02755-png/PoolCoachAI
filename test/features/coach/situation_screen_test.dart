import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_attempt_repository.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/coach/presentation/situation_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';
import '../../support/test_data.dart';

/// Lưu giả: ghi lại lần làm thay vì ghi Drift.
class SpyRepo extends CoachAttemptRepository {
  SpyRepo() : super(AppDatabase.forTesting(NativeDatabase.memory()), userId: 'u1');
  final saved = <CoachAttempt>[];

  @override
  Future<void> record(CoachAttempt attempt) async => saved.add(attempt);
}

void main() {
  // pos-rail-1 là railTable chép sang chấm. Tìm câu trả lời đúng và sai
  // bằng chính lõi Coach (lõi giả tức thì), không viết tay đáp án.
  final setup = railTable();
  final candidates = <PotAnswer>[
    for (final p in Pocket.values)
      for (final s in strokeCandidates)
        for (final w in powerCandidates) pot(setup, p, s, w),
  ];
  final graded = gradeAll(setup, candidates, aim: fakeAim);
  final wrongs = <PotAnswer>[
    for (var i = 0; i < candidates.length; i++)
      if (graded.verdicts[i].outcome == CoachOutcome.wrong) candidates[i],
  ];
  final pass = candidates[graded.verdicts.indexWhere((v) => v.passed)];

  Future<SpyRepo> open(WidgetTester tester, {CoachEngine? engine, Size size = const Size(1000, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = SpyRepo();
    final container = testContainer(coachRepo: repo, coachEngine: engine);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: SituationScreen(request: SituationRequest.parse(const {'lib': 'pos-rail-1'})),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, PotAnswer a) async {
    await tap(tester, SituationScreen.potKey);
    await tap(tester, SituationScreen.pocketKey(a.pocket));
    await tap(tester, SituationScreen.strokeKey(a.stroke));
    await tap(tester, SituationScreen.powerKey(a.power));
  }

  Future<void> submit(WidgetTester tester) => tap(tester, SituationScreen.submitKey);

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(SituationScreen.submitKey)).onPressed != null;

  testWidgets('Chấm chỉ bật khi đã đủ lựa chọn', (tester) async {
    await open(tester);
    expect(find.text(Vi.coachPrompt(1)), findsOneWidget);
    expect(submitEnabled(tester), isFalse);
    await tap(tester, SituationScreen.potKey);
    await tap(tester, SituationScreen.pocketKey(Pocket.bottomMiddle));
    await tap(tester, SituationScreen.strokeKey(Stroke.stun));
    expect(submitEnabled(tester), isFalse);
    await tap(tester, SituationScreen.powerKey(45));
    expect(submitEnabled(tester), isTrue);
    // Phòng thủ không cần thông số nào.
    await tap(tester, SituationScreen.safetyKey);
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('chạm lỗ trên bàn và chạm chip lỗ cho cùng kết quả', (tester) async {
    await open(tester);
    final rect = tester.getRect(find.byKey(SituationScreen.tableKey));
    final layout = TableLayout(size: rect.size);
    for (final p in [Pocket.topLeft, Pocket.bottomMiddle]) {
      // Chạm lệch khỏi tâm lỗ một chút, vẫn trong vùng chạm.
      final at = rect.topLeft + layout.toCanvas(TableSpec.nineFoot.pocketPosition(p)) + const Offset(6, 6);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(find.byKey(SituationScreen.pocketKey(p)));
      expect(chip.selected, isTrue, reason: '$p');
    }
    await tap(tester, SituationScreen.pocketKey(Pocket.topRight));
    expect(tester.widget<ChoiceChip>(find.byKey(SituationScreen.pocketKey(Pocket.topRight))).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.byKey(SituationScreen.pocketKey(Pocket.bottomMiddle))).selected,
        isFalse);
  });

  testWidgets('sai 1 → gợi ý 1 → sai 2 → gợi ý 2 → sai 3 → đáp án, lưu "revealed"', (tester) async {
    expect(wrongs.length, greaterThanOrEqualTo(coachMaxAnswers));
    final repo = await open(tester);
    await choose(tester, wrongs[0]);
    await submit(tester);
    expect(find.text(Vi.coachVerdict(const CoachVerdict(outcome: CoachOutcome.wrong))), findsOneWidget);
    expect(find.text(Vi.coachTryCount(2, coachMaxAnswers)), findsOneWidget);
    expect(find.text(Vi.coachRevealTitle), findsNothing);

    await choose(tester, wrongs[1]);
    await submit(tester);
    expect(find.text(Vi.coachTryCount(3, coachMaxAnswers)), findsOneWidget);
    expect(find.text(Vi.coachRevealTitle), findsNothing);

    await choose(tester, wrongs[2]);
    await submit(tester);
    expect(find.text(Vi.coachRevealTitle), findsOneWidget);
    expect(find.text(Vi.coachNext), findsOneWidget);
    expect(repo.saved.single.outcome, CoachAttemptOutcome.revealed);
    expect(repo.saved.single.answers, hasLength(3));
  });

  testWidgets('đạt thì hiện Lời giải và lưu solved1', (tester) async {
    final repo = await open(tester);
    await choose(tester, pass);
    await submit(tester);
    expect(find.text(Vi.coachSolutionTitle), findsOneWidget);
    expect(repo.saved.single.outcome, CoachAttemptOutcome.solved1);
  });

  testWidgets('Xem đáp án sớm → hỏi lại → revealedEarly', (tester) async {
    final repo = await open(tester);
    await tap(tester, SituationScreen.showAnswerKey);
    expect(find.text(Vi.coachShowAnswerConfirm), findsOneWidget);
    await tester.tap(find.text(Vi.coachShowAnswerNo));
    await tester.pumpAndSettle();
    expect(repo.saved, isEmpty);
    await tap(tester, SituationScreen.showAnswerKey);
    await tester.tap(find.text(Vi.coachShowAnswerYes));
    await tester.pumpAndSettle();
    expect(find.text(Vi.coachRevealTitle), findsOneWidget);
    expect(repo.saved.single.outcome, CoachAttemptOutcome.revealedEarly);
  });

  testWidgets('chọn lại đúng cú vừa sai thì không tính lần thử', (tester) async {
    await open(tester);
    await choose(tester, wrongs[0]);
    await submit(tester);
    expect(find.text(Vi.coachTryCount(2, coachMaxAnswers)), findsOneWidget);
    await submit(tester);
    expect(find.text(Vi.coachSameAnswer), findsOneWidget);
    expect(find.text(Vi.coachTryCount(2, coachMaxAnswers)), findsOneWidget);
  });

  testWidgets('chưa đủ dữ liệu (lõi quá giờ) thì không tính lần thử', (tester) async {
    AimedShot slowAim({
      required Vec2 cue,
      required Vec2 object,
      required Pocket pocket,
      required Stroke stroke,
      SideSpin spin = const SideSpin.none(),
      required double power,
      CueElevation elevation = CueElevation.normal,
      TableSpec table = TableSpec.nineFoot,
      bool compensate = true,
      bool withUncompensated = true,
      double maxTime = maxSimTime,
    }) {
      if (stroke == Stroke.draw && power == 90) {
        throw SimulationTimeout(ShotInput(cue: cue, object: object, aimAngle: 0, power: power));
      }
      return fakeAim(cue: cue, object: object, pocket: pocket, stroke: stroke, spin: spin, power: power);
    }

    await open(tester,
        engine: CoachEngine(aim: slowAim, safety: noSafetyPhysics, budget: const Duration(days: 1)));
    await choose(tester, pot(setup, Pocket.bottomMiddle, Stroke.draw, 90));
    await submit(tester);
    expect(
        find.text(Vi.coachVerdict(const CoachVerdict(
            outcome: CoachOutcome.undecided, undecided: CoachUndecidedReason.timeout))),
        findsOneWidget);
    expect(find.text(Vi.coachTryCount(1, coachMaxAnswers)), findsOneWidget);
  });

  testWidgets('điện thoại 360 × 640: không tràn; vùng chạm lỗ ≥ 24 px', (tester) async {
    await open(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byKey(SituationScreen.tableKey));
    final layout = TableLayout(size: rect.size);
    expect(layout.touchReach(5.5) * layout.scale, greaterThanOrEqualTo(TableLayout.minTouchPx));
    await choose(tester, wrongs[0]);
    await submit(tester);
    expect(tester.takeException(), isNull);
  });
}
