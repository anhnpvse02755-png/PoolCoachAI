import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/reveal.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';

void main() {
  final rail = railTable();

  Reveal revealAfter(List<CoachAnswer> answers) {
    final job = gradeAll(rail, answers);
    return buildReveal(job.reference!, job.verdicts, safety: job.safetyShot);
  }

  test('xem đáp án khi chưa trả lời: cú tốt nhất, vùng của nó, không lý do nào khác', () {
    final r = revealAfter(const []);
    expect(r.kind, RevealKind.pot);
    expect(r.best!.key.stroke, Stroke.stun);
    expect(r.best!.key.power, 45);
    expect(r.spin, isNull);
    expect(r.reasons, hasLength(1));
    expect(r.reasons.single, isA<ReasonZone>().having((z) => z.next, 'next', 2));
    expect(r.railCount, 1);
    expect(r.toleranceGood, isNotNull);
    expect(r.missSide, isNotNull);
  });

  test('cũng đạt: tối đa coachEquivalentsShown cú, không có cú tốt nhất', () {
    final r = revealAfter(const []);
    expect(r.equivalents.length, lessThanOrEqualTo(coachEquivalentsShown));
    expect(r.equivalents.map((o) => o.key.power), [60]);
  });

  test('lý do chỉ có khi khoản điểm thật sự khác', () {
    // Đứng bi 75 %: cùng vùng, cùng kiểu đánh, chỉ khác lực.
    final power = revealAfter([pot(rail, Pocket.bottomMiddle, Stroke.stun, 75)]);
    expect(power.reasons.whereType<ReasonPower>().single.yours, 75);
    expect(power.reasons.whereType<ReasonStroke>(), isEmpty);
    expect(power.reasons.whereType<ReasonNoSpin>(), isEmpty);
    expect(power.reasons.whereType<ReasonYourZone>(), isEmpty);

    // Cu lê 30 %: khác vùng và khác kiểu đánh.
    final stroke = revealAfter([pot(rail, Pocket.bottomMiddle, Stroke.follow, 30)]);
    expect(stroke.reasons.whereType<ReasonYourZone>().single.zone, CoachZone.fair);
    expect(stroke.reasons.whereType<ReasonStroke>().single.yours, Stroke.follow);
    expect(stroke.reasons.whereType<ReasonPower>(), isEmpty);

    // Áp phê thừa: lý do áp phê, không có lý do kiểu đánh.
    final spin = revealAfter([
      pot(rail, Pocket.bottomMiddle, Stroke.stun, 45, spin: const SideSpin(SpinSide.left, 0.5)),
    ]);
    expect(spin.reasons.whereType<ReasonNoSpin>(), hasLength(1));
    expect(spin.reasons.whereType<ReasonStroke>(), isEmpty);

    // Cú hỏng: hậu quả cụ thể.
    final blocked = revealAfter([pot(rail, Pocket.bottomLeft, Stroke.follow, 30)]);
    expect(blocked.reasons.whereType<ReasonYourBlocked>().single.blocker, 2);
  });

  test('có áp phê thì dữ liệu SAWS dùng đúng step.sawsBhePercent và sawsSpeed', () {
    final ball1 = rail.balls.first.pos;
    final job = gradeAll(rail, const [],
        aim: scratchingAim((object, _, spin, _) => object == ball1 && spin.isNone));
    final r = buildReveal(job.reference!, job.verdicts);
    final step = job.reference!.step;
    expect(r.spin, isNotNull);
    expect(r.spin!.bhe, step.sawsBhePercent);
    expect(
        r.spin!.bhe,
        sawsBhePercent(
            distance: step.cbFrom.distanceTo(step.geometry!.ghost), power: step.power, stroke: step.stroke));
    expect(r.spin!.speed, sawsSpeed(step.power));
    expect(r.spin!.side, step.spin.side);
    expect(r.spin!.tips, step.spin.tips);
  });

  test('bước phòng thủ: đáp án là cú thủ của Planner', () {
    final s = noPotTable();
    final job = gradeAll(s, const [SafetyAnswer()]);
    final r = buildReveal(job.reference!, job.verdicts);
    expect(r.kind, RevealKind.safety);
    expect(r.best, isNull);
  });

  test('chưa đủ dữ liệu ăn hay thủ: hiện cú ăn và cú thủ', () {
    final t = typicalNineBallTable();
    final job = gradeAll(t, const [SafetyAnswer()], safety: const SafetyPhysics());
    final r = buildReveal(job.reference!, job.verdicts, safety: job.safetyShot);
    expect(r.kind, RevealKind.potVsSafety);
    expect(r.best, isNotNull);
    expect(r.safety, isNotNull);
  });
}
