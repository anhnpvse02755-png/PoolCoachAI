// ignore_for_file: avoid_print
@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/generator.dart';
import 'package:poolcoachai/domain/coach/library.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';

int median(List<int> xs) => (xs.toList()..sort())[xs.length ~/ 2];
int p95(List<int> xs) => (xs.toList()..sort())[((xs.length - 1) * 0.95).round()];

/// Cổng bằng một nửa số Chrome (spec mục 13), như planner_perf_test.
void main() {
  setUpAll(() => planToEnd(railTable())); // làm nóng JIT

  for (final topic in CoachTopic.values) {
    test('$topic: 20 seed cố định, tới khi có tham chiếu — trung vị ≤ 750 ms, p95 ≤ 1500 ms', () {
      final millis = <int>[];
      final slices = <int>[];
      for (var i = 1; i <= 20; i++) {
        final w = Stopwatch()..start();
        final gen = CoachGenerateJob(topic: topic, difficulty: CoachDifficulty.medium, seed: i * 104729);
        while (!gen.isDone) {
          final s = Stopwatch()..start();
          gen.step();
          slices.add(s.elapsedMicroseconds);
        }
        final job = gen.job ?? CoachJob(coachLibrary.firstWhere((e) => e.topic == topic).setup());
        while (!job.referenceReady) {
          final s = Stopwatch()..start();
          job.step();
          slices.add(s.elapsedMicroseconds);
        }
        millis.add(w.elapsedMilliseconds);
        job.cancel();
      }
      print('$topic tham chiếu ms: trung vị ${median(millis)}, p95 ${p95(millis)}, '
          'max ${millis.reduce((a, b) => a > b ? a : b)}; lát µs trung vị ${median(slices)}');
      expect(median(millis), lessThanOrEqualTo(750));
      expect(p95(millis), lessThanOrEqualTo(1500));
      expect(median(slices), lessThanOrEqualTo(sliceBudget.inMicroseconds * 3 ~/ 2));
    });
  }

  test('chấm câu trả lời khác lỗ Planner: trung vị ≤ 250 ms', () {
    final millis = <int>[];
    for (final e in coachLibrary.where((e) => e.topic == CoachTopic.position || e.topic == CoachTopic.aiming)) {
      final s = e.setup();
      final job = CoachJob(s, safety: noSafetyPhysics);
      while (!job.referenceReady) {
        job.step(budget: const Duration(days: 1));
      }
      final ref = job.reference!;
      for (final p in Pocket.values) {
        if (p == ref.step.pocket) continue;
        job.submit(pot(s, p, Stroke.follow, 60));
        final w = Stopwatch()..start();
        while (job.pending > 0) {
          job.step(budget: const Duration(days: 1));
        }
        millis.add(w.elapsedMilliseconds);
      }
    }
    print('chấm khác lỗ ms: trung vị ${median(millis)}, p95 ${p95(millis)}, n ${millis.length}');
    expect(median(millis), lessThanOrEqualTo(250));
  });
}
