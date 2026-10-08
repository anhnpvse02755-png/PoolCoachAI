@Tags(['perf'])
library;

// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';

import '../../support/planner_tables.dart';

/// "Vài giây" trên Chrome giả lập điện thoại (spec cú phòng thủ mục 6), đọc là
/// ≤ 5 s: Chrome chậm khoảng gấp đôi VM, và lát 4 ms mỗi khung 16,7 ms cho
/// việc tìm khoảng một phần tư thời gian — 5000 / (2 × 4,2) ≈ 600 ms trên VM.
const safetyVmBudgetMs = 600;

void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  final tables = {
    'đui A băng': snookerOneRailTable(),
    'hết đường ăn': noPotTable(),
  };

  test('tìm cú thủ một mạch trên Dart VM: in thời gian, gác ≤ $safetyVmBudgetMs ms', () {
    planToEnd(railTable()); // làm nóng JIT
    final over = <String>[];
    for (final MapEntry(key: name, value: setup) in tables.entries) {
      final job = SafetyJob(contextOf(setup));
      final w = Stopwatch()..start();
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      final ms = w.elapsedMilliseconds;
      print('$name: $ms ms, ${job.simulations} lần dò/mô phỏng, '
          '${job.options.length} phương án, thử ${job.triedRailCounts.toList()..sort()} băng');
      if (ms > safetyVmBudgetMs) over.add('$name $ms ms');
    }
    expect(over, isEmpty, reason: 'quá $safetyVmBudgetMs ms: $over');
  });

  test('lát lúc tìm cú thủ giữ quanh sliceBudget; in p95 và lát dài nhất', () {
    planToEnd(railTable());
    final job = SafetyJob(contextOf(noPotTable()));
    final micros = <int>[];
    while (!job.isDone) {
      final w = Stopwatch()..start();
      job.step();
      micros.add(w.elapsedMicroseconds);
    }
    micros.sort();
    final median = micros[micros.length ~/ 2] / 1000;
    final p95 = micros[((micros.length - 1) * 0.95).floor()] / 1000;
    print('lát tìm cú thủ: trung vị $median ms, p95 $p95 ms, '
        'dài nhất ${micros.last / 1000} ms, ${micros.length} lát');
    expect(median, lessThan(sliceBudget.inMicroseconds / 1000 * 1.5));
  });
}
