import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/sim_cache.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';

import '../../support/planner_tables.dart';

void main() {
  final setup = railTable();
  final g = CandidateFinder(game: setup.game).easiest(setup.cue, setup.balls)!.geometry;
  final key = shotKey(g, Stroke.stun, 45);

  test('chưa có thì ném MissingSimulation đúng khoá; fill xong thì tra được', () {
    final cache = SimCache();
    expect(cache.contains(key), isFalse);
    expect(() => cache.lookup(key),
        throwsA(isA<MissingSimulation>().having((m) => m.key, 'key', key)));
    cache.fill(key);
    expect(cache.contains(key), isTrue);
    expect(cache.length, 1);
    final a = cache.lookup(key)!;
    expect(a.trace.cueEnd, simulateKey(key)!.trace.cueEnd);
  });

  test('quá giờ thì nhớ null — tra ra null, không ném', () {
    final cache = SimCache();
    cache.fill(key, aim: timeoutAim((_, _, _, _) => true));
    expect(cache.contains(key), isTrue);
    expect(cache.lookup(key), isNull);
  });

  test('PlannerJob dùng chung SimCache vẫn cho kế hoạch y hệt khi không dùng chung', () {
    for (final s in [railTable(), cornerFollowTable(), typicalNineBallTable()]) {
      final alone = fingerprint(planToEnd(s, safety: noSafetyPhysics));
      final shared = SimCache();
      final job = PlannerJob(s, safety: noSafetyPhysics, cache: shared);
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      expect(fingerprint(job.steps), alone);
      expect(shared.length, greaterThan(0));
      // Chạy lại trên cache đã đầy: không mô phỏng thêm lần nào.
      final before = shared.length;
      final again = PlannerJob(s, safety: noSafetyPhysics, cache: shared);
      while (!again.isDone) {
        again.step(budget: const Duration(days: 1));
      }
      expect(fingerprint(again.steps), alone);
      expect(shared.length, before);
    }
  });
}
