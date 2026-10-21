// ignore_for_file: avoid_print
@Tags(['probe'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/generator.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Không phải test: sinh tình huống mỗi nhóm từ các seed cố định, in khoá, vị
/// trí bi theo chấm và cú tốt nhất — để người soạn chọn thế đẹp cho thư viện
/// (spec mục 9.3). Chạy riêng bằng:
///   flutter test --tags probe --run-skipped test/domain/coach/generator_probe_test.dart
void main() {
  String cham(Vec2 p) => '(${(p.x / 31.75).toStringAsFixed(3)}, ${(p.y / 31.75).toStringAsFixed(3)})';

  for (final topic in CoachTopic.values) {
    test('$topic', () {
      for (var seed = 1; seed <= 6; seed++) {
        final gen = CoachGenerateJob(topic: topic, difficulty: CoachDifficulty.medium, seed: seed * 1009);
        while (!gen.isDone) {
          gen.step(budget: const Duration(days: 1));
        }
        final s = gen.result;
        if (s == null) {
          print('${topic.name} seed ${seed * 1009}: không sinh được');
          continue;
        }
        final job = gen.job!;
        while (!job.referenceReady) {
          job.step(budget: const Duration(days: 1));
        }
        final ref = job.reference!;
        final best = ref.best;
        print('${s.key}: cue ${cham(s.setup.cue)} '
            '${[for (final b in s.setup.balls) '${b.number}${cham(b.pos)}'].join(' ')} → '
            '${ref.kind.name} ${ref.step.pocket?.name ?? ''} '
            '${best == null ? '' : '${best.key.stroke.name} ${best.key.power} ${best.score.total.toStringAsFixed(2)}'}');
      }
    });
  }
}
