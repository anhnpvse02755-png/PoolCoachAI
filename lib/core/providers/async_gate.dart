import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lỗi nếu có nguồn lỗi (và không đang tải lại); đang tải nếu có nguồn chưa
/// sẵn sàng; null khi mọi nguồn đã sẵn sàng.
///
/// Chỉ `hasValue` là chưa đủ: nguồn đang tải lại còn giá trị cũ của tài khoản
/// trước phải tính là đang tải. Và một nguồn lỗi phải thành lỗi, không để
/// màn hình quay mãi.
AsyncValue<T>? gate<T>(List<AsyncValue<Object?>> s) {
  for (final v in s) {
    if (v.hasError && !v.isLoading) return AsyncError<T>(v.error!, v.stackTrace!);
  }
  return s.every((v) => v.hasValue && !v.isLoading) ? null : AsyncLoading<T>();
}
