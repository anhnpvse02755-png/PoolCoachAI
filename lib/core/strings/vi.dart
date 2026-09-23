import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/recommendation.dart';
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
  /// "Giao bóng", "Điều bi" chứ không phải "Đi bi".
  ///
  /// "A băng" (từ tiếng Pháp *à bande*) là **kick shot**: bi cái chạm
  /// băng trước rồi mới tới bi mục tiêu. "Cân bi" là **bank shot**: bi
  /// mục tiêu mới là bi chạm băng. Hai nhóm riêng, không gộp.
  static String skill(SkillCategory category) => switch (category) {
        SkillCategory.aiming => 'Ngắm bi',
        SkillCategory.position => 'Điều bi / Vị trí',
        SkillCategory.breakShot => 'Phá',
        SkillCategory.safety => 'Phòng thủ',
        SkillCategory.kick => 'A băng',
        SkillCategory.bank => 'Cân bi',
      };

  /// Câu giải thích vì sao hôm nay lại là nhóm kỹ năng này.
  ///
  /// Khuôn câu cố định, tham số do [computeRecommendation] tính ra —
  /// đây không phải bịa nội dung. Mục 2.1 của tài liệu thiết kế cấm
  /// con số bịa, không cấm câu chữ có tham số.
  ///
  /// Sáu lý do phải ra sáu câu khác nhau. Dùng chung một câu là lớp
  /// suy luận nói mà người chơi không nghe được gì.
  static String pickReason(PickReason reason, String skill) =>
      switch (reason) {
        PickReason.scheduled => 'Lịch tập hôm nay của bạn là $skill.',
        PickReason.streakAtRisk =>
          'Hai hôm rồi bạn chưa tập. Quay lại nhẹ nhàng với $skill.',
        PickReason.weakest => '$skill đang là nhóm yếu nhất của bạn.',
        PickReason.newcomer => 'Bắt đầu với $skill — nền của mọi cú đánh.',
        PickReason.declining =>
          '$skill đang đi xuống. Ôn lại trước khi thành điểm yếu.',
        PickReason.rotation => 'Đã lâu bạn chưa tập $skill.',
      };

  // Màn đường dẫn không tồn tại.
  //
  // Người dùng web gõ sai địa chỉ, hoặc mở một liên kết cũ. Không đẩy
  // nội dung ngoại lệ ra màn hình: nó là tiếng Anh và lộ cấu trúc bên
  // trong, chẳng giúp gì người chơi.
  static const notFoundTitle = 'Không tìm thấy trang';
  static const notFoundBody = 'Đường dẫn này không tồn tại. Hãy quay lại '
      'trang chủ để tiếp tục.';
  static const notFoundAction = 'Về trang chủ';

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

  // Màn AI Home — mục 6.1 của thiết kế lát dọc Phase 1.
  //
  // Bốn khối: chuỗi ngày tập, nhóm hôm nay kèm lý do, bài tập gợi ý,
  // bài đọc. Chữ cố định nằm ở đây; con số và tên bài do lớp suy luận
  // đưa lên, không viết sẵn ở bất kỳ đâu.
  static const homeStreakUnit = 'ngày tập liên tiếp';
  static const homeTodayTitle = 'Hôm nay';
  static const homeDrillTitle = 'Bài tập gợi ý';
  static const homeDrillOpen = 'Mở';
  static const homeArticleTitle = 'Bài đọc hôm nay';

  /// Khi nhóm hôm nay đã tập hết bài.
  ///
  /// Không đổi sang bài của nhóm khác: gợi ý phải trung thành với
  /// nhóm mà sáu luật ưu tiên đã chọn, nói thật là hết bài thì hơn.
  static const homeDrillAllDone =
      'Hôm nay bạn đã tập hết bài trong nhóm này rồi.';

  // Màn đọc kiến thức — mục 6.5 của thiết kế.
  static const knowledgeTitle = 'Bài đọc';
  static const knowledgeRelatedTitle = 'Bài tập liên quan';

  // Khi không đọc được dữ liệu.
  //
  // Không in nội dung ngoại lệ ra màn hình: nó là tiếng Anh, lộ cấu
  // trúc bên trong và chẳng giúp gì người chơi — cùng một lý do đã
  // khiến màn không tìm thấy phải tự viết bằng tiếng Việt.
  static const dataErrorTitle = 'Không đọc được dữ liệu';
  static const dataErrorBody = 'Có trục trặc khi đọc dữ liệu luyện tập. '
      'Hãy đóng app rồi mở lại.';

  // Thư viện bài tập — mục 6.2 của thiết kế.
  static const trainingFilterAll = 'Tất cả';

  /// Tỉ lệ đạt mục tiêu của lần tập gần nhất, hiện theo phần trăm.
  ///
  /// `1.0` là đúng mục tiêu nên hiện 100%. Đây là số do [drillRatio]
  /// tính, **không** phải điểm thô người chơi nhập: bài đạt khi trúng
  /// 8 trên 10 thì trúng 9 là 113% mục tiêu, không phải "9".
  static String drillRatioPercent(double ratio) =>
      '${(ratio * 100).round()}%';

  /// Đã tập nhưng thiếu dữ liệu để chấm.
  ///
  /// Không quy về 0: thiếu dữ liệu khác hẳn làm kém, và 0 ở đây là
  /// một con số bịa đặt lên màn hình.
  static const drillRatioUnknown = 'Chưa chấm được';

  // Chi tiết bài tập — mục 6.3.
  static String drillLevel(int level) => 'Cấp $level';
  static String drillUnitLabel(String unit) => 'Đơn vị: $unit';
  static const drillStepsTitle = 'Các bước thực hiện';
  static const drillHistoryTitle = 'Lịch sử tập';
  static const drillStartAction = 'Bắt đầu tập';

  /// Ngày kiểu Việt Nam: ngày trước, tháng sau, đủ bốn chữ số năm.
  ///
  /// Viết tay thay vì dùng intl vì app khoá cứng một ngôn ngữ; thêm
  /// cả gói định dạng cho một khuôn ngày là đắt hơn thứ nhận lại.
  static String shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  // Buổi tập — mục 6.4.
  static String sessionTitle(String drillName) => 'Tập: $drillName';
  static const sessionScoreLabelAttempts = 'Số lần đạt';
  static const sessionScoreLabelTarget = 'Kết quả';
  static const sessionScoreHintAttempts = 'VD: 7';
  static const sessionScoreHintTarget = 'VD: 22.5';
  static const sessionAttemptsLabel = 'Số lần thử';
  static const sessionAttemptsHint = 'VD: 10';
  static const sessionNotesLabel = 'Ghi chú (tùy chọn)';
  static const sessionNotesHint = 'VD: Cú đánh hơi lệch phải...';
  static const sessionSaveAction = 'Lưu kết quả';

  // Chặn ngay tại nút lưu, kèm câu giải thích. Lưu một log méo rồi để
  // drillRatio() trả null về sau là đẩy lỗi đi xa khỏi chỗ gây ra nó.
  static const sessionScoreRequired = 'Nhập kết quả';
  static const sessionScoreInvalid = 'Nhập số hợp lệ';
  static const sessionAttemptsRequired = 'Bài này cần nhập số lần thử';
  static const sessionAttemptsInvalid = 'Nhập số nguyên dương';
  static const sessionSaveFailed = 'Không lưu được kết quả. Hãy thử lại.';

  /// Xác nhận sau khi lưu, kèm tỉ lệ đạt của chính buổi vừa ghi.
  ///
  /// Nói ngay lúc còn đứng ở bàn thì người chơi biết buổi vừa rồi tốt
  /// hay tệ; để họ tự mở màn khác xem mới biết là mất mạch.
  static String sessionSavedRatio(String percent) =>
      'Đã lưu. Buổi này đạt $percent mục tiêu.';

  /// Xác nhận khi bài không chấm được thành tỉ lệ.
  static const sessionSaved = 'Đã lưu kết quả buổi tập.';

  // Tài khoản — spec mục 4.3.
  static const authLoginTitle = 'Đăng nhập';
  static const authLoginAction = 'Đăng nhập';
  static const authEmailLabel = 'Email';
  static const authPasswordLabel = 'Mật khẩu';
  static const authToRegister = 'Chưa có tài khoản? Đăng ký';
  static const authToForgot = 'Quên mật khẩu?';
  static const authToLogin = 'Đã có tài khoản? Đăng nhập';
  static const authSessionExpired =
      'Phiên đăng nhập đã hết, hãy đăng nhập lại.';

  static const authRegisterTitle = 'Tạo tài khoản';
  static const authRegisterAction = 'Tạo tài khoản';
  static const authDisplayNameLabel = 'Tên hiển thị';
  static const authPasswordConfirmLabel = 'Nhập lại mật khẩu';

  static const authForgotTitle = 'Quên mật khẩu';
  static const authForgotHint =
      'Nhập email bạn dùng để đăng ký. Chúng tôi sẽ gửi link đặt lại mật khẩu.';
  static const authForgotAction = 'Gửi link';

  /// Luôn cùng một câu, dù email có tài khoản hay không — để không ai
  /// dùng màn này dò xem email nào đã đăng ký.
  static const authForgotSent =
      'Nếu email này có tài khoản, link đặt lại mật khẩu đã được gửi.';

  static const authResetTitle = 'Đặt lại mật khẩu';
  static const authNewPasswordLabel = 'Mật khẩu mới';
  static const authResetAction = 'Lưu mật khẩu mới';
  static const authResetDone =
      'Đã đổi mật khẩu. Hãy đăng nhập bằng mật khẩu mới.';
  static const authResetMissingToken =
      'Link đặt lại mật khẩu không đầy đủ. Hãy mở lại link trong email.';

  // Đăng xuất — spec mục 5.4.
  static String profileSignedInAs(String name) => 'Đang đăng nhập: $name';
  static const profileSignOut = 'Đăng xuất';
  static const signOutPendingTitle = 'Còn buổi tập chưa đồng bộ';
  static String signOutPendingBody(int count) =>
      'Còn $count buổi chưa đồng bộ, đăng xuất sẽ mất.';
  static const signOutSyncFirst = 'Đồng bộ trước';
  static const signOutAnyway = 'Vẫn đăng xuất';
  static const syncFailed = 'Chưa đồng bộ được. Kiểm tra mạng rồi thử lại.';

  static const authFieldRequired = 'Không được để trống';
  static const authEmailInvalid = 'Nhập email hợp lệ';
  static const authPasswordTooShort = 'Mật khẩu cần ít nhất 8 ký tự';
  static const authPasswordMismatch = 'Hai mật khẩu không khớp';

  /// Một câu cho mỗi loại lỗi — không bao giờ hiện nguyên văn lỗi server.
  static String authFailure(AuthFailure failure) => switch (failure) {
        AuthFailure.wrongCredentials => 'Email hoặc mật khẩu không đúng.',
        AuthFailure.emailTaken =>
          'Email này đã có tài khoản. Hãy đăng nhập, hoặc dùng Quên mật khẩu.',
        AuthFailure.weakPassword => 'Mật khẩu cần ít nhất 8 ký tự.',
        AuthFailure.network =>
          'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        AuthFailure.resetLinkInvalid =>
          'Link đặt lại mật khẩu đã hết hạn hoặc đã dùng. Hãy yêu cầu link mới.',
        AuthFailure.sessionExpired => authSessionExpired,
        AuthFailure.unknown => 'Máy chủ đang gặp lỗi. Hãy thử lại sau.',
      };
}
