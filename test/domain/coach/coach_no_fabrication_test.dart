import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/chat_filter.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/coach_recommendation.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/hints.dart';
import 'package:poolcoachai/domain/coach/library.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/reveal.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/coach/presentation/coach_lines.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';
import 'coach_recommendation_test.dart' show playerWeakAt, todayFor;

/// Mọi câu Coach dựng được cho [job]: kết luận, hai gợi ý của từng câu trả
/// lời, và đáp án sau từng câu.
List<String> allLines(CoachJob job) {
  final ref = job.reference!;
  final out = <String>[];
  for (var i = 0; i < job.verdicts.length; i++) {
    final v = job.verdicts[i];
    out.add(Vi.coachVerdict(v));
    if (hintOne(v, ref) case final h?) out.add(Vi.coachHintOne(h));
    if (hintTwo(v, ref) case final h?) out.add(Vi.coachHintTwo(h.hint));
    final reveal = buildReveal(ref, job.verdicts.sublist(0, i + 1), safety: job.safetyShot);
    out.addAll(revealLines(reveal, searchingSafety: false));
    out.addAll(reveal.reasons.map(Vi.coachReason));
  }
  return out;
}

void main() {
  test('1. đổi bàn thì câu đổi: hai bàn chỉ khác vị trí bi chắn → gợi ý 1 nêu đúng bi chắn', () {
    final base = railTable();
    final key = shotKey(contextFor(base).geometry, Stroke.stun, 45);
    final path = simulateKey(key)!.trace.cueAfter;
    final onPath = path[path.length ~/ 2];
    const away = Vec2(30, 20);
    TableSetup board(Vec2 three, Vec2 four) => TableSetup(
          game: GameType.nineBall,
          cue: base.cue,
          balls: [
            ...base.balls,
            PlacedBall(number: 3, pos: three),
            PlacedBall(number: 4, pos: four),
          ],
        );
    final answer = pot(base, Pocket.bottomMiddle, Stroke.stun, 45);
    final a = gradeAll(board(onPath, away), [answer]);
    final b = gradeAll(board(away, onPath), [answer]);
    final va = a.verdicts.single, vb = b.verdicts.single;
    expect(va.fault, CoachFault.blocked);
    expect(vb.fault, CoachFault.blocked);
    expect(va.blocker, 3);
    expect(vb.blocker, 4);
    final ha = Vi.coachHintOne(hintOne(va, a.reference!)!);
    final hb = Vi.coachHintOne(hintOne(vb, b.reference!)!);
    expect(ha, contains('bi 3'));
    expect(hb, contains('bi 4'));
    expect(ha, isNot(hb));
  });

  test('2. đổi câu trả lời thì kết luận đổi: cả 15 cú tầng 1 khớp điểm và lý do loại của cú đó', () {
    for (final s in [railTable(), cornerFollowTable()]) {
      final pocket = contextFor(s).geometry.pocket;
      final answers = [
        for (final st in strokeCandidates)
          for (final p in powerCandidates) pot(s, pocket, st, p),
      ];
      final job = gradeAll(s, answers);
      final ref = job.reference!;
      final lookup = directLookup();
      for (var i = 0; i < answers.length; i++) {
        final a = answers[i];
        final v = job.verdicts[i];
        final aimed = lookup(a.key(cue: s.cue, object: s.balls.first.pos));
        final rejection = aimed == null ? null : rejectionOf(aimed, pocket, [for (final b in ref.after) b.pos]);
        final scored = ref.scored.where((o) => a.matches(o.key)).firstOrNull;
        if (rejection != null) {
          expect(v.passed, isFalse, reason: '${a.stroke} ${a.power}: bị loại thì không bao giờ đạt');
          expect(v.fault, switch (rejection) {
            Rejection.scratch => CoachFault.scratch,
            Rejection.objectMissed => CoachFault.objectMissed,
            Rejection.blocked => CoachFault.blocked,
          });
          expect(hintOne(v, ref), switch (rejection) {
            Rejection.scratch => isA<HintScratch>(),
            Rejection.objectMissed => isA<HintMissed>(),
            Rejection.blocked => isA<HintBlocker>(),
          });
        } else if (scored != null) {
          expect(v.passed, scored.score.total <= ref.best!.score.total + coachScoreTolerance);
          expect(v.playerScore!.total, scored.score.total);
        }
      }
    }
  });

  test('3. đổi nhóm yếu thì Coach đổi', () {
    final topics = <CoachTopic>{};
    for (final weak in [SkillCategory.position, SkillCategory.safety]) {
      final logs = playerWeakAt(weak);
      final rec = computeCoachRecommendation(
        today: todayFor(logs),
        pi: computePlayerIntelligence(drills: seedDrills, logs: logs),
        attempts: const [],
        articles: seedKnowledge,
      );
      expect(rec.topic, coachTopicOf(weak));
      topics.add(rec.topic);
    }
    expect(topics, hasLength(2));
  });

  group('4. không có số độ, không "ngắm lệch", không "tối ưu"', () {
    void check(Iterable<String> lines) {
      for (final l in lines) {
        expect(coachBannedRule(l), isNull, reason: l);
      }
    }

    test('trên ba bàn thật: mọi lỗ × mọi kiểu đánh × mọi áp phê, cộng Phòng thủ', () {
      for (final s in [railTable(), cornerFollowTable(), typicalNineBallTable()]) {
        final answers = <CoachAnswer>[
          for (final p in Pocket.values)
            for (final st in strokeCandidates)
              for (final spin in const [SideSpin.none(), SideSpin(SpinSide.left, 0.5), SideSpin(SpinSide.right, 1)])
                pot(s, p, st, 45, spin: spin),
          const SafetyAnswer(),
        ];
        check(allLines(gradeAll(s, answers)));
      }
    });

    test('bàn phòng thủ và bàn tầng áp phê', () {
      check(allLines(gradeAll(noPotTable(), [pot(noPotTable(), Pocket.topRight, Stroke.stun, 45), const SafetyAnswer()])));
      final rail = railTable();
      final ball1 = rail.balls.first.pos;
      check(allLines(gradeAll(rail, [pot(rail, Pocket.bottomMiddle, Stroke.stun, 45)],
          aim: scratchingAim((o, _, spin, _) => o == ball1 && spin.isNone))));
    });

    test('mọi dữ liệu gợi ý, lý do, nhóm lỗi, mọi lỗ', () {
      check([
        for (final p in Pocket.values) ...[
          Vi.coachHintOne(HintPathBlocked(1, p)),
          Vi.coachHintOne(HintTooThin(p)),
          Vi.coachHintOne(HintGhostOff(p)),
          Vi.coachHintOne(HintScratch(p)),
          Vi.coachHintOne(HintMissed(1, p)),
          Vi.coachReason(ReasonYourScratch(p)),
          Vi.coachReason(ReasonYourMissed(1, p)),
          Vi.coachReason(ReasonYourUnmakeable(1, p)),
          for (final st in Stroke.values) Vi.coachRevealShot(1, p, st, 60),
        ],
        for (final g in CoachFaultGroup.values) Vi.coachFaultGroup(g),
        for (final z in CoachZone.values) Vi.coachReason(ReasonZone(z, 2)),
        for (final side in SpinSide.values)
          for (final speed in SawsSpeed.values) Vi.coachRevealSpin((side: side, tips: 1, bhe: 70, speed: speed)),
      ]);
    });
  });

  test('5. áp phê theo mẫu SAWS: BHE bằng sawsBhePercent tính độc lập', () {
    for (final s in [railTable(), cornerFollowTable()]) {
      final ball1 = s.balls.first.pos;
      final job = gradeAll(s, const [], aim: scratchingAim((o, _, spin, _) => o == ball1 && spin.isNone));
      final ref = job.reference!;
      final reveal = buildReveal(ref, job.verdicts);
      final step = ref.step;
      expect(step.spin.isNone, isFalse);
      final bhe = sawsBhePercent(
          distance: step.cbFrom.distanceTo(step.geometry!.ghost), power: step.power, stroke: step.stroke);
      final line = revealLines(reveal, searchingSafety: false).firstWhere((l) => l.contains('BHE'));
      expect(line, contains('ngắm như đánh tâm bi'));
      expect(line, contains('$bhe% BHE'));
      expect(line, contains('${100 - bhe}% FHE'));
      expect(['nhẹ', 'trung bình', 'mạnh'].any(line.contains), isTrue);
    }
  });

  test('6. chưa đủ dữ liệu là nói thẳng', () {
    final timeout = gradeOne(railTable(), pot(railTable(), Pocket.bottomMiddle, Stroke.draw, 60),
        aim: timeoutAim((_, stroke, _, power) => stroke == Stroke.draw && power == 60));
    final potVsSafety = gradeOne(typicalNineBallTable(), const SafetyAnswer());
    for (final v in [timeout, potVsSafety]) {
      final line = Vi.coachVerdict(v);
      expect(line, startsWith('Chưa đủ dữ liệu'));
      expect(line, isNot(startsWith('Đạt')));
      expect(line, isNot(startsWith('Chưa đạt')));
      expect(v.counts, isFalse);
    }
  });

  test('7. thư viện không có đáp án: dời bi cái của một mục → đáp án đổi', () {
    final entry = coachLibraryEntry('pos-rail-1')!;
    final s = entry.situation(CoachDifficulty.easy).setup;
    final moved = s.withCue(const Vec2(30, 115));
    final a = runCoachJob(CoachJob(s, safety: noSafetyPhysics)).reference!;
    final b = runCoachJob(CoachJob(moved, safety: noSafetyPhysics)).reference!;
    final ka = a.best!.key, kb = b.best!.key;
    expect([ka.pocket, ka.stroke, ka.power], isNot([kb.pocket, kb.stroke, kb.power]));
    final la = revealLines(buildReveal(a, const []), searchingSafety: false);
    final lb = revealLines(buildReveal(b, const []), searchingSafety: false);
    expect(la.first, isNot(lb.first));
  });
}
