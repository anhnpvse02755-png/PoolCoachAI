import 'package:poolcoachai/domain/assessment/bu_test.dart';

/// Hai lần hoàn tất cách nhau tối thiểu 14 ngày — quy định của app, không
/// phải luật BU (spec Q12).
const retestGapDays = 14;

/// Ngày sớm nhất được làm (và được hoàn tất) lần kế tiếp: nửa đêm của ngày
/// thứ 14 sau lần hoàn tất gần nhất. Lần bị hủy và lần đang dở không tính.
DateTime? retestAvailableFrom(Iterable<BuTest> tests, {String? exceptTestId}) {
  DateTime? last;
  for (final t in tests) {
    final done = t.completedAt;
    if (done == null || t.isCancelled || t.id == exceptTestId) continue;
    if (last == null || done.isAfter(last)) last = done;
  }
  if (last == null) return null;
  return DateTime(last.year, last.month, last.day + retestGapDays);
}

bool retestAllowed(Iterable<BuTest> tests, DateTime now, {String? exceptTestId}) {
  final from = retestAvailableFrom(tests, exceptTestId: exceptTestId);
  return from == null || !now.isBefore(from);
}
