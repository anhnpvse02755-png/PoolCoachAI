import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('dữ liệu khởi tạo', () {
    test('có đúng 19 bài tập và 6 bài kiến thức', () {
      expect(seedDrills.length, 19);
      expect(seedKnowledge.length, 6);
    });

    test('mã bài tập không trùng nhau', () {
      final ids = seedDrills.map((d) => d.id).toSet();
      expect(ids.length, seedDrills.length);
    });

    test('mỗi bài tập chấm được điểm', () {
      for (final drill in seedDrills) {
        expect(
          drill.passThreshold != null || drill.target != null,
          isTrue,
          reason: 'bài ${drill.id} không có cách chấm điểm',
        );
      }
    });

    test('cấp độ nằm trong 1..5', () {
      for (final drill in seedDrills) {
        expect(drill.level, inInclusiveRange(1, 5), reason: drill.id);
      }
    });

    test('mỗi bài tập có mục tiêu và ít nhất một bước', () {
      for (final drill in seedDrills) {
        expect(drill.goal.trim(), isNotEmpty, reason: drill.id);
        expect(drill.steps, isNotEmpty, reason: drill.id);
      }
    });

    test('không còn thuật ngữ cũ trong bất kỳ bài tập nào', () {
      const banned = [
        'Stop shot',
        'stop shot',
        'dừng bi',
        'Draw',
        'kéo bi',
        'Follow',
        'đẩy bi cái theo',
        'Bi băng',
        'Giao bóng',
        'giao bóng',
        'Đi bi',
        'đi bi',
      ];
      for (final drill in seedDrills) {
        final haystack =
            '${drill.name} ${drill.goal} ${drill.steps.join(' ')}';
        for (final term in banned) {
          expect(
            haystack.contains(term),
            isFalse,
            reason: 'bài ${drill.id} còn dùng "$term"',
          );
        }
      }
    });

    test('không còn thuật ngữ cũ trong bài kiến thức', () {
      const banned = [
        'Bi băng',
        'Giao bóng',
        'giao bóng',
        'Đi bi',
        'đi bi',
      ];
      for (final article in seedKnowledge) {
        final haystack = '${article.title} ${article.body}';
        for (final term in banned) {
          expect(
            haystack.contains(term),
            isFalse,
            reason: 'bài ${article.id} còn dùng "$term"',
          );
        }
      }
    });

    test('mỗi nhóm kỹ năng có ít nhất một bài tập', () {
      for (final cat in SkillCategory.values) {
        expect(
          seedDrills.any((d) => d.cat == cat),
          isTrue,
          reason: 'nhóm $cat chưa có bài nào',
        );
      }
    });

    test('bài mới: nguồn, cấp, số cú, bước 1 đều suy từ bảng nguồn và BU', () {
      for (final d in seedDrills) {
        final p = drillProvenanceOf(d.id);
        if (p == null) {
          expect(int.parse(d.id.substring(1)), lessThanOrEqualTo(10));
          continue;
        }
        expect(d.cat.isAdvanced, isTrue);
        expect(d.target, drillFor(p.buDrillId, p.version).attemptCount);
        expect(d.target, p.shots);
        if (p.buDrillId == 'S8') {
          expect(d.target, layoutsFor('S8', p.version).length);
        }
        expect(d.level, p.version.index + 1);
        expect(d.passThreshold, isNull);
        expect(d.name, '${Vi.skill(d.cat)} — bậc ${Vi.buVersionName(p.version)}');
        expect(d.unit, 'cú thành công / ${d.target}');
        expect(d.steps.first, Vi.buDrillSetup(p.buDrillId, p.version));
      }
      expect(
        [for (final d in seedDrills) if (drillProvenanceOf(d.id) != null) d.id],
        ['d11', 'd12', 'd13', 'd14', 'd15', 'd16', 'd17', 'd18', 'd19'],
      );
      expect(
        [
          for (final id in ['d11', 'd14', 'd17'])
            seedDrills.firstWhere((d) => d.id == id).cat,
        ],
        [SkillCategory.dungCo, SkillCategory.nhayBi, SkillCategory.matXe],
      );
    });

    test('số cú không viết tay: file seed chỉ có bốn target số cũ', () {
      final src = File('lib/data/seed/seed_drills.dart').readAsStringSync();
      expect(RegExp(r'target:\s*\d').allMatches(src).length, 4);
    });

    test('bài nâng cao không có từ kỹ thuật tiếng Anh', () {
      const english = [
        'Jump', 'jump', 'Massé', 'Masse', 'masse', 'Scratch', 'scratch',
        'miscue', 'Elevated',
      ];
      for (final d in seedDrills.where((d) => d.cat.isAdvanced)) {
        final text = '${d.name} ${d.goal} ${d.steps.join(' ')}';
        for (final w in english) {
          expect(text.contains(w), isFalse, reason: '${d.id}: $w');
        }
      }
    });

    test('bậc Doctorate của S9 giữ yêu cầu đưa bi cái vào lỗ góc', () {
      for (final id in ['d16', 'd19']) {
        expect(
          seedDrills.firstWhere((d) => d.id == id).steps.last,
          contains('bi cái vào lỗ góc (chết cái)'),
        );
      }
    });

    test('cảnh báo nỉ/bàn có ở mọi bài Nhảy bi và Mát xê, không có ở Dựng cơ', () {
      for (final d in seedDrills.where((d) => d.cat.isAdvanced)) {
        final t = d.steps.join(' ');
        final warns = t.contains('Nhiều giải giới hạn') ||
            t.contains('rách nỉ');
        expect(warns, d.cat != SkillCategory.dungCo, reason: d.id);
      }
    });
  });
}
