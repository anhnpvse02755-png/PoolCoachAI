import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_physics/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

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

  /// Góc lệch do áp phê, độ, làm tròn 0.5°. Có [shiftTips] thì nói thêm
  /// điểm ngắm phải dịch bao xa, bằng đầu cơ và phần con bi (đã làm tròn ở
  /// `aimShiftUnits`): "1/[ballDenominator] con bi", hoặc "[ballCount] con
  /// bi" khi lệch từ một con bi trở lên. Có thêm [bhePercent] thì câu kết
  /// bằng lựa chọn SAWS (FHE = phần còn lại của 100). Dòng nào cũng kết
  /// bằng dấu chấm.
  static String simSquirt(double deg,
      [double? shiftTips,
      double? ballDenominator,
      int? bhePercent,
      double? ballCount]) {
    final base = 'Bi cái bị lệch do áp phê khoảng ${_rounded(deg.abs(), 0.5)}°';
    if (shiftTips == null || (ballDenominator == null && ballCount == null)) {
      return '$base.';
    }
    final ball = ballCount != null
        ? '${simTips(ballCount)} con bi'
        : '1/${simTips(ballDenominator!)} con bi';
    final shift = '$base (điểm ngắm cần lệch khoảng ${simTips(shiftTips)} '
        'đầu cơ ≈ $ball)';
    if (bhePercent == null) return '$shift.';
    return '$shift → bạn có thể dùng SAWS ($bhePercent% BHE / '
        '${100 - bhePercent}% FHE) hoặc ngắm lệch đi để bù trừ áp phê.';
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

  // Lõi quá maxSimTime — docs/superpowers/specs/2026-10-07-poolcoachai-planner-safety-design.md mục 7.
  static const simTimeoutQuestion =
      'Cú này tính quá lâu, bạn muốn chờ hay bỏ qua chỉ vẽ đường ngắm?';
  static const simWait = 'Chờ';
  static const simAimOnly = 'Chỉ vẽ đường ngắm';
  static const simAimOnlyLine = 'Chỉ vẽ đường ngắm.';
  static const simTooLong = 'Cú này quá dài để mô phỏng.';

  /// Nhãn semantics của bàn: trình đọc màn hình và E2E đọc từ đây — nên
  /// có đủ số lần chạm băng và độ dốc cơ để phân biệt từng cảnh.
  static String simSummary(
    ShotResult? shot,
    AimedShot? aimed, {
    required CueElevation elevation,
    bool showingUncompensated = false,
    String? notice,
  }) {
    const head = 'Bàn mô phỏng.';
    return switch (shot) {
      null => '$head $simNoPocket',
      Unmakeable(:final reason) => '$head ${simUnmakeable(reason)}',
      Makeable(:final geometry) => [
          '$head Lỗ ${simPocket(geometry.pocket)}, góc cắt '
              '${geometry.angle.round()}°, ${simBand(bandFor(geometry.angle))}.',
          '${simElevationLine(elevation)}.',
          ?notice,
          if (aimed != null && aimed.trace.cueRailCount > 0)
            simRailCount(aimed.trace.cueRailCount),
          if (aimed?.trace.cuePocket != null) 'Chết cái.',
          if (showingUncompensated) simShowingUncompensated,
        ].join(' '),
    };
  }

  // Kế hoạch dọn bàn — docs/superpowers/specs/2026-10-07-poolcoachai-run-out-planner-design.md.
  // Câu nào có số thì số do lõi planner tính ra; ở đây chỉ ghép chữ.
  static const planTitle = 'Kế hoạch dọn bàn';
  static const planCardBody = 'Bày bàn, xem cách dọn hết bi từng bước.';
  static const planGameLabel = 'Loại bàn';
  static const planGroupLabel = 'Nhóm của tôi';
  static const planPlacingLabel = 'Đang đặt';

  static String planGame(GameType game) => switch (game) {
        GameType.nineBall => '9 bi',
        GameType.tenBall => '10 bi',
        GameType.eightBall => '8 bi',
      };

  static String planGroup(BallGroup group) => switch (group) {
        BallGroup.solids => 'Trơn',
        BallGroup.stripes => 'Sọc',
      };

  static String planPlacing(BallRole role) => switch (role) {
        BallRole.mine => 'Bi của tôi',
        BallRole.opponent => 'Bi đối thủ',
        BallRole.eight => 'Bi 8',
      };

  static const planCueHint = 'Chạm lên bàn để đặt bi cái trước.';

  /// PRD §6.2: số bi gán theo thứ tự chạm.
  static const planOrderHint = 'Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…';
  static const planUndo = 'Xoá bi cuối';
  static const planClear = 'Xoá hết';
  static const planStart = 'Lập kế hoạch';

  static String planComputing(int step, int total) => 'Đang tính bước $step/$total…';
  static String planStepHeader(int step, int total) => 'Bước $step / $total';
  static String planBallLine(int number) => 'Bi $number';

  /// Số mức lực (trong [samples] mức) mà điểm dừng vẫn trong vùng điều tốt.
  static String planTolerance(int good, int samples) =>
      '$good/$samples mức lực vẫn trong vùng điều tốt';

  /// Thông tin, không phải cảnh báo. Không còn vế "hao khoảng 15% lực":
  /// lõi vật lý tính hao lực thật (spec quyết định 7).
  static String planRailInfo(int count) => 'Bi cái chạm băng $count lần rồi tới vùng điều.';

  /// Bước cuối: không có bi kế tiếp, nên không có vùng điều để tới.
  static String planRailInfoLast(int count) => 'Bi cái chạm băng $count lần.';

  /// PRD §6.5, nguyên văn.
  static const planRiskWarning = 'Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái '
      'hoặc sai số lớn hơn bình thường.';

  static String planMissAdvice(MissSide side) =>
      'Nếu trượt: nên đánh dư ${side == MissSide.thick ? 'dày' : 'mỏng'} một chút — '
      'bi sẽ khó cho đối thủ hơn.';

  static const planNoPosition = 'Không có vị trí tốt cho bi sau.';

  /// Bước phòng thủ. [ballNum] là bi bắt buộc (9 / 10 bi); null khi 8 bi
  /// không bi nào của mình có đường (không bi cụ thể nào bị ép).
  static String planSafety(int? ballNum) =>
      '${ballNum == null ? 'Không bi nào có' : 'Bi $ballNum không có'} đường đánh rõ ràng '
      'vào lỗ nào (bị chắn hoặc góc quá khó) — nên chơi an toàn (safety) thay vì cố đánh.';

  static const planPreviewLabel = 'XEM TRƯỚC';
  static const planBack = '← Quay lại';
  static const planShotDone = 'Đã đánh xong → Bi tiếp theo';
  static const planFinish = 'Xong bàn';
  static const planEditTable = 'Sửa bàn';
  static const planCueStoppedQuestion = 'Bi cái dừng đúng chỗ dự kiến?';
  static const planYes = 'Đúng';
  static const planResetCue = 'Đặt lại bi cái';
  static const planResetHint = 'Kéo bi cái tới đúng chỗ nó dừng ngoài bàn.';
  static const planRecompute = 'Tính lại từ đây';

  // Cú phòng thủ: lượt thô và điểm hỏi (chủ sản phẩm chốt 08/10/2026 sau
  // Task 25 của kế hoạch cú phòng thủ).
  static const planSearchingSafety = 'Đang tìm cú thủ…';

  /// Lời của chủ sản phẩm, nguyên văn.
  static const planSafetyCheckpoint = 'Tính toán cơ bản thì đánh như thế này là thủ tốt, '
      'có thể có phương án tối ưu hơn nhưng sẽ mất thời gian tính toán. '
      'Bạn muốn tính tiếp hay không?';
  static const planSafetyContinue = 'Tính tiếp';
  static const planSafetyKeep = 'Dùng cú này';

  /// Lượt thô chưa ra cú thủ tốt: hiện cú tốt nhất tạm thời, máy tự tìm tiếp.
  static const planSafetyProvisional = 'Cú thủ tạm tính — đang tìm cú tốt hơn…';

  /// Nút gập/mở chú giải; gập sẵn để câu hỏi và nút không rớt dưới màn.
  static const planLegendClosed = 'Chú thích ▸';
  static const planLegendOpen = 'Chú thích ▾';

  /// Chú giải các lớp trên bàn (spec mục 7.1). Ngưỡng lấy từ hằng số planner.
  static List<String> get planLegend => [
        'Ô xanh: vùng điều tốt — từ đây góc cắt bi sau ≤ ${zoneGood.round()}°.',
        'Ô vàng: tạm được — góc cắt bi sau ≤ ${zoneFair.round()}°.',
        'Nét đứt trắng: bi cái tới bi mục tiêu. Nét đứt ngọc: bi cái sau va chạm.',
        'Chấm vàng: bi cái chạm băng. Vòng trắng nét đứt: chỗ bi cái dừng.',
        'Thanh vàng: chỗ bi cái dừng nếu lực lệch ±${powerJitter.round()}%.',
        'Hai chấm cam: bi mục tiêu trôi tới đâu nếu trượt (dư dày / dư mỏng); '
            'chấm đặc là hướng nên chọn.',
      ];

  /// Nhãn semantics của bàn khi bày bi — E2E đọc từ đây.
  static String planSetupSummary({required bool hasCue, required int balls}) => hasCue
      ? 'Bàn bày bi. Đã đặt bi cái, $balls bi mục tiêu.'
      : 'Bàn bày bi. Chưa đặt bi cái.';

  static const planResetSummary = 'Bàn kế hoạch. Đang đặt lại bi cái.';

  /// Nhãn semantics của bàn ở màn từng bước (spec mục 7.4): bi, lỗ, kiểu
  /// đánh, lực của bước đang xem; bước phòng thủ có cú thủ thì câu đầu, câu
  /// ngắm và kết quả cho đối thủ. [step] null khi bước đầu còn đang tính.
  static String planSummary(PlanStep? step,
      {required int index, required int total, bool searchingSafety = false}) {
    const head = 'Bàn kế hoạch.';
    if (step == null) {
      return '$head ${searchingSafety ? planSearchingSafety : planComputing(index + 1, total)}';
    }
    final at = planStepHeader(index + 1, total);
    if (step.kind == PlanStepKind.safety) {
      final s = step.safety;
      if (s == null) return '$head $at: ${planSafety(step.ballNum)}';
      return '$head $at: ${safetyHeadline(s)} ${safetyAimLine(s)} ${safetyOpponent(s.opponent)}';
    }
    return '$head $at: bi ${step.ballNum}, lỗ ${simPocket(step.pocket!)}, '
        '${simStroke(step.stroke)}, lực ${step.power.round()}%.';
  }

  // Cú phòng thủ — docs/superpowers/specs/2026-10-07-poolcoachai-planner-safety-design.md.
  // Câu nào có số thì số do lõi tìm cú thủ tính ra; ở đây chỉ ghép chữ.
  // planSearchingSafety đã có từ Task 25c, cạnh câu hỏi của điểm hỏi.
  static String safetySnookered(int ballNum) => 'Bi cái bị đui bi $ballNum — đánh A băng để thủ.';
  static const safetyNoPot = 'Không còn đường ăn bi — nên thủ bi.';

  static String safetyHeadline(SafetyShot s) =>
      s.reason == SafetyReason.snookered ? safetySnookered(s.ballNum) : safetyNoPot;

  /// Câu ngắm: A băng nói chấm, trực tiếp nói độ dày. Không bao giờ nói độ.
  static String safetyAimLine(SafetyShot s) => switch (s.railAim) {
        final aim? => safetyKick(s.rails, aim),
        null => safetyThickness(s.thickness, s.side),
      };

  /// Tên băng theo hướng nhìn trên màn.
  static String safetyRail(Rail rail) => switch (rail) {
        Rail.left => 'băng ngắn trái',
        Rail.right => 'băng ngắn phải',
        Rail.top => 'băng dài trên',
        Rail.bottom => 'băng dài dưới',
      };

  /// Số chấm, làm tròn nửa chấm sẵn ở lõi; dấu phẩy thập phân: "2,5".
  static String safetyDiamond(double d) =>
      d == d.roundToDouble() ? '${d.round()}' : '${d.floor()},5';

  static String safetyKick(int rails, RailAim aim) =>
      'A băng $rails băng: ngắm chấm ${safetyDiamond(aim.diamond)} ${safetyRail(aim.rail)}.';

  static String _fraction(double thickness) => switch ((thickness * 8).round()) {
        6 => '¾',
        4 => '½',
        2 => '¼',
        1 => '⅛',
        _ => '${(thickness * 100).round()}%',
      };

  /// Độ dày chạm bi, theo hướng nhìn từ bi cái.
  static String safetyThickness(double thickness, ThicknessSide side) => switch (side) {
        ThicknessSide.full => 'Ăn trọn bi.',
        ThicknessSide.left => 'Ăn ${_fraction(thickness)} bi, lệch bên trái.',
        ThicknessSide.right => 'Ăn ${_fraction(thickness)} bi, lệch bên phải.',
      };

  /// Kết quả cho đối thủ. Số độ ở đây là độ khó của đối thủ, không phải lời
  /// khuyên ngắm (spec quyết định 9).
  static String safetyOpponent(OpponentView o) {
    if (o.snookered) return 'Đối thủ bị đui.';
    final g = o.easiest;
    final ball = o.ball;
    if (g == null || ball == null) return 'Đối thủ không còn đường ăn.';
    return 'Cú dễ nhất của đối thủ: bi ${ball.number} vào lỗ ${simPocket(g.pocket)}, '
        'góc cắt ${g.angle.round()}°.';
  }

  static String safetyTolerance(int hard, int samples) =>
      '$hard/$samples mức lực vẫn để đối thủ khó.';

  /// Chữ trên bàn cạnh đường bị chắn của đối thủ.
  static const safetyOpponentSnookered = 'Đối thủ bị đui';

  /// Chú giải thêm khi bước đang xem là cú thủ (spec mục 5.1).
  static List<String> get planSafetyLegend => const [
        'Vòng vàng đậm: điểm ngắm trên băng đầu tiên (A băng); số ở mép bàn là chấm.',
        'Nét xám và vòng nét đứt xám: bi hợp lệ sau va chạm và chỗ nó dừng.',
        'Nét đỏ mờ: cú dễ nhất của đối thủ sau cú thủ.',
      ];

  // ─── Đánh giá + hạng — tên bài BU (spec mục 5.1, 5.2, 11.3) ───────────────
  //
  // Tên tiếng Việt do chủ sản phẩm chốt ngày 14/10/2026; tên tiếng Anh trong
  // ngoặc là tên bài của Billiard University, để đối chiếu với đề.

  static String buDrillName(String drillId) => switch (drillId) {
        'F1' => 'Cắt góc (Cut Shot)',
        'F2' => 'Đánh đứng bi (Stop Shot)',
        'F3' => 'Đánh cu lê (Follow Shot)',
        'F4' => 'Đánh trô bi (Draw Shot)',
        'F5' => 'Đánh tâm tiến (Stun Shot)',
        'F6' => 'Ăn bi (Ball Pocketing)',
        'F7' => 'Bánh xe (Wagon Wheel)',
        'F8' => 'Lưới đích (Grid Target)',
        'S1' => 'Hàng bi (Line of Balls)',
        'S2' => 'Ngắm bi sát băng (Rail Cuts)',
        'S3' => 'Thế 9 bi (9-Ball Patterns)',
        'S4' => 'Thế 8 bi (8-Ball Patterns)',
        'S5' => 'Phòng thủ / bắt đui (Safety)',
        'S6' => 'A băng (Kicks)',
        'S7' => 'Cân bi (Banks)',
        'S8' => 'Dựng cơ (Elevated cue)',
        'S9' => 'Nhảy bi (Jump) hoặc Mát xê (Massé)',
        'S10' => 'Phá (Break)',
        _ => throw ArgumentError.value(drillId, 'drillId', 'không có bài này'),
      };

  static String buDrillTitle(String drillId) => '$drillId · ${buDrillName(drillId)}';

  static String buExamName(BuExam exam) => switch (exam) {
        BuExam.fundamentals => 'Đề I — Cơ bản',
        BuExam.skills => 'Đề II — Kỹ năng',
      };

  static String buVersionName(ExamIIVersion v) => switch (v) {
        ExamIIVersion.bachelors => 'Bachelors',
        ExamIIVersion.masters => 'Masters',
        ExamIIVersion.doctorate => 'Doctorate',
      };

  // ─── Đánh giá + hạng — bộ câu hỏi và mô tả hạng ────────────────────────────
  //
  // Nguyên văn PoolOS v2 (AppConstants.assessmentQuestions và
  // AppConstants.playerLevels), chủ sản phẩm duyệt ngày 14/10/2026 —
  // spec mục 11.1, 11.2. Không sửa chữ ở đây mà không hỏi chủ sản phẩm.

  static String rankQuestion(int question) => switch (question) {
        1 => 'Bạn đã chơi Pool được bao lâu?',
        2 => 'Trung bình bạn chơi Pool bao nhiêu?',
        3 => 'Trong một lượt cơ, bạn đã từng đi được nhiều nhất bao nhiêu bi?',
        4 => 'Trong những thế bi bình thường, bạn thường đi được bao nhiêu bi?',
        5 => 'Bạn đã từng Runout (đi chấm) chưa?',
        6 => 'Trung bình bao nhiêu rack bạn có thể đi được một chấm?',
        7 => 'Sau cú phá bi, bạn thường còn thế bi như thế nào?',
        8 => 'Sau khi ăn một bi, bạn thường điều bi cái ở mức nào?',
        _ => throw RangeError.range(question, 1, 8, 'question'),
      };

  static List<String> rankQuestionOptions(int question) => switch (question) {
        1 => const ['Chưa từng chơi', 'Dưới 3 tháng', '3 – 6 tháng', '6 tháng – 1 năm',
            '1 – 2 năm', '2 – 5 năm', 'Trên 5 năm'],
        2 => const ['Dưới 2 giờ / tuần', '2 – 5 giờ / tuần', '5 – 10 giờ / tuần',
            '10 – 20 giờ / tuần', 'Trên 20 giờ / tuần'],
        3 => const ['1', '2', '3', '4', '5', '6', '7', '8', 'Dọn bàn (Run Out)'],
        4 => const ['1', '2', '3', '4', '5', '6+', 'Thường xuyên Runout'],
        5 => const ['Chưa bao giờ', 'Đã từng 1–2 lần', 'Thỉnh thoảng',
            'Khá thường xuyên', 'Rất thường xuyên'],
        6 => const ['Chưa từng', 'Hơn 100 rack', 'Khoảng 50 rack', 'Khoảng 20 rack',
            'Khoảng 10 rack', 'Khoảng 5 rack', 'Khoảng 2–3 rack',
            'Gần như rack nào cũng có thể'],
        7 => const ['Thường không có bi đánh tiếp', 'Thường chỉ có 1 bi',
            'Có thể đi tiếp 2–3 bi', 'Thường có layout thuận lợi',
            'Thường có cơ hội đi chấm'],
        8 => const ['Thường xuyên bị khó', 'Có lúc dễ, có lúc khó',
            'Phần lớn còn bi đánh tiếp', 'Thường chủ động điều được bi cái',
            'Có thể điều bi chính xác theo ý muốn'],
        _ => throw RangeError.range(question, 1, 8, 'question'),
      };

  static String rankDescription(Rank rank) => switch (rank) {
        Rank.k => 'Người mới làm quen với Pool',
        Rank.i => 'Đã biết luật chơi, kỹ thuật cơ bản',
        Rank.h => 'Người chơi phong trào phổ biến, bắt đầu có khả năng điều bi',
        Rank.g => 'Người chơi phong trào khá, có thể thi đấu ổn định với đa số CLB',
        Rank.f => 'Bước đầu tham gia sân chơi thi đấu, trình độ cao trong nhóm phong trào',
        Rank.e => 'Người chơi bán chuyên',
        Rank.d => 'Người chơi mạnh, thường xuyên thi đấu',
        Rank.c => 'Vận động viên trình độ cao',
        Rank.b => 'Vận động viên rất mạnh',
        Rank.a => 'Top đầu trong nước',
        Rank.pro => 'Thi đấu chuyên nghiệp',
      };

  static String rankGroupName(RankGroup group) => switch (group) {
        RankGroup.amateur => 'phong trào',
        RankGroup.competitive => 'thi đấu',
        RankGroup.pro => 'chuyên nghiệp',
      };

  // ─── Đánh giá + hạng — cách chấm và cách xếp bài ───────────────────────────
  //
  // Cách chấm: chữ của spec mục 5.1, 5.2 (đã đối chiếu PDF ở Task 11).
  // Cách xếp bài: dịch từ PDF của Billiard University, chủ sản phẩm duyệt
  // khi xem sơ đồ trên Chrome (D13 của kế hoạch).

  static const _ladderRule = 'Thang vị trí: bắt đầu ở vị trí 4, vào thì lên một vị trí, '
      'trượt thì xuống một (trong khoảng 1–7). Đánh đủ 10 cú. Điểm = vị trí cuối + '
      'số lần vào khi đang ở vị trí 7, tối đa 10.';

  static String buDrillScoring(String drillId, ExamIIVersion? v) => switch (drillId) {
        'F1' => _ladderRule,
        'F2' => '$_ladderRule Bi mục tiêu phải vào và bi cái dừng chồng lên vòng bi ảo.',
        'F3' => '$_ladderRule Bi cái dừng trong hoặc chồng lên khung giấy đích.',
        'F4' => '$_ladderRule Tâm bi cái dừng trong hình chữ nhật 2×1 chấm cạnh lỗ giữa.',
        'F5' => '$_ladderRule Đích di chuyển thay cho bi cái: vị trí 1–3 đi thẳng tới đích, '
            '5–7 phải bật băng cuối.',
        'F6' => '10 cú, mỗi cú 1 lượt, không được chết cái. Mỗi bi vào 1 điểm.',
        'F7' => '10 bi đích trên băng, mỗi bi 2 lượt. Vào lỗ và chạm đúng bi đích được 1 điểm.',
        'F8' => '5 đích, mỗi đích 4 lượt. Vào lỗ và bi cái dừng trong hoặc chồng lên đích '
            'được 1 điểm.',
        'S1' => 'Đánh theo thứ tự số, 2 lượt, lấy lượt cao hơn. Lượt 1 trọn điểm thì '
            'không cần lượt 2.',
        'S2' => '2 lượt, thứ tự tùy ý, lấy lượt cao hơn. Lượt 1 trọn điểm thì không cần lượt 2.',
        'S3' => '3 thế, mỗi bi hợp lệ theo thứ tự được 1 điểm, cộng 2 thế thấp nhất. Bi 9 '
            'vào sớm thì vẫn đánh nốt các bi còn lại theo thứ tự.'
            '${v == ExamIIVersion.doctorate ? ' Thế 3: phải tới bi 7 và bi 9 bằng 3–4 băng.' : ''}',
        'S4' => '3 thế, mỗi bi trước khi trượt được 1 điểm, cộng 2 thế thấp nhất. '
            'Được chạm bi chướng ngại.',
        'S5' => 'Mỗi vị trí bi cái 2 lượt, mỗi lần bắt đui được 1 điểm.',
        'S6' || 'S7' || 'S8' => 'Mỗi cú thành công 1 điểm.',
        // PDF bản Doctorate: "1 point for each successful shot (CB pocketed, no
        // obstacle-ball contact)" và hình ghi "scratch in the corner" — bản này
        // không có bi mục tiêu, cú thành công là đưa bi cái vào lỗ góc.
        'S9' => 'Dùng nhảy bi (Jump) hoặc mát xê (Massé). Mỗi cú thành công 1 điểm.'
            '${v == ExamIIVersion.doctorate ? ' Bản Doctorate: không có bi mục tiêu, cú thành công '
                'là đưa bi cái vào lỗ góc mà không chạm bi chướng ngại.' : ' Được chết cái.'}',
        'S10' => '3 lần phá, mỗi lần chấm 5 tiêu chí a–e, lấy trung vị điểm của 3 lần.',
        _ => throw ArgumentError.value(drillId, 'drillId'),
      };

  static String buBreakCriterion(int index) => switch (index) {
        0 => 'a: không chết cái',
        1 => 'b: a, và bi cái không chạm băng',
        2 => 'c: a, và bi cái dừng trong vùng 4 chấm ở giữa bàn',
        3 => 'd: a, và có ít nhất 1 bi vào',
        4 => 'e: a, và có ít nhất 3 bi mục tiêu vào lỗ hoặc vượt qua vạch đầu bàn',
        _ => throw RangeError.range(index, 0, 4, 'index'),
      };

  /// Cách xếp bài, dịch từ PDF (Task 11 Step 3). Một nhánh cho mỗi bài; bài
  /// Đề II mà các bản khác nhau thì rẽ theo [v].
  static String buDrillSetup(String drillId, ExamIIVersion? v) => switch (drillId) {
        'F1' => 'Bi cái bắt đầu ở vị trí 4 trên đường chấm 1. Bi mục tiêu trên đường chấm 3, '
            'cách băng cuối một khe bằng một bi; ăn bi mục tiêu vào lỗ góc gần nó. Vào thì '
            'lên một vị trí (xa lỗ hơn), trượt thì xuống một vị trí. Được chết cái. '
            'Có thể đánh từ phía bên kia bàn.',
        'F2' => 'Bi cái và bi mục tiêu sát băng trên (bi cái cách băng không quá một chấm); '
            'bi mục tiêu ở nửa chấm cạnh lỗ góc. Dán vòng đánh dấu chỗ bi mục tiêu và bi ảo. '
            'Đánh đứng bi: ăn bi, bi cái dừng chồng lên vòng bi ảo. Bi cái được chạm băng. Ở vị trí 1 '
            'được đặt bi cái trong khoảng vị trí 1–2.',
        'F3' => 'Bi cái và bi mục tiêu luôn cách nhau 1 chấm, sát băng trên (bi cái cách băng '
            'không quá một chấm). Khung giấy đích 8.5"×11" (bỏ lõi, chừa viền 1") đặt ở góc. '
            'Đánh cu lê: ăn bi, bi cái theo vào khung. Bi cái và bi mục tiêu được chạm băng.',
        'F4' => 'Bi cái và bi mục tiêu sát băng trên; bi mục tiêu ở nửa chấm cạnh lỗ góc. '
            'Hình chữ nhật 2×1 chấm cạnh lỗ giữa cố định, góc đánh dấu bằng vòng dán. Đánh '
            'trô bi: ăn bi, tâm bi cái dừng trong hình. Ở vị trí 1 được đặt bi cái '
            'trong khoảng vị trí 1–2.',
        'F5' => 'Bi mục tiêu ở dưới tâm bàn một bi, ăn vào lỗ giữa. Bi cái đặt tự do mỗi cú. '
            'Đánh tâm tiến. Khung giấy đích bắt đầu ở vị trí 4 (cạnh dài áp băng cuối); các vị trí khác có '
            'tâm thẳng chấm băng dài. Vị trí 1–3: bi cái đi thẳng tới đích; 5–7: bật băng cuối.',
        'F6' => 'Hai vị trí bi cái, mỗi vị trí 5 cú vào các lỗ như hình. Mỗi cú một lần, '
            'đánh theo thứ tự, không được chết cái.',
        'F7' => 'Bi mục tiêu trên đường chấm 1 dưới lỗ giữa; 10 bi đích áp sát băng. Bi cái '
            'đặt tự do mỗi cú. Ăn bi mục tiêu rồi cho bi cái chạm bi đích đang đánh; được '
            'chạm băng ngay cạnh bi đích, không được chạm băng khác. Mỗi bi đích 2 lượt, xong '
            'thì nhấc bi đích ra, bi bị xô lệch thì đặt lại.',
        'F8' => 'Bi mục tiêu (bi 1) ở chấm (1, 1), ăn vào lỗ góc gần nó; bi cái như hình. '
            'Năm khung giấy đích: hai cái sát băng trên, hai cái sát băng dưới, một cái giữa '
            'bàn. Mỗi đích 4 lượt, đi đường nào tới đích cũng được.',
        'S1' => 'Bi cái đặt tự do. Các bi xếp trên đường giữa bàn, bi 1 cách băng cuối một khe '
            'một bi, giữa các bi là khe ${switch (v) {
              ExamIIVersion.bachelors => 'ba bi',
              ExamIIVersion.masters => 'hai bi',
              _ => 'một bi',
            }}. Ăn theo thứ tự số vào lỗ bất kỳ, không chết cái, không chạm bi còn lại; '
            'chạm bi khác thì bi vừa vào vẫn tính nhưng lượt dừng.',
        'S2' => 'Bi cái đặt tự do. Các bi áp sát băng như hình (và một bi ở tâm bàn). Ăn theo '
            'thứ tự tùy ý, không chết cái, không đánh bi kết hợp, không chạm bi còn lại.',
        'S3' => 'Bi cái đặt tự do. Xếp bi như hình của từng thế, ăn theo luật 9 bi: luôn chạm '
            'bi số nhỏ nhất trước.',
        'S4' => 'Bi cái đặt tự do. Ăn hết bi sọc theo thứ tự tùy ý rồi tới bi 8. Bi xám là bi '
            'chướng ngại.',
        'S5' => 'Bi 1 ở (2, 3). Cụm 9 bi chướng ngại xếp khít trong khung giấy đích 8.5"×11" '
            'tâm (6, 1). Từ mỗi vị trí bi cái (${switch (v) {
              ExamIIVersion.bachelors => '3',
              ExamIIVersion.masters => '5',
              _ => '7',
            }} vị trí), đánh hợp lệ để bi 1 bị cụm bi che khỏi bi cái. Không được ăn bi 1; được '
            'chạm cụm bi nhưng mọi bi phải còn trong hoặc chồng lên khung.',
        'S6' => switch (v) {
            ExamIIVersion.bachelors => 'Bi cái cố định ở (1, 1). A băng (băng dài dưới) vào '
                'từng bi 1–3. Không chết cái, bi chạm băng sau va chạm.',
            ExamIIVersion.masters => 'Cú 1–4: bi cái cố định ở (1, 1), A băng một băng dài '
                'vào từng bi 1–4. Cú 5: bi cái đặt tự do, A băng hai băng bất kỳ vào bi 1.',
            _ => 'Cú 1–4: bi cái cố định ở (1, 1), A băng một băng dài vào từng bi 1–4. Cú 5, '
                '6: bi cái đặt tự do, A băng hai băng bất kỳ vào bi 1 và bi 3. Cú 7: bi cái đặt '
                'tự do, A băng ba băng bất kỳ vào bi 2.',
          },
        'S7' => switch (v) {
            ExamIIVersion.bachelors => 'Bi cái đặt tự do mỗi cú. Cân bi từng bi (cách nhau '
                'một khe một bi) chéo bàn vào lỗ giữa.',
            ExamIIVersion.masters => 'Bi mục tiêu ở (3, 3). Từ mỗi vị trí trong 5 vị trí bi '
                'cái, cân bi chéo bàn vào lỗ giữa.',
            _ => 'Bi mục tiêu ở (6, 3). Từ mỗi vị trí trong 7 vị trí bi cái, cân bi chéo bàn '
                'vào lỗ góc.',
          },
        'S8' => 'Dựng cơ: ăn từng bi mục tiêu vào lỗ góc dưới phải từ vị trí bi cái đã chỉ, '
            'không chết cái. Bi mục tiêu ở giữa bi cái và lỗ. Bi cái áp sát băng, hoặc áp '
            'sát bi chướng ngại thẳng hướng cú đánh.',
        'S9' => switch (v) {
            ExamIIVersion.bachelors => 'Bi cái ở (1, 1); hai bi chướng ngại cách nhau một khe '
                'một bi. Nhảy bi qua khe, hoặc mát xê vòng qua một bi (khi mát xê thì nhấc một '
                'bi chướng ngại ra), rồi ăn bi treo miệng lỗ góc.',
            ExamIIVersion.masters => 'Bi cái ở (1, 1), một bi chướng ngại trên đường bắn. Nhảy '
                'bi hoặc mát xê qua/vòng bi chướng ngại, rồi ăn bi treo miệng lỗ góc.',
            _ => 'Bi cái ở (1, 1), bi chướng ngại cách bi cái một khe hai bi trên đường bắn. '
                'Nhảy bi hoặc mát xê qua/vòng bi chướng ngại, đưa bi cái vào lỗ góc.',
          },
        'S10' => 'Phá giá 9 bi, bi cái đặt tự do sau vạch đầu bàn. Vùng đích của bi cái là 4 '
            'chấm ở giữa bàn. Phá 3 lần, chấm từng lần theo tiêu chí a–e.',
        _ => throw ArgumentError.value(drillId, 'drillId', 'chưa dịch cách xếp bài'),
      };

  // Sơ đồ bài kiểm tra — D12 của kế hoạch.
  static const buLayoutsTitle = 'Sơ đồ bài kiểm tra';
  static const buLayoutsEnd = 'Hết sơ đồ.';

  static String buLayoutCaption(BuLayout l, int k, int n) =>
      'Sơ đồ $k / $n · ${buDrillTitle(l.drillId)}'
      '${l.version == null ? '' : ' · ${buVersionName(l.version!)}'} · hình ${l.variant}';

  static String buLayoutSource(String source) => 'Nguồn: Billiard University — $source';

  // Bộ câu hỏi xác định hạng — spec mục 7.2.
  static const onboardingTitle = 'Xác định hạng';
  static const onboardingLater = 'Để sau';
  static const onboardingIntroTitle = 'Xác định hạng của bạn';
  static const onboardingIntroBody = 'Trả lời 8 câu hỏi ngắn, app gợi ý một hạng. Bạn '
      'xác nhận hoặc tự chọn hạng khác. Muốn có hạng đã kiểm chứng, hãy làm bài kiểm tra '
      'Billiard University ở mục Hồ sơ.';
  static const onboardingStart = 'Bắt đầu';
  static String onboardingQuestionCounter(int q) => 'Câu $q / 8';
  static const onboardingBack = 'Quay lại';
  static const onboardingNext = 'Tiếp';
  static const onboardingSuggestTitle = 'Hạng gợi ý cho bạn';
  static const onboardingConfirm = 'Xác nhận';
  static const onboardingChooseOther = 'Chọn hạng khác';
  static const onboardingChooseTitle = 'Chọn hạng của bạn';
  static const onboardingLocked = 'Hạng của bạn đã được kiểm chứng bằng bài kiểm tra '
      'Billiard University. Từ giờ chỉ bài kiểm tra mới đổi được hạng.';

  /// Câu miễn trừ bắt buộc ở mọi màn hiện hạng (spec mục 4.3).
  static const rankDisclaimer =
      'Đây là bảng hạng riêng của PoolCoachAI, tham khảo cách hiểu ở Hà Nội.';

  // Làm bài kiểm tra — spec mục 7.3.
  static const buTestTitle = 'Bài kiểm tra BU';
  static const buPrepTitle = 'Chuẩn bị';
  static const buPrepIntro = 'Bài kiểm tra gồm Đề I (Cơ bản) và Đề II (Kỹ năng) của '
      'Billiard University. Mỗi đề mất khoảng 40–60 phút. Điểm Đề I quyết định bản '
      'Đề II (Bachelors, Masters hoặc Doctorate). Đề II làm ngay hoặc để buổi khác đều được.';
  static const buSourceLine = 'Đề bài: Billiard University (billiarduniversity.org) — '
      'Dr. Dave Alciatore và Bob Jewett.';
  static const buTableSizeLabel = 'Kích thước bàn';
  static String buTableSize(TableSize s) => switch (s) {
        TableSize.sevenFoot => '7 feet',
        TableSize.eightFoot => '8 feet',
        TableSize.nineFootPlus => '9 feet trở lên',
      };
  static const buDoctorateNeedsNine = 'Bản Doctorate chỉ làm trên bàn 9 feet trở lên.';
  static const buStart = 'Bắt đầu Đề I';
  static String buRetestFrom(DateTime d) => 'Lần kiểm tra trước đã hoàn tất. '
      'Lần kế tiếp làm được từ ngày ${shortDate(d)}.';
  static const buLoadFailed = 'Không đọc được bài kiểm tra trên máy.';

  static String buRunnerHeader(BuExam exam, ExamIIVersion? v, int k, int n) =>
      '${buExamName(exam)}${v == null ? '' : ' · ${buVersionName(v)}'} · bài $k / $n';
  static String buRunningScore(BuExam exam, int score) =>
      'Điểm ${exam == BuExam.fundamentals ? 'Đề I' : 'Đề II'} hiện tại: $score';
  static String buLadderPosition(int p) => 'Vị trí hiện tại: $p';

  /// Lượt đang nhập, theo cách phiếu điểm BU chia ô.
  static String buAttemptLabel(BuDrill d, int index) {
    final i = index.clamp(0, d.attemptCount - 1);
    final group = i ~/ d.attemptsPerGroup + 1;
    final within = i % d.attemptsPerGroup + 1;
    return switch (d.kind) {
      ScoringKind.bestOfTwo => 'Lượt ${i + 1} / 2',
      ScoringKind.sumOfLowestTwo => 'Thế ${i + 1} / 3',
      ScoringKind.medianBreak => 'Lần phá ${i + 1} / 3',
      _ when d.id == 'F7' => 'Bi đích $group · lượt $within',
      _ when d.id == 'F8' => 'Đích $group · lượt $within',
      _ when d.id == 'S5' => 'Vị trí bi cái $group · lượt $within',
      _ => 'Cú ${i + 1} / ${d.attemptCount}',
    };
  }

  static String buShotYes(String drillId) => switch (drillId) {
        'S5' => 'Bắt đui được',
        'S6' => 'Chạm bi',
        'F7' || 'F8' || 'S8' || 'S9' => 'Đạt',
        _ => 'Vào',
      };

  static String buShotNo(String drillId) => switch (drillId) {
        'S5' => 'Không bắt đui',
        'F7' || 'F8' || 'S8' || 'S9' => 'Không đạt',
        _ => 'Trượt',
      };

  static const buCountLess = 'Bớt một bi';
  static const buCountMore = 'Thêm một bi';
  static String buCountOf(int n, int max) => '$n / $max bi';
  static const buCountSubmit = 'Ghi lượt';
  static const buBreakSubmit = 'Ghi lần phá';
  static const buUndo = 'Hoàn tác cú vừa nhập';
}
