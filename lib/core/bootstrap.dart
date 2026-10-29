import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
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

/// Bật đồng bộ nền và nhắc bảo dưỡng suốt đời app. Gọi **sau** [restoreSession]:
/// lượt đầu cần biết ai đang đăng nhập. Màn hình chỉ đọc Drift.
void startSync(ProviderContainer container) {
  container.read(syncServiceProvider);
  container.read(cueEquipmentSyncProvider);
  container.read(practiceSyncProvider);
  startNotifications(container);
  container.read(assessmentSyncProvider);
  container.read(roadmapSyncProvider);
  container.read(coachSyncProvider);
}

/// Bật dịch vụ thông báo và giữ nó được nghe suốt đời app (plan ★12).
///
/// Không dùng `container.read`: trong Riverpod 3.4.3 `read` là `listen` rồi
/// `close` ngay, nên dịch vụ thành không còn ai nghe, và các `ref.listen` của
/// nó (cài đặt thông báo, nguồn gợi ý) bị vô hiệu. Lần đổi `state =` trực
/// tiếp vẫn tới được (như lần nạp cài đặt đầu tiên), nhưng một provider không
/// còn ai nghe thì không dựng lại khi thứ nó phụ thuộc đổi. Vì vậy sau khi
/// đăng nhập giữa phiên hay đổi tài khoản, chuỗi auth → cài đặt / nguồn gợi
/// ý không dựng lại, và dịch vụ giữ cài đặt mặc định (hoặc của tài khoản
/// trước) cho tới khi một màn hình nào đó theo dõi chúng.
///
/// Đăng ký ở đây không bao giờ đóng: dịch vụ sống cùng [container].
void startNotifications(ProviderContainer container) {
  container.listen(notificationServiceProvider, (_, _) {}).read().start();
}
