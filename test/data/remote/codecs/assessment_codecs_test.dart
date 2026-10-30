import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/remote/codecs/assessment_codecs.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/rank.dart';

DateTime plus7(DateTime utc) => utc.add(const Duration(hours: 7));

void main() {
  test('BU: lần kiểm tra và kết quả đọc đúng; attempts hỏng ném khi giải mã', () {
    final t = buTestFromRemote({
      'id': 'b1',
      'started_at': '2026-10-13T01:02:03.000Z',
      'completed_at': '2026-10-13T02:00:00.000Z',
      'cancelled_at': null,
      'table_size': 'nineFootPlus',
      'exam_i_score': 60,
      'exam_ii_version': 'masters',
      'exam_ii_score': 40,
      'total_score': 100,
      'result_rank': 'k',
    }, toLocal: plus7);
    expect(t.startedAt, DateTime.utc(2026, 10, 13, 8, 2, 3));
    expect(t.completedAt, DateTime.utc(2026, 10, 13, 9));
    expect(t.cancelledAt, isNull);
    expect(t.tableSize, TableSize.nineFootPlus);
    expect(t.examIIVersion, ExamIIVersion.masters);
    expect(t.resultRank, Rank.k);

    final r = buDrillResultFromRemote({
      'id': 'r1',
      'test_id': 'b1',
      'drill_id': 'dr',
      'attempts': {'shots': [true, false]},
      'score': 1,
      'recorded_at': '2026-10-13T01:02:03.000Z',
    }, toLocal: plus7);
    expect(r.attemptsJson, '{"shots":[true,false]}');
    expect(r.score, 1);
    expect(r.recordedAt, DateTime.utc(2026, 10, 13, 8, 2, 3));
    expect(drillAttemptsFromJson(r.attemptsJson), isA<ShotAttempts>());
    expect(() => drillAttemptsFromJson('{"x":1}'), throwsFormatException);
  });
}
