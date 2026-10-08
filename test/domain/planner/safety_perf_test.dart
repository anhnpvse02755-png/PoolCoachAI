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
/// ≤ 5 s tới lúc bước thủ hiện ra. Chrome chậm khoảng gấp đôi VM; lát
/// [safetySliceBudget] 12 ms mỗi khung 16,7 ms cho việc tìm khoảng 12/16,7
/// thời gian — 5000 / (2 × 16,7 / 12) ≈ 1800 ms trên VM.
const safetyVmBudgetMs = 1800;

void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  final tables = {
    'đui A băng': snookerOneRailTable(),
    'hết đường ăn': noPotTable(),
    '8 bi thủ': eightSafetyTable(),
  };

  test('tìm cú thủ trên Dart VM: bước hiện ra gác ≤ $safetyVmBudgetMs ms; '
      'in cả lượt đầy đủ', () {
    planToEnd(railTable()); // làm nóng JIT
    final over = <String>[];
    for (final MapEntry(key: name, value: setup) in tables.entries) {
      final job = SafetyJob(contextOf(setup));
      final w = Stopwatch()..start();
      // Từng đơn vị việc như PlannerJob: lượt thô xong mà có cú thì bước
      // hiện ra (điểm hỏi hay cú tạm); không có cú thì ở cuối lượt đầy đủ.
      while (!job.coarseDone) {
        job.work();
      }
      final coarseMs = w.elapsedMilliseconds;
      final coarseUnits = job.simulations;
      final rough = job.coarseResult;
      final asked = job.atCheckpoint;
      job.resume();
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      final fullMs = w.elapsedMilliseconds;
      final firstMs = rough == null ? fullMs : coarseMs;
      print('$name: bước hiện sau $firstMs ms '
          '(${rough == null ? 'lượt thô không có cú' : asked ? 'dừng hỏi' : 'cú tạm'}; '
          'lượt thô $coarseUnits lần); lượt đầy đủ xong sau $fullMs ms, ${job.simulations} lần, '
          '${job.coarseOptions.length} + ${job.options.length} phương án, '
          'thử ${job.triedRailCounts.toList()..sort()} băng'
          '${rough != null && !identical(job.result, rough) ? ', thay cú' : ''}');
      if (firstMs > safetyVmBudgetMs) over.add('$name $firstMs ms');
    }
    expect(over, isEmpty, reason: 'bước thủ hiện ra quá $safetyVmBudgetMs ms: $over');
  });

  test('lát lúc tìm cú thủ giữ quanh safetySliceBudget; in p95 và lát dài nhất', () {
    planToEnd(railTable());
    final job = SafetyJob(contextOf(noPotTable()));
    final micros = <int>[];
    while (!job.isDone) {
      job.resume();
      final w = Stopwatch()..start();
      job.step();
      micros.add(w.elapsedMicroseconds);
    }
    micros.sort();
    final median = micros[micros.length ~/ 2] / 1000;
    final p95 = micros[((micros.length - 1) * 0.95).floor()] / 1000;
    print('lát tìm cú thủ: trung vị $median ms, p95 $p95 ms, '
        'dài nhất ${micros.last / 1000} ms, ${micros.length} lát');
    expect(median, lessThan(safetySliceBudget.inMicroseconds / 1000 * 1.5));
  });
}
