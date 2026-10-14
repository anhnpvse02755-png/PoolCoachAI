import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

Iterable<Cham> _points(LayoutMark m) => switch (m) {
      ObjectBall(:final at) || CueBall(:final at) || SpotRing(:final at) || LadderPosition(:final at) => [at],
      TargetZone(:final from, :final to) => [from, to],
      AimPath(:final points) => points,
      CueBallInHand() || TargetPocket() => const [],
    };

void main() {
  const table = TableSpec.nineFoot;

  group('toạ độ chấm (spec mục 5.5)', () {
    test('gốc trên trái, x dọc băng dài 0–8, y từ băng trên 0–4', () {
      expect(chamToTable(const Cham(0, 0), table), const Vec2(0, 0));
      expect(chamToTable(const Cham(8, 4), table), Vec2(table.length, table.width));
      expect(chamToTable(const Cham(4, 2), table), Vec2(table.length / 2, table.width / 2));
    });

    test('chấm của sáu lỗ khớp vị trí lỗ của bàn', () {
      for (final p in Pocket.values) {
        expect(chamToTable(pocketCham(p), table), table.pocketPosition(p), reason: '$p');
      }
    });

    test('lerpCham và evenlySpaced', () {
      expect(lerpCham(const Cham(0, 0), const Cham(8, 4), 0.5), const Cham(4, 2));
      expect(evenlySpaced(const Cham(1, 1), const Cham(7, 1), 4),
          const [Cham(1, 1), Cham(3, 1), Cham(5, 1), Cham(7, 1)]);
      expect(evenlySpaced(const Cham(1, 1), const Cham(7, 1), 1), const [Cham(1, 1)]);
    });
  });

  test('ví dụ đã đo của spec: Bachelors S3 thế 1 (trang 3)', () {
    final s3 = layoutsFor('S3', ExamIIVersion.bachelors).firstWhere((l) => l.variant == 1);
    expect(s3.source, 'BU_Exam-II_Skills-Bachelors.pdf, trang 3');
    expect(s3.marks, const [
      CueBallInHand(),
      ObjectBall(5, Cham(1, 1)),
      ObjectBall(8, Cham(3, 1)),
      ObjectBall(9, Cham(5, 1)),
      ObjectBall(7, Cham(1, 3)),
      ObjectBall(6, Cham(3, 3)),
      SpotRing(Cham(6, 2)),
    ]);
  });

  group('đủ sơ đồ cho mọi bài', () {
    test('mỗi bài Đề I và mỗi bài của từng bản Đề II có ít nhất một sơ đồ', () {
      for (final d in examIDrills) {
        expect(layoutsFor(d.id, null), isNotEmpty, reason: d.id);
      }
      for (final v in ExamIIVersion.values) {
        for (final d in examIIDrills(v)) {
          expect(layoutsFor(d.id, v), isNotEmpty, reason: '${d.id} $v');
        }
      }
    });

    test('S3, S4: đúng 3 thế mỗi bản (phiếu điểm "layout 1 2 3")', () {
      for (final v in ExamIIVersion.values) {
        for (final id in ['S3', 'S4']) {
          expect(layoutsFor(id, v).map((l) => l.variant).toList(), [1, 2, 3], reason: '$id $v');
        }
      }
    });

    test('thang vị trí F1–F5: đủ vị trí 1–7, mỗi vị trí một lần', () {
      for (final id in ['F1', 'F2', 'F3', 'F4', 'F5']) {
        for (final l in layoutsFor(id, null)) {
          final positions = l.marks.whereType<LadderPosition>().map((m) => m.position).toList()..sort();
          expect(positions, [1, 2, 3, 4, 5, 6, 7], reason: id);
        }
      }
    });
  });

  group('mọi sơ đồ đều hợp lệ', () {
    final source = RegExp(
        r'^BU_Exam-(I_Fundamentals|II_Skills-(Bachelors|Masters|Doctorate))\.pdf, trang \d+$');

    test('nguồn ghi đúng file và trang', () {
      for (final l in allLayouts()) {
        expect(l.source, matches(source), reason: '${l.drillId} ${l.version} ${l.variant}');
        if (l.version != null) {
          final name = switch (l.version!) {
            ExamIIVersion.bachelors => 'Bachelors',
            ExamIIVersion.masters => 'Masters',
            ExamIIVersion.doctorate => 'Doctorate',
          };
          expect(l.source, contains(name), reason: '${l.drillId} ${l.version}');
        } else {
          expect(l.source, contains('Fundamentals'), reason: l.drillId);
        }
      }
    });

    test('mọi điểm nằm trong lưới 8 × 4', () {
      for (final l in allLayouts()) {
        for (final p in l.marks.expand(_points)) {
          expect(p.x, inInclusiveRange(0, 8), reason: '${l.drillId} $p');
          expect(p.y, inInclusiveRange(0, 4), reason: '${l.drillId} $p');
        }
      }
    });

    test('số bi 1–15, không trùng; nhiều nhất một bi cái', () {
      for (final l in allLayouts()) {
        final numbers = l.marks.whereType<ObjectBall>().map((b) => b.number).toList();
        expect(numbers.every((n) => n >= 1 && n <= 15), isTrue, reason: l.drillId);
        expect(numbers.toSet().length, numbers.length, reason: l.drillId);
        final cues = l.marks.where((m) => m is CueBall || m is CueBallInHand).length;
        expect(cues, lessThanOrEqualTo(1), reason: l.drillId);
      }
    });

    test('các bi không chồng lên nhau', () {
      for (final l in allLayouts()) {
        final centres = [
          for (final m in l.marks)
            if (m case ObjectBall(:final at) || CueBall(:final at)) chamToTable(at, table),
        ];
        for (var i = 0; i < centres.length; i++) {
          for (var j = i + 1; j < centres.length; j++) {
            expect(centres[i].distanceTo(centres[j]), greaterThanOrEqualTo(table.ballDiameter - 0.01),
                reason: '${l.drillId} ${l.version} ${l.variant}');
          }
        }
      }
    });
  });

  test('chọn sơ đồ theo lượt: S3 lượt 1, 2, 3 → thế 1, 2, 3', () {
    final s3 = drillFor('S3', ExamIIVersion.masters);
    expect([for (var i = 0; i < 3; i++) layoutForAttempt(s3, ExamIIVersion.masters, i).variant], [1, 2, 3]);
    final f1 = drillFor('F1', null);
    expect(layoutForAttempt(f1, null, 9).drillId, 'F1');
  });
}
