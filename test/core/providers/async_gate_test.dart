import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';

void main() {
  final error = StateError('nguồn lỗi');

  test('mọi nguồn sẵn sàng: null', () {
    expect(gate<int>([const AsyncData(1), const AsyncData('a')]), isNull);
  });

  test('một nguồn lỗi: AsyncError mang đúng lỗi', () {
    final result = gate<int>([const AsyncData(1), AsyncError<int>(error, StackTrace.empty)]);
    expect(result, isA<AsyncError<int>>());
    expect(result!.error, same(error));
  });

  test('một nguồn chưa có giá trị: đang tải', () {
    expect(gate<int>([const AsyncData(1), const AsyncLoading<int>()]), isA<AsyncLoading<int>>());
  });

  test('nguồn đang tải lại mà còn lỗi cũ tính là đang tải', () {
    // ignore: invalid_use_of_internal_member
    final stale = const AsyncLoading<int>().copyWithPrevious(AsyncError<int>(error, StackTrace.empty));
    expect(stale.hasError, isTrue);
    expect(stale.isLoading, isTrue);
    expect(gate<int>([stale]), isA<AsyncLoading<int>>());
  });

  test('lỗi thắng đang tải khi có cả hai', () {
    final result = gate<int>([const AsyncLoading<int>(), AsyncError<int>(error, StackTrace.empty)]);
    expect(result, isA<AsyncError<int>>());
  });
}
