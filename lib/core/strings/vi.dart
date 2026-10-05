import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

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
  static const syncBlockedByUnsyncable =
      'Còn buổi tập không đồng bộ được. Xem mục cảnh báo ở Hồ sơ để bỏ chúng.';

  static const cancel = 'Huỷ';
  static String unsyncableTitle(int count) =>
      'Có $count buổi tập không đồng bộ được';
  static const unsyncableBody =
      'Điểm của các buổi này không hợp lệ nên máy chủ không nhận. '
      'Chúng chỉ nằm trên máy này và sẽ mất khi đăng xuất.';
  static const unsyncableDiscard = 'Bỏ các buổi này';
  static const unsyncableConfirm = 'Bỏ';
  static String unsyncableConfirmBody(int count) =>
      'Xoá $count buổi lỗi khỏi máy? Không lấy lại được.';

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

  // Mô phỏng góc cắt — docs/superpowers/specs/2026-10-01-poolcoachai-cut-angle-simulator-design.md.
  // Câu nào có số thì số do lõi table_geometry tính ra; ở đây chỉ ghép chữ.
  static const simTitle = 'Mô phỏng góc cắt';
  static const simCardBody = 'Đặt bi, xem bi ảo, góc cắt và đường đi bi cái.';
  static const simHint = 'Kéo bi để đặt lại, chạm vào lỗ để chọn lỗ khác.';
  static const simStrokeLabel = 'Kiểu đánh';
  static const simPowerLabel = 'Lực';
  static const simSpinLabel = 'Áp phê';
  static const simNoPocket = 'Không lỗ nào đánh được từ vị trí này.';

  /// PRD §6.6 — không được bỏ.
  static const simDisclaimer = 'Lực và đầu cơ là gợi ý định hướng dựa trên '
      'hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, '
      'người chơi vẫn cần tự canh lực thực tế.';

  /// Gắn sau mức áp phê mà lời khuyên gợi ý, khi mức đó dễ trượt cơ.
  static const simMiscueClause = ' (dễ Trượt cơ)';

  static String get simMiscue => 'Lệch ${simTips(miscueTips)} đầu cơ dễ trượt cơ.';

  static String simStroke(Stroke stroke) => switch (stroke) {
        Stroke.stun => 'Đánh đứng bi',
        Stroke.draw => 'Đánh trô bi',
        Stroke.follow => 'Đánh cu lê',
      };

  /// Năm mức lực đứng cạnh nhau: chỉ số phần trăm là đủ rõ.
  static String simPowerPreset(double power) => '${power.round()}%';

  /// 0.5 → "0.5", 1 → "1": người chơi nói "lệch 1 đầu cơ", không "1.0".
  static String simTips(double tips) =>
      tips == tips.roundToDouble() ? '${tips.round()}' : '$tips';

  static String _side(SpinSide side) => switch (side) {
        SpinSide.left => 'trái',
        SpinSide.right => 'phải',
      };

  static String simSpinChip(SideSpin spin) => switch (spin.side) {
        null => 'Không',
        SpinSide.left => 'Trái ${simTips(spin.tips)}',
        SpinSide.right => 'Phải ${simTips(spin.tips)}',
      };

  static String _spinLong(SideSpin spin) => switch (spin.side) {
        null => 'không áp phê',
        final side => 'áp phê ${_side(side)} lệch ${simTips(spin.tips)} đầu cơ',
      };

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String simPocket(Pocket pocket) => switch (pocket) {
        Pocket.topLeft => 'góc trên trái',
        Pocket.topMiddle => 'giữa trên',
        Pocket.topRight => 'góc trên phải',
        Pocket.bottomLeft => 'góc dưới trái',
        Pocket.bottomMiddle => 'giữa dưới',
        Pocket.bottomRight => 'góc dưới phải',
      };

  static String simBand(DifficultyBand band) => switch (band) {
        DifficultyBand.easy => 'Dễ',
        DifficultyBand.medium => 'Vừa',
        DifficultyBand.hard => 'Khó',
        DifficultyBand.veryHard => 'Rất khó',
        DifficultyBand.extreme => 'Cực khó',
        DifficultyBand.impossible => 'Không đánh được',
      };

  static String simUnmakeable(UnmakeableReason reason) => switch (reason) {
        UnmakeableReason.overlap => 'Hai bi đang chồng lên nhau.',
        UnmakeableReason.ghostOffTable =>
          'Bi ảo nằm ngoài mặt bàn — bi mục tiêu sát băng, lỗ này không đánh được.',
        UnmakeableReason.tooThin =>
          'Góc cắt quá lớn (>${maxCutAngle.round()}°).',
        UnmakeableReason.cueBlocked => 'Đường bi cái tới bi ảo bị bi khác chắn.',
        UnmakeableReason.objectBlocked =>
          'Đường bi mục tiêu vào lỗ bị bi khác chắn.',
      };

  static String simPocketLine(Pocket pocket) => 'Lỗ: ${simPocket(pocket)}';
  static String simAngleLine(double angle) => 'Góc cắt: ${angle.round()}°';
  static String simBandLine(DifficultyBand band) => 'Độ khó: ${simBand(band)}';
  static String simStrokeLine(Stroke stroke) => 'Kiểu đánh: ${simStroke(stroke)}';
  static String simPowerLine(double power) => 'Lực: ${power.round()}%';
  static String simSpinLine(SideSpin spin) => switch (spin.side) {
        null => 'Áp phê: không',
        final side => 'Áp phê: ${_side(side)} lệch ${simTips(spin.tips)} đầu cơ',
      };
  static String simScratch(Pocket pocket) =>
      'Bi cái rơi lỗ ${simPocket(pocket)} (chết cái).';

  // Lõi vật lý — docs/superpowers/specs/2026-10-02-poolcoachai-table-physics-design.md.
  static const simElevationLabel = 'Độ dốc cơ';
  static const simCompensateToggle = 'Xem nếu không bù ném';
  static const simComputing = 'Đang tính…';
  static const simObjectMissed = 'Bi mục tiêu không vào lỗ.';

  static String simElevation(CueElevation elevation) => switch (elevation) {
        CueElevation.normal => 'Thường',
        CueElevation.steep => 'Dốc',
      };

  static String simElevationLine(CueElevation elevation) =>
      'Độ dốc cơ: ${simElevation(elevation)}';

  /// Làm tròn tới bội số gần nhất của [step], bỏ số 0 thừa: 1.0 → "1".
  static String _rounded(double value, double step) {
    final r = (value / step).round() * step;
    return r == r.roundToDouble() ? '${r.round()}' : '$r';
  }

  /// [offset] là `b`, cm (âm là dưới tâm), đổi ra đầu cơ, làm tròn 0.25.
  static String simStunOffset(double offset) =>
      'Đánh đứng bi: đặt cơ dưới tâm khoảng '
      '${_rounded(offset.abs() / tipWidth, 0.25)} đầu cơ';

  /// Góc lệch do áp phê, độ, làm tròn 0.5°. Có [shiftTips] và
  /// [ballDenominator] (đã làm tròn ở `aimShiftUnits`) thì nói thêm điểm
  /// ngắm phải dịch bao xa, bằng đầu cơ và phần con bi; thiếu thì thôi.
  ///
  /// Có thêm [bhePercent] thì câu kết bằng lựa chọn SAWS (FHE = phần còn
  /// lại của 100) thay cho dấu chấm.
  static String simSquirt(double deg,
      [double? shiftTips, double? ballDenominator, int? bhePercent]) {
    final base = 'Bi cái bị lệch do áp phê khoảng ${_rounded(deg.abs(), 0.5)}°';
    if (shiftTips == null || ballDenominator == null) return base;
    final shift = '$base (điểm ngắm cần lệch khoảng ${simTips(shiftTips)} '
        'đầu cơ ≈ 1/${simTips(ballDenominator)} con bi)';
    if (bhePercent == null) return '$shift.';
    return '$shift → bạn có thể dùng SAWS ($bhePercent% BHE / '
        '${100 - bhePercent}% FHE) hoặc ngắm lệch đi để bù trừ áp phê';
  }

  static String simRailCount(int count) => 'Bi cái chạm băng $count lần.';

  static String simAdvice(Advice advice) => switch (advice) {
        AddSpinToAvoid(:final from, :final to, :final pocket) =>
          _avoidText(from, to, pocket),
        NoSpinAvoids(:final pocket) => 'Bi cái chết cái ở lỗ '
            '${simPocket(pocket)}, áp phê không cứu được — đổi lực hoặc kiểu đánh.',
        OverhitRisk(:final margin, :final fromPower, :final pocket, :final saferSpin) =>
          'Nếu đánh quá lực khoảng +${margin.round()}% (từ ~${fromPower.round()}%), '
              'bi cái có thể rơi lỗ ${simPocket(pocket)} (chết cái).'
              '${saferSpin == null ? '' : ' ${_capitalize(_spinAdvised(saferSpin))} thì vẫn an toàn tới 100%.'}',
        SpinCeiling(:final side, :final maxSafeTips, :final pocket) =>
          'Đừng áp phê ${_side(side)} quá ${simTips(maxSafeTips)} đầu cơ — '
              'bi cái sẽ rơi lỗ ${simPocket(pocket)}.',
      };

  static String _spinAdvised(SideSpin spin) =>
      '${_spinLong(spin)}${spin.risksMiscue ? simMiscueClause : ''}';

  /// Chọn câu theo chiều đổi: thêm đầu cơ, bớt đầu cơ, hay đổi phía.
  static String _avoidText(SideSpin from, SideSpin to, Pocket pocket) {
    final at = 'lỗ ${simPocket(pocket)}';
    if (to.isNone) {
      return 'Áp phê đang chọn làm bi cái chết cái ở $at — đánh không áp phê '
          'thì tránh được.';
    }
    if (from.isNone || (from.side == to.side && to.tips > from.tips)) {
      return 'Ít áp phê thì bi cái chết cái ở $at — nên ${_spinAdvised(to)} để '
          'đổi góc bật tránh lỗ.';
    }
    if (from.side == to.side) {
      return 'Áp phê nhiều quá, bi cái chết cái ở $at — giảm còn ${_spinAdvised(to)}.';
    }
    return 'Áp phê ${_side(from.side!)} làm bi cái chết cái ở $at — nên đổi '
        'sang ${_spinAdvised(to)}.';
  }

  static const simShowingUncompensated = 'Đang xem đường không bù ném.';
  static const simCannotSimulate =
      'Không mô phỏng được cú này — chỉ vẽ đường ngắm.';

  /// Nhãn semantics của bàn: trình đọc màn hình và E2E đọc từ đây — nên
  /// có đủ số lần chạm băng và độ dốc cơ để phân biệt từng cảnh.
  static String simSummary(
    ShotResult? shot,
    AimedShot? aimed, {
    required CueElevation elevation,
    bool showingUncompensated = false,
    bool cannotSimulate = false,
  }) {
    const head = 'Bàn mô phỏng.';
    return switch (shot) {
      null => '$head $simNoPocket',
      Unmakeable(:final reason) => '$head ${simUnmakeable(reason)}',
      Makeable(:final geometry) => [
          '$head Lỗ ${simPocket(geometry.pocket)}, góc cắt '
              '${geometry.angle.round()}°, ${simBand(bandFor(geometry.angle))}.',
          '${simElevationLine(elevation)}.',
          if (cannotSimulate) simCannotSimulate,
          if (aimed != null && aimed.trace.cueRailCount > 0)
            simRailCount(aimed.trace.cueRailCount),
          if (aimed?.trace.cuePocket != null) 'Chết cái.',
          if (showingUncompensated) simShowingUncompensated,
        ].join(' '),
    };
  }
}
