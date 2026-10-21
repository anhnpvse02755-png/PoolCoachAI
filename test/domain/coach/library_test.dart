import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/generator.dart';
import 'package:poolcoachai/domain/coach/library.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/planner/sim_cache.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/planner_tables.dart';

void main() {
  const table = TableSpec.nineFoot;

  test('id không trùng; mỗi nhóm có ít nhất một mục', () {
    final ids = [for (final e in coachLibrary) e.id];
    expect(ids.toSet(), hasLength(ids.length));
    for (final t in CoachTopic.values) {
      expect(coachLibrary.where((e) => e.topic == t), isNotEmpty, reason: '$t');
    }
  });

  for (final e in coachLibrary) {
    group(e.id, () {
      final s = e.setup();

      test('vị trí hợp lệ theo mục 8.3 (sơ đồ BU: bỏ luật số liên tiếp, luật lỗ và khe bi)', () {
        final all = [s.cue, for (final b in s.balls) b.pos];
        for (var i = 0; i < all.length; i++) {
          expect(table.contains(all[i]), isTrue, reason: '${all[i]}');
          for (var j = i + 1; j < all.length; j++) {
            // Bi chạm nhau thì được (cụm bi xếp sát của BU), chồng nhau thì không.
            final minGap = e.fromBu ? table.ballDiameter - 1e-6 : table.ballDiameter + coachBallGap;
            expect(all[i].distanceTo(all[j]), greaterThanOrEqualTo(minGap), reason: '$i–$j');
          }
          if (!e.fromBu) {
            for (final p in Pocket.values) {
              expect(all[i].distanceTo(table.pocketPosition(p)),
                  greaterThanOrEqualTo(coachMinPocketClearance));
            }
          }
        }
        if (!e.fromBu) {
          final numbers = [for (final b in s.balls) b.number]..sort();
          for (var i = 0; i + 1 < numbers.length; i++) {
            expect(numbers[i + 1], numbers[i] + 1);
          }
          expect(e.game, GameType.nineBall);
        }
      });

      test('tham chiếu của CoachJob khớp nhóm theo điều kiện mục 8.5', () {
        final job = CoachJob(s, safety: noSafetyPhysics);
        while (!job.referenceReady) {
          job.step(budget: const Duration(days: 1));
        }
        bool accepts() {
          while (true) {
            try {
              return acceptsForTopic(e.topic, job.reference!, job.cache.lookup);
            } on MissingSimulation catch (m) {
              job.cache.fill(m.key);
            }
          }
        }

        expect(accepts(), isTrue,
            reason: '${e.id}: ${job.reference!.kind}, khớp hình học: '
                '${[for (final t in CoachTopic.values) if (geometryFitsTopic(s, t)) t.name]}');
      });

      test('khoá và nguồn', () {
        final sit = e.situation(CoachDifficulty.medium);
        expect(sit.key, libraryKey(e.id));
        expect(sit.source, CoachSource.library);
        expect(e.source, isNotEmpty);
      });
    });
  }

  test('hết số lần thử: ưu tiên mục chưa làm, không có thì mục đầu, nhóm trống thì null', () {
    final position = [for (final e in coachLibrary) if (e.topic == CoachTopic.position) e];
    expect(fallbackEntry(CoachTopic.position, const {})!.id, position.first.id);
    expect(fallbackEntry(CoachTopic.position, {libraryKey(position.first.id)})!.id,
        position.length > 1 ? position[1].id : position.first.id);
    expect(fallbackEntry(CoachTopic.position, {for (final e in position) libraryKey(e.id)})!.id,
        position.first.id);
  });
}

