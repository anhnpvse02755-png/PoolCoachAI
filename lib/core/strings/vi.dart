/// Toàn bộ chuỗi tiếng Việt hiển thị cho người dùng.
///
/// Không widget nào được chứa chuỗi tiếng Việt viết thẳng — mọi chữ
/// phải đi qua đây. Nhờ vậy đổi cách gọi một thuật ngữ chỉ cần sửa
/// một dòng thay vì lục khắp 35 màn.
abstract final class Vi {
  static const appName = 'PoolCoachAI';

  // Thanh tab
  static const tabHome = 'Trang chủ';
  static const tabTraining = 'Luyện tập';
  static const tabPlay = 'Thi đấu';
  static const tabStats = 'Thống kê';
  static const tabProfile = 'Hồ sơ';

  // Màn mở đè lên shell
  static const coachTitle = 'Huấn luyện viên AI';
  static const notificationsTitle = 'Thông báo';

  // Trạng thái rỗng dùng chung
  static const comingSoonTitle = 'Đang xây dựng';
  static const comingSoonBody = 'Phần này sẽ có ở bản cập nhật sau.';
}
