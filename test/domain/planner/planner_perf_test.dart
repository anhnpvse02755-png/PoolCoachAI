@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';

import '../../support/planner_tables.dart';

void main() {
  test('bước 1 của bàn 9 bi điển hình ra dưới 500 ms trên Dart VM', () {
    planToEnd(railTable()); // làm nóng JIT
    final millis = <int>[];
    for (var i = 0; i < 3; i++) {
      final job = PlannerJob(typicalNineBallTable());
      final w = Stopwatch()..start();
      while (job.steps.isEmpty) {
        job.step(budget: const Duration(days: 1), maxSimulations: 1);
      }
      millis.add(w.elapsedMilliseconds);
    }
    millis.sort();
    // Chrome chậm khoảng gấp đôi VM (đo ở kế hoạch lõi vật lý): 500 ms ở
    // đây là khoảng 1 giây trên Chrome giả lập điện thoại (spec mục 10.3).
    expect(millis[1], lessThan(500), reason: '$millis');
  });

  test('lát điển hình giữ quanh sliceBudget; in p95 và lát dài nhất', () {
    planToEnd(railTable());
    final job = PlannerJob(typicalNineBallTable());
    final micros = <int>[];
    while (!job.isDone) {
      final w = Stopwatch()..start();
      job.step();
      micros.add(w.elapsedMicroseconds);
    }
    micros.sort();
    final median = micros[micros.length ~/ 2] / 1000;
    final p95 = micros[((micros.length - 1) * 0.95).floor()] / 1000;
    // Một đơn vị việc là một lần aimShot, không chia nhỏ được nữa: lần dài
    // nhất đo được 47 ms trên VM (c43c74a). Nên chỉ gác trung vị ở đây; p95
    // in ra để ghi vào nhật ký, cổng khung hình thật nằm ở planner.mjs.
    // ignore: avoid_print
    print('lát: trung vị $median ms, p95 $p95 ms, dài nhất ${micros.last / 1000} ms, '
        '${micros.length} lát');
    expect(median, lessThan(sliceBudget.inMicroseconds / 1000 * 1.5));
  });
}
