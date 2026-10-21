import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/generator.dart';
import 'package:poolcoachai/domain/coach/rng.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/planner_tables.dart';

String layoutOf(TableSetup s) =>
    [s.cue, for (final b in s.balls) '${b.number}@${b.pos}'].join(' ');

/// Ràng buộc mục 8.3 cho mọi thế bàn sinh ra.
void expectRealistic(TableSetup s) {
  const table = TableSpec.nineFoot;
  expect(s.game, GameType.nineBall);
  final numbers = [for (final b in s.balls) b.number]..sort();
  expect(numbers.last, 9);
  for (var i = 0; i + 1 < numbers.length; i++) {
    expect(numbers[i + 1], numbers[i] + 1);
  }
  final all = [s.cue, for (final b in s.balls) b.pos];
  for (var i = 0; i < all.length; i++) {
    expect(table.contains(all[i]), isTrue);
    for (final p in Pocket.values) {
      expect(all[i].distanceTo(table.pocketPosition(p)), greaterThanOrEqualTo(coachMinPocketClearance));
    }
    for (var j = i + 1; j < all.length; j++) {
      expect(all[i].distanceTo(all[j]), greaterThanOrEqualTo(table.ballDiameter + coachBallGap));
    }
  }
  expect(s.cue.distanceTo(footSpot(table)), greaterThanOrEqualTo(table.ballDiameter));
}

CoachGenerateJob generate(CoachTopic topic, CoachDifficulty d, int seed) {
  final job = CoachGenerateJob(topic: topic, difficulty: d, seed: seed, safety: noSafetyPhysics);
  while (!job.isDone) {
    job.step(budget: const Duration(days: 1));
  }
  return job;
}

void main() {
  test('CoachRng khớp chuỗi chuẩn Park–Miller hệ số 48271: số thứ 10 000 từ seed 1 là 399 268 537', () {
    final rng = CoachRng(1);
    var x = 0;
    for (var i = 0; i < 10000; i++) {
      x = rng.next();
    }
    expect(x, 399268537);
    expect(CoachRng(1).next(), 48271);
  });

  test('CoachRng: seed 0 hay âm vẫn hợp lệ; số thực trong [0, 1)', () {
    for (final seed in [0, -5, CoachRng.modulus - 1, CoachRng.modulus * 3]) {
      final rng = CoachRng(seed);
      expect(rng.state, inInclusiveRange(1, CoachRng.modulus - 1));
      for (var i = 0; i < 100; i++) {
        final d = rng.nextDouble();
        expect(d, greaterThanOrEqualTo(0));
        expect(d, lessThan(1));
      }
    }
    expect(coachSeedFrom(DateTime(2026, 10, 21)), inInclusiveRange(1, CoachRng.modulus - 1));
  });

  test('cùng seed → cùng thế bàn', () {
    for (final topic in CoachTopic.values) {
      final a = proposeLayout(CoachRng(42), topic, CoachDifficulty.medium);
      final b = proposeLayout(CoachRng(42), topic, CoachDifficulty.medium);
      expect(a, isNotNull, reason: '$topic');
      expect(layoutOf(a!), layoutOf(b!));
    }
  });

  group('lượt hình học: mọi thế bàn qua ràng buộc mục 8.3 và điều kiện nhóm mục 8.5', () {
    for (final topic in CoachTopic.values) {
      for (final d in CoachDifficulty.values) {
        test('$topic $d', () {
          for (var seed = 1; seed <= 8; seed++) {
            final s = proposeLayout(CoachRng(seed * 7919), topic, d);
            expect(s, isNotNull, reason: 'seed $seed');
            expectRealistic(s!);
            expect(geometryFitsTopic(s, topic), isTrue);
            final target = legalTargetsAmong(s.game, s.balls).first;
            final best = bestPocket(cue: s.cue, object: target.pos, others: obstaclesFor(target, s.balls));
            switch (topic) {
              case CoachTopic.aiming || CoachTopic.position:
                // Độ khó đúng số bi và dải góc.
                final c = coachBallCount(d);
                expect(s.balls.length, inInclusiveRange(c.min, c.max));
                expect(coachCutBands(d), contains(bandFor(best!.angle)));
              case CoachTopic.safety || CoachTopic.kick:
                final c = coachBlockerCount(d);
                expect(s.balls.length - 1, inInclusiveRange(c.min, c.max));
                expect(best, isNull);
            }
          }
        });
      }
    }
  });

  test('sinh đủ hai lượt: Vị trí và Ngắm bi qua lượt vật lý, bước 0 là cú ăn thường', () {
    for (final topic in [CoachTopic.position, CoachTopic.aiming]) {
      final job = generate(topic, CoachDifficulty.easy, 20261021);
      expect(job.failed, isFalse, reason: '$topic');
      final s = job.result!;
      expect(s.key, generatedKey(topic, CoachDifficulty.easy, 20261021));
      expect(s.source, CoachSource.generated);
      expect(job.job!.reference!.kind, PlanStepKind.normal);
      // Cùng seed ban đầu → cùng tình huống cuối cùng, kể cả sau lượt vật lý.
      expect(layoutOf(generate(topic, CoachDifficulty.easy, 20261021).result!.setup), layoutOf(s.setup));
    }
  });

  test('Phòng thủ và A băng: không cần lượt vật lý', () {
    for (final topic in [CoachTopic.safety, CoachTopic.kick]) {
      final job = generate(topic, CoachDifficulty.medium, 99);
      expect(job.result, isNotNull);
      expect(job.physicsTries, 0);
    }
  });

  test('hết số lần thử thì báo thất bại (màn hình lấy thư viện)', () {
    // Lõi chết cái mọi cú: không thế bàn nào qua lượt vật lý.
    final job = CoachGenerateJob(
      topic: CoachTopic.position,
      difficulty: CoachDifficulty.easy,
      seed: 5,
      aim: scratchingAim((_, _, _, _) => true),
      safety: noSafetyPhysics,
    );
    while (!job.isDone) {
      job.step(budget: const Duration(days: 1));
    }
    expect(job.failed, isTrue);
    expect(job.result, isNull);
    expect(job.physicsTries, coachPhysicsTries);
  });
}
