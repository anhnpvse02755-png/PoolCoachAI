import 'package:poolcoachai/domain/skill_category.dart';

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

  /// Tên tiếng Việt của một nhóm kỹ năng.
  ///
  /// Đây là thuật ngữ đã được cơ thủ xác nhận — "Phá" chứ không phải
  /// "Giao bóng", "A băng" (từ tiếng Pháp *à bande*) chứ không phải
  /// "Bi băng", "Điều bi" chứ không phải "Đi bi".
  static String skill(SkillCategory category) => switch (category) {
        SkillCategory.aiming => 'Ngắm bi',
        SkillCategory.position => 'Điều bi / Vị trí',
        SkillCategory.breakShot => 'Phá',
        SkillCategory.safety => 'Phòng thủ',
        SkillCategory.bank => 'A băng',
      };

  // Trạng thái rỗng dùng chung
  static const comingSoonTitle = 'Đang xây dựng';
  static const comingSoonBody = 'Phần này sẽ có ở bản cập nhật sau.';

  /// Tiền tố huy hiệu hạng, ví dụ "HẠNG G".
  static const rankWord = 'Hạng';

  // Tiêu đề và mô tả tạm của các màn gốc.
  //
  // Đây là chữ cố định của giao diện, không phải nội dung do hệ thống
  // sinh ra — viết sẵn ở đây là đúng. Mỗi màn nói thẳng sẽ có gì ở bản
  // sau thay vì để trắng hoặc bịa nội dung cho có.
  static const homeTitle = 'Xin chào';
  static const homeComing = 'Gợi ý của huấn luyện viên, mục tiêu hôm nay '
      'và tiến độ sẽ hiện ở đây.';

  static const trainingTitle = 'Trung tâm luyện tập';
  static const trainingComing = 'Thư viện bài tập, lộ trình AI, mô phỏng '
      'góc cắt và đồng hồ luyện tập sẽ nằm ở đây.';

  static const playTitle = 'Thi đấu';
  static const playComing = 'Ghi trận đấu, lịch sử trận và giải đấu sẽ '
      'nằm ở đây.';

  static const statsTitle = 'Thống kê';
  static const statsComing = 'Biểu đồ tiến bộ theo từng nhóm kỹ năng, '
      'kết hợp dữ liệu luyện tập và thi đấu.';

  static const profileTitle = 'Hồ sơ';
  static const profileComing = 'Hạng, chứng nhận, cơ bi-a và cài đặt sẽ '
      'nằm ở đây.';

  static const coachComing = 'Hỏi huấn luyện viên hôm nay nên tập gì, '
      'hoặc vì sao trận vừa rồi thua.';

  static const notificationsComing = 'Nhắc lịch tập, nhắc bảo dưỡng đầu cơ '
      'và đề xuất mới sẽ hiện ở đây.';
}
