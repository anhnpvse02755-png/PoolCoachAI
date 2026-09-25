import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';

/// Nạp dữ liệu seed vào DB trước khi màn hình đầu tiên đọc nó.
///
/// Mã trong `lib/data/seed/` là nguồn sự thật, DB chỉ là bản sao đọc
/// được bằng truy vấn. Chạy mỗi lần mở app chứ không chỉ lần cài đầu:
/// bài tập nằm trong DB thì một bản sửa trong mã không tự tới được máy
/// đã cài, và dự án này đã hai lần phải sửa dữ liệu seed sau khi phát
/// hành.
///
/// Tách khỏi `main()` để kiểm thử được: `main()` phải gọi `runApp`,
/// còn hàm này thì không.
Future<void> loadSeed(ProviderContainer container) async {
  await upsertSeed(container.read(appDatabaseProvider));
}

/// Đọc phiên đã lưu **trước** khung hình đầu tiên, để router quyết định
/// ngay: có phiên thì vào thẳng app, kể cả khi đang mất mạng.
Future<void> restoreSession(ProviderContainer container) async {
  await container.read(authRepositoryProvider).restore();
}

/// Bật đồng bộ nền suốt đời app. Gọi **sau** [restoreSession]: lượt đầu
/// cần biết ai đang đăng nhập. Màn hình chỉ đọc Drift.
void startSync(ProviderContainer container) {
  container.read(syncServiceProvider);
}
