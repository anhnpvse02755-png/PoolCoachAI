import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  test('tên bài đúng thuật ngữ chủ sản phẩm đã chốt (spec mục 5.1, 5.2, 11.3)', () {
    expect(Vi.buDrillName('F2'), 'Đánh đứng bi (Stop Shot)');
    expect(Vi.buDrillName('F3'), 'Đánh cu lê (Follow Shot)');
    expect(Vi.buDrillName('F4'), 'Đánh trô bi (Draw Shot)');
    expect(Vi.buDrillName('F5'), 'Đánh tâm tiến (Stun Shot)');
    expect(Vi.buDrillName('F6'), 'Ăn bi (Ball Pocketing)');
    expect(Vi.buDrillName('S5'), 'Phòng thủ / bắt đui (Safety)');
    expect(Vi.buDrillName('S6'), 'A băng (Kicks)');
    expect(Vi.buDrillName('S7'), 'Cân bi (Banks)');
    expect(Vi.buDrillName('S8'), 'Dựng cơ (Elevated cue)');
    expect(Vi.buDrillName('S9'), 'Nhảy bi (Jump) hoặc Mát xê (Massé)');
    expect(Vi.buDrillName('S10'), 'Phá (Break)');
  });

  test('mọi bài đều có tên, không dùng từ cấm', () {
    final all = [...examIDrills, ...examIIDrills(ExamIIVersion.doctorate)];
    for (final d in all) {
      final name = Vi.buDrillName(d.id).toLowerCase();
      for (final banned in ['kim cương', 'bi ma', 'lọt bi cái']) {
        expect(name, isNot(contains(banned)), reason: d.id);
      }
      expect(Vi.buDrillTitle(d.id), startsWith('${d.id} · '));
    }
  });

  test('8 câu hỏi, số lựa chọn khớp questionOptionCounts', () {
    for (var q = 1; q <= 8; q++) {
      expect(Vi.rankQuestion(q), isNotEmpty);
      expect(Vi.rankQuestionOptions(q).length, questionOptionCounts[q - 1], reason: 'Q$q');
    }
  });

  test('câu hỏi nguyên văn PoolOS v2 (spec mục 11.2)', () {
    expect(Vi.rankQuestion(5), 'Bạn đã từng Runout (đi chấm) chưa?');
    expect(Vi.rankQuestionOptions(6).last, 'Gần như rack nào cũng có thể');
    expect(Vi.rankQuestionOptions(3).last, 'Dọn bàn (Run Out)');
  });

  test('mỗi hạng có mô tả nguyên văn (spec mục 11.1)', () {
    expect(Vi.rankDescription(Rank.k), 'Người mới làm quen với Pool');
    expect(Vi.rankDescription(Rank.a), 'Top đầu trong nước');
    expect(Vi.rankDescription(Rank.pro), 'Thi đấu chuyên nghiệp');
    for (final r in Rank.values) {
      expect(Vi.rankDescription(r), isNotEmpty);
    }
  });

  test('mọi bài, mọi bản đều có cách chấm và cách xếp bài', () {
    for (final d in examIDrills) {
      expect(Vi.buDrillScoring(d.id, null), isNotEmpty, reason: d.id);
      expect(Vi.buDrillSetup(d.id, null), isNotEmpty, reason: d.id);
    }
    for (final v in ExamIIVersion.values) {
      for (final d in examIIDrills(v)) {
        expect(Vi.buDrillScoring(d.id, v), isNotEmpty, reason: '${d.id} $v');
        expect(Vi.buDrillSetup(d.id, v), isNotEmpty, reason: '${d.id} $v');
      }
    }
  });

  test('cách chấm theo đúng chữ của spec', () {
    expect(Vi.buDrillScoring('S3', ExamIIVersion.doctorate), contains('3–4 băng'));
    expect(Vi.buDrillScoring('S3', ExamIIVersion.bachelors), isNot(contains('3–4 băng')));
    expect(Vi.buDrillScoring('S4', ExamIIVersion.masters), contains('chướng ngại'));
    expect(Vi.buDrillScoring('S1', ExamIIVersion.masters), contains('không cần lượt 2'));
    expect(Vi.buBreakCriterion(0), 'a: không chết cái');
    expect(Vi.buBreakCriterion(4),
        'e: a, và có ít nhất 3 bi mục tiêu vào lỗ hoặc vượt qua vạch đầu bàn');
  });

  test('không chữ nào dùng từ cấm', () {
    final all = <String>[
      for (final d in examIDrills) ...[Vi.buDrillScoring(d.id, null), Vi.buDrillSetup(d.id, null)],
      for (final v in ExamIIVersion.values)
        for (final d in examIIDrills(v)) ...[Vi.buDrillScoring(d.id, v), Vi.buDrillSetup(d.id, v)],
    ];
    for (final s in all) {
      for (final banned in ['kim cương', 'bi ma', 'lọt bi cái']) {
        expect(s.toLowerCase(), isNot(contains(banned)), reason: s);
      }
    }
  });
}
