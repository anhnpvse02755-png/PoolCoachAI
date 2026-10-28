import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/features/play/presentation/match_analysis_sheet.dart';
import 'package:poolcoachai/features/stats/presentation/match_analysis_card.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/certification_summary.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

import '../support/match_fixtures.dart';
import '../support/roadmap_fixtures.dart';
import '../support/skill_test_fixtures.dart';
import '../support/test_data.dart';

final _today = DateTime(2026, 9, 17);

/// Dựng người chơi yếu đúng một nhóm: tập kém ở nhóm đó, tốt ở nhóm khác.
///
/// [lapsed] đẩy mọi buổi lùi về hơn một tuần trước, tức người chơi đang
/// đứt chuỗi. Mặc định là vừa tập hôm nay, để luật "sắp mất streak"
/// không che mất luật "nhóm yếu" mà các test dưới đang xét.
List<DrillLog> _playerWeakAt(SkillCategory weakCat, {bool lapsed = false}) {
  final logs = <DrillLog>[];
  var n = 0;

  for (final drill in seedDrills) {
    if (!drill.usesAttempts) continue;
    final poor = drill.cat == weakCat;
    for (var i = 0; i < 3; i++) {
      n++;
      logs.add(
        DrillLog(
          id: 'l$n',
          drillId: drill.id,
          date: _today.subtract(Duration(days: (lapsed ? 10 : 2) - i)),
          score: poor ? 2 : 10,
          attempts: 10,
        ),
      );
    }
  }
  return logs;
}

void main() {
  group('lớp suy luận bám dữ liệu, không viết cứng', () {
    test('đổi nhóm yếu trong dữ liệu thì kết luận đổi theo', () {
      for (final weakCat in [SkillCategory.position, SkillCategory.safety]) {
        final pi = computePlayerIntelligence(
          drills: seedDrills,
          logs: _playerWeakAt(weakCat),
        );

        expect(
          pi.weak.first,
          weakCat,
          reason: 'dữ liệu nói yếu $weakCat nhưng kết luận lại khác',
        );
      }
    });

    test('gợi ý hôm nay đi theo nhóm yếu, không cố định một nhóm', () {
      final picks = <SkillCategory>{};

      for (final weakCat in [SkillCategory.position, SkillCategory.safety]) {
        final rec = computeRecommendation(
          drills: seedDrills,
          logs: _playerWeakAt(weakCat),
          knowledge: seedKnowledge,
          timerSessions: const [],
          schedule: const [],
          today: _today,
        );

        expect(rec.reason, PickReason.weakest);
        expect(rec.cat, weakCat);
        picks.add(rec.cat);
      }

      expect(
        picks.length,
        2,
        reason: 'hai người chơi yếu khác nhau mà nhận cùng một gợi ý',
      );
    });

    test('người đã bỏ tập cả tuần thì luật streak thắng luật nhóm yếu', () {
      // Không phải lỗi: spec xếp luật 2 trên luật 3 có chủ ý — kéo người
      // quay lại bàn quan trọng hơn việc hôm đó tập đúng nhóm yếu.
      final rec = computeRecommendation(
        drills: seedDrills,
        logs: _playerWeakAt(SkillCategory.position, lapsed: true),
        knowledge: seedKnowledge,
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.reason, PickReason.streakAtRisk);
    });

    test('chưa đủ dữ liệu thì nói không biết, không đoán', () {
      final pi = computePlayerIntelligence(
        drills: seedDrills,
        logs: [
          DrillLog(
            id: 'l1',
            drillId: seedDrills.first.id,
            date: _today,
            score: 9,
            attempts: 10,
          ),
        ],
      );

      expect(pi.weak, isEmpty);
      expect(pi.strong, isEmpty);
      for (final insight in pi.categories.values) {
        if (insight.sessionCount < 3) {
          expect(insight.mastery, isNull);
        }
      }
    });
  });

  group('Lộ trình bám dữ liệu, không viết cứng (spec 2026-10-15 mục 9)', () {
    final rank = PlayerRank(
      rank: Rank.h,
      source: RankSource.estimated,
      onboardingState: OnboardingState.done,
      updatedAt: _today,
    );
    final goal = PlayerGoal(
      goalId: 'g',
      kind: GoalKind.lenHang,
      createdAt: _today,
    );

    Roadmap roadmapFor(List<DrillLog> logs, {BuResult? result}) => buildRoadmap(
      goal: goal,
      rank: rank,
      drills: seedDrills,
      logs: logs,
      tests: const [],
      latestResult: result,
      today: _today,
    );

    test('hai người yếu hai nhóm khác nhau nhận hai lộ trình khác nhau', () {
      final position = roadmapFor(_playerWeakAt(SkillCategory.position));
      final safety = roadmapFor(_playerWeakAt(SkillCategory.safety));
      expect(position.steps.first.category, SkillCategory.position);
      expect(safety.steps.first.category, SkillCategory.safety);
      expect(
        Vi.stepTitle(position.steps.first),
        isNot(Vi.stepTitle(safety.steps.first)),
      );
    });

    test('đổi điểm mất BU thì câu lý do đổi theo', () {
      BuResult result(Map<String, int> lost) =>
          BuResult(testId: 't', completedAt: _today, total: 50, lost: lost);
      final aiming = roadmapFor(const [], result: result(const {'F7': 20}));
      final safety = roadmapFor(const [], result: result(const {'S5': 12}));
      expect(Vi.stepReason(aiming.steps.first.reason), contains('20'));
      expect(Vi.stepReason(safety.steps.first.reason), contains('12'));
      expect(
        Vi.stepReason(aiming.steps.first.reason),
        isNot(Vi.stepReason(safety.steps.first.reason)),
      );
    });
  });

  group(
    'phân tích trận bám dữ liệu, không viết cứng (spec 2026-10-28 mục 8)',
    () {
      final aimingMatches = matchesWeakAt(SkillCategory.aiming, at: _today);
      final positionMatches = matchesWeakAt(SkillCategory.position, at: _today);

      test('gợi ý hôm nay đổi theo nhóm yếu trong trận', () {
        TodayRecommendation rec(List<PoolMatch> m) => computeRecommendation(
          drills: seedDrills,
          logs: const [],
          knowledge: seedKnowledge,
          timerSessions: const [],
          schedule: const [],
          today: _today,
          matches: m,
        );
        final a = rec(aimingMatches);
        final p = rec(positionMatches);
        expect(a.reason, PickReason.matchWeakness);
        expect(p.reason, PickReason.matchWeakness);
        expect(a.cat, SkillCategory.aiming);
        expect(p.cat, SkillCategory.position);
        final sa = Vi.pickReason(
          a.reason,
          Vi.skill(a.cat),
          signal: a.matchSignal,
        );
        final sp = Vi.pickReason(
          p.reason,
          Vi.skill(p.cat),
          signal: p.matchSignal,
        );
        expect(sa, contains(Vi.skill(SkillCategory.aiming)));
        expect(sp, contains(Vi.skill(SkillCategory.position)));
        expect(sa, isNot(sp));
      });

      Future<void> pumpHome(
        WidgetTester tester,
        ProviderContainer container,
      ) async {
        final router = createAppRouter(auth: signedInGate());
        addTearDown(router.dispose);
        addTearDown(container.dispose);
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: PoolCoachApp(router: router),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets(
        'Home nêu đúng nhóm yếu trong trận, đổi dữ liệu thì đổi câu',
        (tester) async {
          for (final (cat, ms) in [
            (
              SkillCategory.aiming,
              matchesWeakAt(SkillCategory.aiming, at: testToday),
            ),
            (
              SkillCategory.position,
              matchesWeakAt(SkillCategory.position, at: testToday),
            ),
          ]) {
            final container = testContainer(matches: ms, now: testToday);
            await pumpHome(tester, container);
            final rec = container
                .read(todayRecommendationProvider)
                .requireValue;
            expect(rec.cat, cat);
            expect(rec.reason, PickReason.matchWeakness);
            expect(
              find.text(
                Vi.pickReason(
                  rec.reason,
                  Vi.skill(cat),
                  signal: rec.matchSignal,
                ),
              ),
              findsOneWidget,
            );
          }
        },
      );

      testWidgets(
        'Home: nhóm chỉ yếu theo BU (không bài tập, không trận) được nêu',
        (tester) async {
          final bu = buResultGraded(
            completedAt: DateTime(2026, 9, 1),
            lost: const {'F7': 20, 'F6': 10},
          );
          final container = testContainer(buResult: bu, now: testToday);
          await pumpHome(tester, container);
          final pi = container.read(playerIntelligenceProvider)!;
          expect(pi.categories[SkillCategory.aiming]!.mastery, isNull);
          expect(pi.buPercent[SkillCategory.aiming], lessThan(55));
          final rec = container.read(todayRecommendationProvider).requireValue;
          expect(rec.reason, PickReason.weakest);
          expect(rec.cat, SkillCategory.aiming);
          expect(
            find.text(
              Vi.pickReason(PickReason.weakest, Vi.skill(SkillCategory.aiming)),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('thẻ Thống kê đổi theo nhóm yếu', (tester) async {
        Future<void> pumpCard(List<PoolMatch> ms) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MatchAnalysisCard(analysis: analyzeMatches(ms)),
              ),
            ),
          ),
        );
        await pumpCard(aimingMatches);
        final aiming = analyzeMatches(aimingMatches)
            .signals[SkillCategory.aiming]!;
        expect(
          find.text(
            Vi.statsMatchWeak(
              Vi.skill(SkillCategory.aiming),
              aiming.failures,
              aiming.attempts,
              percentOf(aiming.failures, aiming.attempts)!,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('${Vi.skill(SkillCategory.position)}: hỏng'),
          findsNothing,
        );

        await pumpCard(positionMatches);
        final position = analyzeMatches(positionMatches)
            .signals[SkillCategory.position]!;
        expect(
          find.text(
            Vi.statsMatchWeak(
              Vi.skill(SkillCategory.position),
              position.failures,
              position.attempts,
              percentOf(position.failures, position.attempts)!,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('${Vi.skill(SkillCategory.aiming)}: hỏng'),
          findsNothing,
        );
      });

      testWidgets('bảng Phân tích trận đổi theo nhóm yếu của trận', (
        tester,
      ) async {
        Future<void> pumpView(PoolMatch m) {
          final analysis = analyzeMatches([m]);
          return tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MatchAnalysisView(
                    match: m,
                    analysis: analysis,
                    focus: singleMatchFocus(
                      analysis,
                      drills: seedDrills,
                      logs: const [],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final a = aimingMatches.first;
        await pumpView(a);
        final sa = analyzeMatches([a]).signals[SkillCategory.aiming]!;
        final aimingLine = Vi.matchAnalysisFocus(
          Vi.skill(SkillCategory.aiming),
          sa.failures,
          sa.attempts,
        );
        expect(find.text(aimingLine), findsOneWidget);

        final p = positionMatches.first;
        await pumpView(p);
        final sp = analyzeMatches([p]).signals[SkillCategory.position]!;
        expect(
          find.text(
            Vi.matchAnalysisFocus(
              Vi.skill(SkillCategory.position),
              sp.failures,
              sp.attempts,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(aimingLine), findsNothing);
      });

      test('fact chat đổi theo', () {
        String weakOf(List<PoolMatch> ms) {
          final facts = buildCoachContext(
            pi: computePlayerIntelligence(drills: seedDrills, logs: const []),
            rank: null,
            currentStep: null,
            attempts: const [],
            today: null,
            matches: ms,
          ).toFacts();
          final analysis = (facts['matches']! as Map)['analysis']! as Map;
          return ((analysis['weak']! as List).first as Map)['category']!
              as String;
        }

        expect(weakOf(aimingMatches), 'aiming');
        expect(weakOf(positionMatches), 'position');
      });

      test('thứ tự bước Lộ trình Chuẩn bị giải đổi theo', () {
        Roadmap tournament(List<PoolMatch> ms) => buildRoadmap(
          goal: PlayerGoal(
            goalId: 'g',
            kind: GoalKind.chuanBiGiai,
            eventDate: _today.add(const Duration(days: 30)),
            createdAt: _today,
          ),
          rank: PlayerRank(
            rank: Rank.h,
            source: RankSource.estimated,
            onboardingState: OnboardingState.done,
            updatedAt: _today,
          ),
          drills: seedDrills,
          logs: const [],
          tests: const [],
          latestResult: null,
          today: _today,
          matches: ms,
        );
        final a = tournament(aimingMatches);
        final p = tournament(positionMatches);
        expect(a.steps.first.category, SkillCategory.aiming);
        expect(p.steps.first.category, SkillCategory.position);
        expect(Vi.stepTitle(a.steps.first), isNot(Vi.stepTitle(p.steps.first)));
      });
    },
  );

  group('Skill Test bám dữ liệu, không viết cứng (spec 2026-10-28 skill test mục 8)', () {
    String line(String id, List<DrillLog> logs, List<SkillTest> tests) =>
        Vi.skillTestGateLine(
          skillTestGate(
            drill: stById(id),
            drills: stDrills,
            logs: logs,
            tests: tests,
          ),
          nameOf: (d) => stById(d).name,
        );

    test('lý do khoá hoặc mở bài kiểm tra đổi theo dữ liệu', () {
      final lines = {
        line('a1', const [], const []),
        line('a1', threePasses('a1').skip(1).toList(), const []),
        line('a1', threePasses('a1'), const []),
        line('a1', threePasses('a1'), [
          failedTest('a1', 1, stToday.subtract(const Duration(hours: 2))),
        ]),
        line('a1', threePasses('a1'), [passedTest('a1', 1, stToday)]),
      };
      expect(lines, hasLength(5));
      expect(
        line('a3', threePasses('a3'), const []),
        contains(stById('a1').name),
      );
      expect(
        line('p3', threePasses('p3'), [passedTest('p2a', 2, stToday)]),
        contains(stById('p2b').name),
      );
    });

    test(
      'gợi ý ở Hồ sơ và dòng ở Trang chủ đi theo nhật ký và bài kiểm tra',
      () {
        CertificationSummary summary(
          List<DrillLog> logs,
          List<SkillTest> tests,
        ) => certificationSummary(drills: stDrills, logs: logs, tests: tests);
        List<String> ready(List<DrillLog> logs, List<SkillTest> tests) =>
            testableDrillIds(drills: stDrills, logs: logs, tests: tests);

        expect(summary(const [], const []).closest, isNull);
        expect(summary(const [], const []).groups, isEmpty);
        expect(ready(const [], const []), isEmpty);

        final two = summary(
          threePasses('a1').skip(1).toList(),
          const [],
        ).closest!;
        expect((two.drill.id, two.passCount), ('a1', 2));
        expect(ready(threePasses('a1').skip(1).toList(), const []), isEmpty);

        expect(ready(threePasses('a1'), const []), ['a1']);
        expect(summary(threePasses('a1'), const []).closest!.passCount, 3);

        final certified = [passedTest('a1', 1, stToday)];
        expect(ready(threePasses('a1'), certified), isEmpty);
        expect(
          summary(
            threePasses('a1'),
            certified,
          ).groups.single.entries.single.drill.id,
          'a1',
        );
        expect(
          Vi.certificationEntry('Bai a1', 1, stToday),
          contains(
            summary(
              threePasses('a1'),
              certified,
            ).groups.single.entries.single.drill.name,
          ),
        );
      },
    );
  });
}
