import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/coach/coach_recommendation.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/hints.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/reveal.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart'
    show SkillSignal, percentOf;
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/roadmap/rank_check.dart'
    show RankCheckBasis, RankCheckDirection, RankCheckSignal;
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart' show dateOnly;
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis_constants.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart' as gate;
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
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
  /// Bảy lý do phải ra bảy câu khác nhau. Dùng chung một câu là lớp
  /// suy luận nói mà người chơi không nghe được gì.
  ///
  /// [signal] chỉ dùng cho [PickReason.matchWeakness]: có thì câu nêu số
  /// trận, số lần hỏng và tỷ lệ; không có thì câu không chứa con số nào.
  static String pickReason(
    PickReason reason,
    String skill, {
    SkillSignal? signal,
  }) => switch (reason) {
    PickReason.scheduled => 'Lịch tập hôm nay của bạn là $skill.',
    PickReason.streakAtRisk =>
      'Hai hôm rồi bạn chưa tập. Quay lại nhẹ nhàng với $skill.',
    PickReason.matchWeakness =>
      signal == null
          ? '$skill đang yếu khi thi đấu.'
          : 'Trong ${signal.matches} trận gần đây, $skill hỏng '
                '${signal.failures}/${signal.attempts} lần '
                '(${percentOf(signal.failures, signal.attempts)}%).',
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
  static const notFoundBody =
      'Đường dẫn này không tồn tại. Hãy quay lại '
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

  static const trainingTitle = 'Trung tâm luyện tập';

  static const playTitle = 'Thi đấu';
  static const matchStart = 'Ghi trận mới';
  static const matchEdit = 'Sửa thông tin trận';
  static const matchEditTitle = 'Sửa thông tin trận';
  static const matchSaveDetails = 'Lưu thay đổi';
  static const matchEmpty = 'Chưa có trận đấu nào được ghi.';
  static const matchGameType = 'Thể loại';
  static const matchEightBall = '8 bi';
  static const matchNineBall = '9 bi';
  static const matchTenBall = '10 bi';
  static const matchPlayerName = 'Tên của bạn';
  static const matchOpponentName = 'Tên đối thủ';
  static const matchTarget = 'Thắng bao nhiêu ván';
  static const matchStartAction = 'Bắt đầu trận';
  static const matchPlayerWinsRack = 'Tôi thắng ván';
  static const matchOpponentWinsRack = 'Đối thủ thắng ván';
  static const matchUndoRack = 'Hoàn tác ván gần nhất';
  static const matchDelete = 'Xóa trận';
  static const matchDeleteTitle = 'Xóa trận đấu?';
  static const matchDeleteBody =
      'Toàn bộ tỷ số và cú đánh đã ghi trong trận này sẽ bị xóa khỏi thiết bị.';
  static const matchDeleteConfirm = 'Xóa trận';
  static const matchRecordShot = 'Ghi cú đánh';
  static const matchUndoShot = 'Hoàn tác cú gần nhất';
  static const matchShooter = 'Người đánh';
  static const matchShotType = 'Loại cú';
  static const matchShotOutcome = 'Kết quả cú';
  static const matchPositionOutcome = 'Vị trí bi cái';
  static const matchPositionUnknown = 'Chưa ghi';
  static const matchPositionSuccessful = 'Đạt ý đồ';
  static const matchPositionUnsuccessful = 'Không đạt';
  static const matchShotNotes = 'Ghi chú (không bắt buộc)';
  static const matchSaveShot = 'Lưu cú đánh';
  static const matchShotRecorded = 'cú';
  static const matchBreakShot = 'Phá';
  static const matchNormalShot = 'Cú thường';
  static const matchSafetyShot = 'Phòng thủ';
  static const matchShotMade = 'Có bi';
  static const matchShotMissed = 'Trượt';
  static const matchShotFoul = 'Phạm lỗi';
  static const matchShotScratch = 'Chết cái';
  static const matchCompleted = 'Đã kết thúc';
  static const matchInProgress = 'Đang diễn ra';
  static const matchNameRequired = 'Nhập tên của cả hai người chơi.';
  static const matchTargetInvalid = 'Chọn số ván thắng hợp lệ.';
  static const matchStartFailed =
      'Không bắt đầu được trận đấu. Vui lòng thử lại.';
  static const matchRecordFailed =
      'Không cập nhật được kết quả trận đấu. Vui lòng thử lại.';
  static const matchEditFailed = 'Không sửa được trận đấu. Vui lòng thử lại.';
  static const matchDeleteFailed = 'Không xóa được trận đấu. Vui lòng thử lại.';
  static String matchTargetBelowLeader(int leaderWins) =>
      'Phải chọn ít nhất $leaderWins ván vì đã có người thắng $leaderWins ván.';
  static String matchScore(
    String player,
    int playerScore,
    int opponentScore,
    String opponent,
  ) => '$player $playerScore – $opponentScore $opponent';
  static const matchTournament = 'Giải đấu';
  static const matchNoTournament = 'Không thuộc giải nào';
  static const matchRound = 'Vòng (không bắt buộc)';
  static const tournamentRoundSuggestions = <String>[
    'Vòng loại',
    'Vòng bảng',
    'Tứ kết',
    'Bán kết',
    'Chung kết',
  ];
  static const matchRoundTooLong =
      'Vòng tối đa ${TournamentConstants.roundLabelMaxLength} ký tự.';
  static String matchTournamentLabel(String name, String? round) =>
      round == null ? name : '$name · $round';
  // --- Phân tích trận (spec 2026-10-28) ---
  static const matchAnalysisOpen = 'Phân tích trận';
  static String matchAnalysisRacks(int withShots, int full) =>
      '$withShots ván có ghi cú · $full ván ghi đủ';
  static const matchAnalysisNoShots =
      'Trận này chưa ghi cú đánh nên chưa phân tích được nguyên nhân. '
      'Ghi cú ở trận sau để xem phân tích.';
  static const matchAnalysisLostTitle = 'Nguyên nhân mất ván';
  static String lostRackCause(LostRackCause c, int n) => switch (c) {
    LostRackCause.offensiveMiss => 'Mất $n ván sau khi trượt cú tấn công',
    LostRackCause.safety => 'Mất $n ván sau cú phòng thủ',
    LostRackCause.foul => 'Mất $n ván sau khi phạm lỗi',
    LostRackCause.scratch => 'Mất $n ván sau khi chết cái',
    LostRackCause.dryBreak => 'Mất $n ván sau khi phá khô',
    LostRackCause.opponentBreakAndRun => 'Đối thủ phá-và-dọn $n ván',
    LostRackCause.notFull => '$n ván thua chưa ghi đủ cú',
    LostRackCause.unclear => '$n ván thua chưa rõ nguyên nhân',
  };
  static const matchAnalysisBreakTitle = 'Phá';
  static String matchAnalysisBreak(int shots, int made, int breakAndRuns) =>
      'Phá $shots ván, vào bi $made, phá-và-dọn $breakAndRuns';
  static String matchAnalysisOpponentBreak(
    String name,
    int shots,
    int made,
    int breakAndRuns,
  ) => '$name: phá $shots ván, vào bi $made, phá-và-dọn $breakAndRuns';
  static const matchAnalysisPositionTitle = 'Điều bi và lỗi';
  static String matchAnalysisPositionFouls(
    int failed,
    int assessed,
    int fouls,
    int scratches,
  ) => 'Điều bi hỏng $failed/$assessed, phạm lỗi $fouls, chết cái $scratches';
  static const matchAnalysisFocusTitle = 'Nên luyện';
  static String matchAnalysisFocus(String skill, int failures, int attempts) =>
      '$skill: hỏng $failures/$attempts lần trong trận này';
  static String matchAnalysisFocusDrill(String drill) => 'Bài nên tập: $drill';
  static const matchAnalysisFocusNone =
      'Trong trận này chưa có nhóm nào đủ '
      '${MatchAnalysisConstants.singleMatchMinAttempts} lần thử và vượt ngưỡng yếu.';

  // ─── Giải đấu (spec 2026-10-28) ───
  // Thành tích là chữ người chơi tự ghi; mọi con số do lib/domain/tournament tính ra.
  static const tournamentsTitle = 'Giải đấu';
  static const tournamentNone = 'Chưa có giải nào';
  static const tournamentNoneActive = 'Không có giải đang diễn ra hay sắp tới';
  static const tournamentListEmpty =
      'Chưa có giải nào. Thêm giải bạn sắp đánh hoặc đã đánh để ghi trận vào đó.';
  static const tournamentAdd = 'Thêm giải';
  static const tournamentAddTitle = 'Thêm giải';
  static const tournamentEditTitle = 'Sửa giải';
  static const tournamentSave = 'Lưu giải';
  static const tournamentName = 'Tên giải';
  static const tournamentStartDate = 'Ngày bắt đầu';
  static const tournamentEndDate = 'Ngày kết thúc (không bắt buộc)';
  static const tournamentNoEndDate = 'Chưa chọn';
  static const tournamentPickDate = 'Chọn ngày';
  static const tournamentClearDate = 'Bỏ ngày kết thúc';
  static const tournamentLocation = 'Địa điểm (không bắt buộc)';
  static const tournamentGameType = 'Loại bi (không bắt buộc)';
  static const tournamentNoGameType = 'Chưa chọn';
  static const tournamentResultNote = 'Thành tích (không bắt buộc)';
  static const tournamentResultHint = 'Ví dụ: Vào vòng 16';
  static const tournamentNotes = 'Ghi chú (không bắt buộc)';
  static String tournamentInputError(TournamentInputError e) => switch (e) {
    TournamentInputError.nameRequired => 'Nhập tên giải.',
    TournamentInputError.nameTooLong =>
      'Tên giải tối đa ${TournamentConstants.nameMaxLength} ký tự.',
    TournamentInputError.endBeforeStart =>
      'Ngày kết thúc không được trước ngày bắt đầu.',
    TournamentInputError.locationTooLong =>
      'Địa điểm tối đa ${TournamentConstants.locationMaxLength} ký tự.',
    TournamentInputError.resultNoteTooLong =>
      'Thành tích tối đa ${TournamentConstants.resultNoteMaxLength} ký tự.',
    TournamentInputError.notesTooLong =>
      'Ghi chú tối đa ${TournamentConstants.notesMaxLength} ký tự.',
  };
  static const tournamentSaveFailed = 'Không lưu được giải. Vui lòng thử lại.';
  static const tournamentDataError = 'Chưa tải được dữ liệu giải đấu.';
  static String tournamentStatusName(TournamentStatus s) => switch (s) {
    TournamentStatus.sapToi => 'Sắp tới',
    TournamentStatus.dangDienRa => 'Đang diễn ra',
    TournamentStatus.daXong => 'Đã xong',
  };
  static String tournamentDates(Tournament t) =>
      t.endDate == null || dateOnly(t.endDate!) == dateOnly(t.startDate)
      ? shortDate(t.startDate)
      : '${shortDate(t.startDate)} – ${shortDate(t.endDate!)}';
  static String tournamentStatusDates(TournamentStatus s, Tournament t) =>
      '${tournamentStatusName(s)} · ${tournamentDates(t)}';
  static String tournamentRecord(int won, int lost) =>
      'Thắng $won – thua $lost trận';
  static String tournamentResultLine(String note) => 'Thành tích: $note';
  static const tournamentSelfReported = 'Kết quả do bạn ghi';
  static const tournamentCompareTitle = 'Ở giải và trận thường';
  static String tournamentCompare(
    int inPercent,
    int inMatches,
    int regularPercent,
    int regularMatches,
  ) =>
      'Ở giải: thắng $inPercent% số ván ($inMatches trận) · '
      'Trận thường: thắng $regularPercent% số ván ($regularMatches trận)';
  static const tournamentCompareNotEnough =
      'Cần ít nhất ${MatchAnalysisConstants.minMatches} trận hoàn tất ở mỗi bên để so sánh';
  static const tournamentEdit = 'Sửa giải';
  static const tournamentDelete = 'Xóa giải';
  static const tournamentDeleteTitle = 'Xóa giải đấu?';
  static const tournamentDeleteBody =
      'Giải sẽ bị xóa. Các trận đã ghi vẫn còn và hiện như trận thường.';
  static const tournamentDeleteConfirm = 'Xóa giải';
  static const tournamentDeleteFailed =
      'Không xóa được giải. Vui lòng thử lại.';
  static const tournamentSummaryTitle = 'Tổng kết';
  static const tournamentSummaryEmpty =
      'Chưa có trận hoàn tất nào trong giải này.';
  static String tournamentRacks(int won, int lost) =>
      'Thắng $won – thua $lost ván';
  static String tournamentRackRate(int percent) => 'Tỷ lệ ván thắng: $percent%';
  static const tournamentMatchesTitle = 'Các trận';
  static const tournamentMatchesEmpty = 'Chưa có trận nào trong giải này.';
  static String tournamentMatchTitle(String? round, String opponent) =>
      round == null ? 'Gặp $opponent' : '$round · gặp $opponent';
  static const tournamentMatchWon = 'Thắng';
  static const tournamentMatchLost = 'Thua';
  static const tournamentAnalysisTitle = 'Phân tích các trận trong giải';
  static const tournamentStartMatch = 'Bắt đầu trận trong giải';
  static const tournamentPrepare = 'Chuẩn bị cho giải này';
  static const tournamentPreparing = 'Đang chuẩn bị cho giải này';
  static const tournamentOpenRoadmap = 'Mở Lộ trình';
  static const tournamentReplaceGoalTitle = 'Thay mục tiêu hiện tại?';
  static String tournamentReplaceGoalBody(String currentGoal) =>
      'Mục tiêu đang chạy: $currentGoal. Đặt mục tiêu chuẩn bị cho giải này '
      'thì mục tiêu cũ sẽ được thay.';
  static const tournamentGoalFailed =
      'Không đặt được mục tiêu. Vui lòng thử lại.';
  static const tournamentNotFoundTitle = 'Không tìm thấy giải';
  static const tournamentNotFoundBody =
      'Giải này không còn hoặc không thuộc tài khoản của bạn.';
  static const tournamentBackToList = 'Về danh sách giải';
  static String matchRaceTo(int target) => 'Chạm $target ván thắng';
  static String matchRackProgress(int count) => '$count ván đã ghi';
  static String matchRackLabel(int number) => 'Ván $number';
  static String matchShotNumber(int number) => 'Cú $number';
  static String matchShotCount(int count) => '$count $matchShotRecorded';
  static String matchGameTypeName(PoolGameType type) => switch (type) {
    PoolGameType.eightBall => matchEightBall,
    PoolGameType.nineBall => matchNineBall,
    PoolGameType.tenBall => matchTenBall,
  };
  static String matchShotTypeName(MatchShotType type) => switch (type) {
    MatchShotType.breakShot => matchBreakShot,
    MatchShotType.normal => matchNormalShot,
    MatchShotType.safety => matchSafetyShot,
  };
  static String matchShotOutcomeName(MatchShotOutcome outcome) =>
      switch (outcome) {
        MatchShotOutcome.made => matchShotMade,
        MatchShotOutcome.missed => matchShotMissed,
        MatchShotOutcome.foul => matchShotFoul,
        MatchShotOutcome.scratch => matchShotScratch,
      };
  static String matchPositionOutcomeName(PositionOutcome? outcome) =>
      switch (outcome) {
        PositionOutcome.successful => matchPositionSuccessful,
        PositionOutcome.unsuccessful => matchPositionUnsuccessful,
        null => matchPositionUnknown,
      };
  static String matchShotSummary(MatchShot shot, {required String shooter}) =>
      '${matchRackLabel(shot.rackNumber)} · ${matchShotNumber(shot.shotNumber)} · '
      '$shooter · ${matchShotTypeName(shot.type)} · '
      '${matchShotOutcomeName(shot.outcome)}';

  static const statsTitle = 'Thống kê';
  static const statsOverview = 'Tổng quan luyện tập';
  static const statsCombinedTitle = 'Nhịp tập và thi đấu tuần này';
  static const statsCombinedTraining = 'Buổi tập';
  static const statsCombinedPlay = 'Trận';
  static String statsCombinedSummary(
    int trainingSessions,
    int matches,
    int activeDays,
    int sharedDays,
  ) =>
      '$trainingSessions buổi tập · $matches trận · $activeDays ngày có hoạt động · '
      '$sharedDays ngày vừa tập vừa thi đấu';
  static String statsCombinedDayLabel(int weekday) => switch (weekday) {
    DateTime.monday => 'T2',
    DateTime.tuesday => 'T3',
    DateTime.wednesday => 'T4',
    DateTime.thursday => 'T5',
    DateTime.friday => 'T6',
    DateTime.saturday => 'T7',
    DateTime.sunday => 'CN',
    _ => '',
  };
  static String statsCombinedDaySemantics(
    int weekday,
    int trainingSessions,
    int matches,
  ) =>
      '${statsCombinedDayLabel(weekday)}: $trainingSessions buổi tập, $matches trận';
  static const statsCombinedEmpty =
      'Chưa có hoạt động tập hoặc thi đấu tuần này.';
  static const statsTotalSessions = 'Tổng buổi tập';
  static const statsDrillSessions = 'Buổi theo bài';
  static const statsTimerSessions = 'Buổi tập tự do';
  static const statsTimerTotal = 'Tổng thời gian tập tự do';
  static const statsDrillDurationTotal = 'Tổng thời lượng Drill đã đo';
  static String statsDrillDurationValue(int seconds, int sessionCount) =>
      '${statsDuration(seconds)} · $sessionCount buổi có dữ liệu';
  static const statsTimerWeek = 'Thời gian tập tự do tuần này';
  static const statsStreak = 'Chuỗi ngày tập hiện tại';
  static String statsStreakValue(int days) => '$days ngày';
  static String statsDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours giờ $minutes phút';
  }

  static const statsRecordedMatches = 'Trận đã ghi (hoàn tất)';
  static const statsMatchWinsLosses = 'Thắng / thua';
  static const statsRecordedShots = 'Cú đã ghi';
  static const statsMatchDetails = 'Chi tiết trận đấu';
  static const statsBreaks = 'Cú phá';
  static const statsSafeties = 'Cú phòng thủ';
  static const statsMisses = 'Cú trượt';
  static const statsFouls = 'Lỗi';
  static const statsScratches = 'Chết cái';
  static const statsPositionSuccess = 'Vị trí bi cái đạt ý đồ';
  static const statsNoShotRecords = 'Chưa có dữ liệu cú đánh.';
  static const statsSkills = 'Tiến bộ theo nhóm kỹ năng';
  static const statsDrillTrends = 'Xu hướng theo bài tập';
  static const statsScoredSessions = 'buổi có thể chấm';
  static const statsNoScoredSessions = 'Chưa có kết quả đủ dữ liệu để chấm.';
  static const statsNoDrillTrends = 'Hãy hoàn thành bài tập để xem xu hướng.';
  static const statsNoTraining =
      'Hoàn thành bài tập hoặc lưu buổi tập tự do để bắt đầu thống kê.';
  static const statsTargetAverage = 'Trung bình mục tiêu';
  static const statsMatchAnalysisTitle = 'Phân tích trận gần đây';
  static String statsMatchAnalysisBasis(int matches, int fullRacks) =>
      'Dựa trên $matches trận, $fullRacks ván ghi đủ';
  static const statsMatchAnalysisEmpty =
      'Chưa có trận hoàn tất nào có ghi cú. Ghi cú trong trận để xem phân tích.';
  static String statsBreakLine(
    int shots,
    int madePercent,
    int dry,
    int fouls,
    int scratches,
  ) =>
      'Phá: $shots cú · vào bi $madePercent% · phá khô $dry · phạm lỗi $fouls · chết cái $scratches';
  static String statsBreakAndRun(int breakAndRuns, int racksBroken) =>
      'Phá-và-dọn: $breakAndRuns/$racksBroken ván bạn phá';
  static String statsRunOuts(int n) => 'Dọn bàn: $n ván';
  static String statsOffense(int missed, int shots, int percent) =>
      'Tấn công: trượt $missed/$shots cú thường ($percent%)';
  static String statsPositionMiss(int failed, int assessed, int percent) =>
      'Điều bi hỏng: $failed/$assessed cú có ghi vị trí ($percent%)';

  /// Mỗi nửa chỉ hiện khi mẫu số của nó lớn hơn 0; cả hai bằng 0 thì rỗng.
  static String statsPositionFollowUp(
    int afterFailed,
    int nextFailed,
    int afterGood,
    int nextGood,
  ) {
    final parts = [
      if (nextFailed > 0) '$afterFailed/$nextFailed sau điều bi hỏng',
      if (nextGood > 0) '$afterGood/$nextGood sau điều bi tốt',
    ];
    return parts.isEmpty ? '' : 'Trượt cú kế tiếp: ${parts.join(', ')}';
  }

  /// Mỗi nửa chỉ hiện khi mẫu số của nó lớn hơn 0; cả hai bằng 0 thì rỗng.
  static String statsSafety(
    int successful,
    int assessed,
    int safetyTurnovers,
    int proactive,
  ) {
    final parts = [
      if (assessed > 0) 'thành công $successful/$assessed',
      if (proactive > 0)
        '$safetyTurnovers/$proactive lần mất lượt chủ động là phòng thủ',
    ];
    return parts.isEmpty ? '' : 'Phòng thủ: ${parts.join(' · ')}';
  }

  static String statsErrors(int fouls, int scratches, int shots) =>
      'Phạm lỗi $fouls, chết cái $scratches trên $shots cú';
  static const statsMatchWeakTitle = 'Nhóm yếu khi thi đấu';
  static String statsMatchWeak(
    String skill,
    int failures,
    int attempts,
    int percent,
  ) => '$skill: hỏng $failures/$attempts lần ($percent%)';
  static const statsMatchWeakNone =
      'Chưa đủ dữ liệu để kết luận (cần ít nhất ${MatchAnalysisConstants.minMatches} trận và ${MatchAnalysisConstants.minAttempts} lần thử mỗi nhóm).';
  static String statsMatchWeakNoneOverThreshold(int matches) =>
      'Không nhóm nào đủ mẫu vượt ngưỡng yếu trong $matches trận gần đây.';
  static String statsMatchCount(int recorded, int completed) =>
      '$recorded ($completed)';
  static String statsPositionCount(int success, int assessed) =>
      '$success / $assessed';
  static String statsPercent(int percent) => '$percent% mục tiêu';
  static String statsRecentResults(List<int> percentages) =>
      'Gần nhất: ${percentages.map((value) => '$value%').join(' · ')}';

  static const profileTitle = 'Hồ sơ';
  static const equipmentTitle = 'Cơ bi-a';
  static const equipmentCardBody =
      'Quản lý cơ chính, cơ phá, cơ nhảy và thông tin đầu cơ.';
  static const equipmentEmpty = 'Bạn chưa thêm cây cơ nào.';
  static const equipmentAdd = 'Thêm cơ';
  static const equipmentEdit = 'Sửa thông tin cơ';
  static const equipmentName = 'Tên cây cơ';
  static const equipmentNameRequired = 'Nhập tên cây cơ.';
  static const equipmentType = 'Loại cơ';
  static const equipmentPlayingCue = 'Cơ chính';
  static const equipmentBreakCue = 'Cơ phá';
  static const equipmentJumpCue = 'Cơ nhảy';
  static const equipmentBreakJumpCue = 'Cơ phá nhảy kết hợp';
  static const equipmentWeight = 'Trọng lượng (gram)';
  static const equipmentShaftBrand = 'Hãng ngọn';
  static const equipmentShaftDiameter = 'Size ngọn (đường kính)';
  static const unitMm = 'mm';
  static const equipmentTipBrand = 'Hãng đầu tẩy';
  static const equipmentButtBrand = 'Hãng chuôi';
  static const equipmentTipHardness = 'Độ cứng đầu tẩy';
  static const equipmentNoHardness = 'Không chọn';
  static const equipmentSoft = 'Mềm';
  static const equipmentMedium = 'Trung bình';
  static const equipmentHard = 'Cứng';
  static const equipmentSkills = 'Nhóm kỹ năng phù hợp';
  static const equipmentLastMaintenance = 'Lần bảo dưỡng đầu cơ gần nhất';
  static const equipmentDueDate = 'Ngày dự kiến bảo dưỡng tiếp';
  static const equipmentNoDate = 'Chưa đặt';
  static const equipmentSelectDate = 'Chọn ngày';
  static const equipmentClearDate = 'Xóa ngày';
  static const equipmentDueDateInvalid =
      'Ngày bảo dưỡng tiếp theo phải sau lần bảo dưỡng gần nhất.';
  static const equipmentSave = 'Lưu cơ';
  static const equipmentDelete = 'Xóa cơ';
  static const equipmentDeleteQuestion = 'Xóa hồ sơ cây cơ này?';
  static const equipmentDeleteWarning =
      'Các buổi tập trước vẫn được giữ nhưng sẽ không còn liên kết với cây cơ này.';
  static const equipmentDeleteFailed =
      'Không xóa được hồ sơ cơ. Vui lòng thử lại.';
  static const equipmentSaveFailed =
      'Không lưu được hồ sơ cơ. Vui lòng thử lại.';
  static const equipmentWeightInvalid = 'Nhập trọng lượng tính bằng gram.';
  static const equipmentShaftDiameterInvalid =
      'Nhập size ngọn (đường kính) tính bằng mm.';
  static const equipmentDue = 'Đã đến ngày bảo dưỡng đầu cơ.';
  static const equipmentDueSoon = 'Sắp đến ngày bảo dưỡng đầu cơ.';
  static const equipmentReminderTitle = 'Nhắc bảo dưỡng đầu cơ';
  static const equipmentNotificationTitle = 'Đến lịch bảo dưỡng đầu cơ';
  static String equipmentNotificationBody(String cueName, int daysBefore) =>
      '$cueName: lịch bảo dưỡng ${daysBefore == 0 ? 'hôm nay' : 'sau $daysBefore ngày'}.';
  static const equipmentReminderEnabled =
      'Trình duyệt sẽ nhắc lúc 09:00 ngày đến hạn và 7 ngày trước đó khi ứng dụng đang mở.';
  static const equipmentReminderDenied =
      'Quyền thông báo đang bị chặn. Hãy bật lại trong cài đặt trang web của trình duyệt.';
  static const equipmentReminderEnable = 'Bật thông báo';
  static const equipmentReminderPrompt =
      'Thông báo lúc 09:00 ngày đến hạn và 7 ngày trước đó. Chỉ hoạt động khi ứng dụng đang mở.';
  static const equipmentPracticeTime = 'Thời gian tập với cơ';
  static const equipmentLastUsed = 'Lần dùng gần nhất';
  static const equipmentNoRecordedPractice = 'Chưa có buổi tập ghi với cơ này.';
  static const equipmentUnknownCue = 'Cơ đã xóa';
  static const matchCue = 'Cơ dùng trong trận';
  static String matchCueLine(String cueName) => 'Cơ: $cueName';
  static const cueWinRateTitle = 'Tỉ lệ thắng theo cơ';
  static const cueWinRateNoMatches = 'Chưa có trận hoàn tất nào ghi cơ.';
  static const cueBestBadge = 'Cơ hợp bạn nhất';
  static String cueWinRateLine({
    required int wins,
    required int completed,
    required int percent,
  }) => '$wins thắng / $completed trận hoàn tất · $percent%';
  static const cueWinRateNone = 'Chưa có trận hoàn tất với cơ này.';
  static String cueMatchesNeeded(int count) =>
      'Cần thêm $count trận hoàn tất để so sánh.';
  static String cueVerdictRule(int minMatches) =>
      'Cơ hợp bạn nhất chỉ được nêu khi có ít nhất hai cơ, mỗi cơ từ '
      '$minMatches trận hoàn tất, và một cơ có tỉ lệ thắng cao hơn hẳn các cơ còn lại.';
  static const timerChooseCue = 'Cơ đang dùng (không bắt buộc)';
  static const timerNoCue = 'Không chọn cơ';
  static String equipmentTypeName(CueType type) => switch (type) {
    CueType.playing => equipmentPlayingCue,
    CueType.breakCue => equipmentBreakCue,
    CueType.jump => equipmentJumpCue,
    CueType.breakJump => equipmentBreakJumpCue,
  };
  static String equipmentHardnessName(TipHardness hardness) =>
      switch (hardness) {
        TipHardness.soft => equipmentSoft,
        TipHardness.medium => equipmentMedium,
        TipHardness.hard => equipmentHard,
      };
  static String equipmentShaftBrandValue(String brand) => 'Ngọn $brand';
  static String equipmentTipBrandValue(String brand) => 'Đầu tẩy $brand';
  static String equipmentButtBrandValue(String brand) => 'Chuôi $brand';
  static String equipmentWeightValue(int grams) => '$grams g';
  static String equipmentDiameterValue(double millimeters) =>
      '${millimeters.toStringAsFixed(1)} mm';

  // Thông báo — nội dung do bộ lập lịch (lib/domain/notifications) điền
  // từ dữ liệu thật của người chơi.
  static String notificationKind(NotificationKind kind) => switch (kind) {
    NotificationKind.maintenance => 'Bảo dưỡng đầu cơ',
    NotificationKind.schedule => 'Lịch tập',
    NotificationKind.streak => 'Chuỗi ngày tập',
  };
  static String notificationKindHint(NotificationKind kind) => switch (kind) {
    NotificationKind.maintenance =>
      'Lúc 09:00, 7 ngày trước và đúng ngày đến hạn bảo dưỡng đầu cơ.',
    NotificationKind.schedule =>
      'Nhắc $scheduleReminderLeadMinutes phút trước mỗi khung giờ trong lịch tập tuần.',
    NotificationKind.streak =>
      'Lúc $streakReminderHour:00 nếu bạn có chuỗi từ $streakReminderMinDays ngày trở lên mà hôm nay chưa ghi buổi tập.',
  };
  static const scheduleReminderTitle = 'Sắp đến giờ tập';
  static String scheduleReminderBody(
    String label,
    String time,
    int minutesBefore,
    SkillCategory? category,
  ) =>
      '$label bắt đầu lúc $time, còn $minutesBefore phút.'
      '${category == null ? '' : ' Nhóm kỹ năng: ${skill(category)}.'}';
  static const streakReminderTitle = 'Giữ chuỗi ngày tập';
  static String streakReminderBody(int days) =>
      'Bạn đang có chuỗi $days ngày tập liên tiếp nhưng hôm nay chưa ghi buổi tập nào.';

  static const notificationsSettingsTitle = 'Loại thông báo';
  static const notificationsUpcomingTitle = 'Sắp tới trong 7 ngày';
  static const notificationsUpcomingEmpty =
      'Chưa có thông báo nào trong 7 ngày tới.';
  static const notificationsToday = 'Hôm nay';
  static const notificationsTomorrow = 'Ngày mai';
  static String notificationsDay(DateTime day) =>
      '${scheduleDays[day.weekday - 1]}, '
      '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}';
  static String notificationsTime(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  static const notificationsPermissionTitle = 'Quyền thông báo';
  static const notificationsPermissionGranted = 'Đã bật thông báo.';
  static const notificationsPermissionDenied =
      'Quyền thông báo đang bị chặn. Hãy bật lại trong cài đặt của thiết bị hoặc trình duyệt.';
  static const notificationsPermissionPrompt =
      'Bật thông báo để nhận nhắc bảo dưỡng, nhắc giờ tập và nhắc giữ chuỗi.';
  static const notificationsPermissionUnsupported =
      'Thiết bị hoặc trình duyệt này không hỗ trợ thông báo.';
  static const notificationsWebOnlyWhileOpen =
      'Trên trình duyệt, thông báo chỉ hiện khi ứng dụng đang mở.';

  // Màn AI Home — mục 6.1 của thiết kế lát dọc Phase 1.
  //
  // Bốn khối: chuỗi ngày tập, nhóm hôm nay kèm lý do, bài tập gợi ý,
  // bài đọc. Chữ cố định nằm ở đây; con số và tên bài do lớp suy luận
  // đưa lên, không viết sẵn ở bất kỳ đâu.
  static const homeStreakUnit = 'ngày tập liên tiếp';
  static String homePracticeWeek(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return 'Tuần này: $hours giờ $minutes phút tập tự do';
  }

  static const homeScheduleTitle = 'Lịch tập hôm nay';
  static const homeNoScheduleToday = 'Hôm nay chưa có lịch tập.';
  static const homeTodayTitle = 'Hôm nay';
  static const homeDrillTitle = 'Bài tập gợi ý';
  static const homeDrillOpen = 'Mở';
  static const homeArticleTitle = 'Bài đọc hôm nay';

  /// Khi nhóm hôm nay đã tập hết bài.
  ///
  /// Không đổi sang bài của nhóm khác: gợi ý phải trung thành với
  /// nhóm mà bảy luật ưu tiên đã chọn, nói thật là hết bài thì hơn.
  static const homeDrillAllDone =
      'Hôm nay bạn đã tập hết bài trong nhóm này rồi.';

  // Màn đọc kiến thức — mục 6.5 của thiết kế.
  static const knowledgeTitle = 'Bài đọc';
  static const knowledgeRelatedTitle = 'Bài tập liên quan';

  // Thư viện kiến thức: danh sách mọi bài đọc.
  static const knowledgeLibraryTitle = 'Kiến thức';
  static const knowledgeLibraryCardBody =
      'Các bài đọc về kỹ thuật, theo từng nhóm kỹ năng.';
  static const knowledgeLibraryEmpty = 'Chưa có bài kiến thức nào.';

  /// Tiêu đề khối trên chi tiết bài tập: các bài đọc nhắc tới bài này.
  static const drillReadArticles = 'Đọc bài liên quan';

  // Khi không đọc được dữ liệu.
  //
  // Không in nội dung ngoại lệ ra màn hình: nó là tiếng Anh, lộ cấu
  // trúc bên trong và chẳng giúp gì người chơi — cùng một lý do đã
  // khiến màn không tìm thấy phải tự viết bằng tiếng Việt.
  static const dataErrorTitle = 'Không đọc được dữ liệu';
  static const dataErrorBody =
      'Có trục trặc khi đọc dữ liệu luyện tập. '
      'Hãy đóng app rồi mở lại.';

  // Thư viện bài tập — mục 6.2 của thiết kế.
  static const trainingFilterAll = 'Tất cả';
  static const timerTitle = 'Đồng hồ luyện tập';
  static const scheduleTitle = 'Lịch tập tuần';
  static const timerCardBody =
      'Tập tự do có bấm giờ, lưu thời lượng vào tiến độ.';
  static const scheduleCardBody =
      'Lên lịch tập cố định theo ngày và giờ trong tuần.';
  static const timerCountUp = 'Đếm lên';
  static const timerCountDown = 'Đếm ngược';
  static const timerGoalDuration = 'Thời lượng mục tiêu';
  static const timerHistoryTitle = 'Buổi tập gần đây';
  static const timerNoCategory = 'Không chọn';
  static String timerTargetMinutes(int minutes) => '$minutes phút';
  static const timerStart = 'Bắt đầu';
  static const timerPause = 'Tạm dừng';
  static const timerResume = 'Tiếp tục';
  static const timerFinish = 'Kết thúc và lưu';
  static const timerChooseCategory = 'Nhóm kỹ năng (không bắt buộc)';
  static const timerSaved = 'Đã lưu buổi tập';
  static const timerSaveFailed = 'Không lưu được buổi tập. Vui lòng thử lại.';
  static const timerEmptyHistory = 'Chưa có buổi tập tự do nào.';
  static const scheduleAdd = 'Thêm lịch';
  static const scheduleEdit = 'Sửa lịch';
  static const scheduleEditTooltip = 'Sửa khung giờ tập';
  static const scheduleEmpty = 'Chưa có lịch tập. Hãy thêm khung giờ đầu tiên.';
  static const scheduleLabel = 'Tên buổi tập';
  static const scheduleChooseDay = 'Ngày trong tuần';
  static const scheduleChooseTime = 'Giờ bắt đầu';
  static const scheduleChooseCategory = 'Nhóm kỹ năng (không bắt buộc)';
  static const scheduleNoCategory = 'Không chọn';
  static const scheduleSave = 'Lưu lịch';
  static const scheduleCancel = 'Hủy';
  static const scheduleLabelRequired = 'Nhập tên buổi tập.';
  static const scheduleDeleteQuestion = 'Xóa khung giờ tập này?';
  static const scheduleKeep = 'Giữ lại';
  static const scheduleDelete = 'Xóa';
  static const scheduleDeleteTooltip = 'Xóa lịch';
  static const scheduleSaveFailed =
      'Không lưu được lịch tập. Vui lòng thử lại.';
  static const scheduleDeleteFailed =
      'Không xóa được lịch tập. Vui lòng thử lại.';
  static const scheduleDays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// Tỉ lệ đạt mục tiêu của lần tập gần nhất, hiện theo phần trăm.
  ///
  /// `1.0` là đúng mục tiêu nên hiện 100%. Đây là số do [drillRatio]
  /// tính, **không** phải điểm thô người chơi nhập: bài đạt khi trúng
  /// 8 trên 10 thì trúng 9 là 113% mục tiêu, không phải "9".
  static String drillRatioPercent(double ratio) => '${(ratio * 100).round()}%';

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
  static const drillReadinessTitle = 'Tiến độ buổi đạt liên tiếp';
  static String drillReadinessProgress(int count) =>
      'Buổi đạt liên tiếp: $count / ${PracticeConstants.readyStreak}';
  static const drillReadinessQualified =
      'Đã đạt số buổi liên tiếp theo yêu cầu.';
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
  static const sessionDurationRecordedAutomatically =
      'Thời lượng được tính từ lúc mở buổi tập đến khi lưu kết quả; thời gian ứng dụng ở nền không tính.';

  // Chặn ngay tại nút lưu, kèm câu giải thích. Lưu một log méo rồi để
  // drillRatio() trả null về sau là đẩy lỗi đi xa khỏi chỗ gây ra nó.
  static const sessionScoreRequired = 'Nhập kết quả';
  static const sessionScoreInvalid = 'Nhập số hợp lệ';
  static const sessionAttemptsRequired = 'Bài này cần nhập số lần thử';
  static const sessionAttemptsInvalid = 'Nhập số nguyên dương';
  static const sessionSaveFailed = 'Không lưu được kết quả. Hãy thử lại.';

  // Skill Test và chứng nhận (spec 2026-10-28)
  static String skillTestTitle(String drillName) => 'Kiểm tra: $drillName';
  static const skillTestConditionsTitle = 'Điều kiện đo';
  static String skillTestCriterion(Drill drill) => drill.usesAttempts
      ? 'Tiêu chí đạt: từ ${(drill.passThreshold! * 100).round()}% số lần thử'
      : 'Tiêu chí đạt: từ ${skillTestNumber(drill.target!)}, đơn vị: ${drill.unit}';

  /// Tiêu chí mà lần kiểm tra đã được chấm theo, lấy từ ảnh chụp lúc hoàn
  /// tất (không phải bài hiện tại). Null khi không có ảnh chụp.
  static String? skillTestGradedAgainst(SkillTest test, String unit) =>
      criterionSnapshot(test.passThreshold, test.target, unit);

  static String? criterionSnapshot(
    double? threshold,
    num? target,
    String unit,
  ) {
    if (threshold != null) {
      return 'Chấm theo tiêu chí: từ ${(threshold * 100).round()}% số lần thử';
    }
    if (target != null) {
      return 'Chấm theo tiêu chí: từ ${skillTestNumber(target)}, đơn vị: $unit';
    }
    return null;
  }

  static const certificationTitle = 'Chứng nhận';
  static const certificationEmpty = 'Chưa có chứng nhận';
  static String certificationClosest(String drillName, int count) =>
      'Gần sẵn sàng nhất: $drillName — $count/${PracticeConstants.readyStreak} buổi đạt liên tiếp';
  static const certificationNoProgress = 'Chưa bài nào có buổi đạt liên tiếp.';
  static String certificationEntry(String drillName, int level, DateTime at) =>
      '$drillName — cấp $level — ${shortDate(at)}';

  /// Điều kiện đo của lần đạt: cỡ bàn và kết quả (đếm cú hoặc theo đơn vị).
  static String certificationEvidence(
    TableSize size,
    num? score,
    int? attempts,
    String unit,
  ) {
    final table = 'Bàn ${buTableSize(size)}';
    if (score == null) return table;
    return attempts != null
        ? '$table · ${skillTestNumber(score)}/$attempts lần thử'
        : '$table · ${skillTestNumber(score)} $unit';
  }

  static const certificationGroupDone = 'Đã chứng nhận toàn nhóm';
  static String homeSkillTestReady(String drillName, int more) => more == 0
      ? 'Sẵn sàng kiểm tra: $drillName'
      : 'Sẵn sàng kiểm tra: $drillName (và $more bài khác)';

  static const skillTestStart = 'Bắt đầu kiểm tra';
  static const skillTestSubmit = 'Nộp kết quả';
  static const skillTestCancel = 'Huỷ bài kiểm tra';
  static const skillTestCancelled =
      'Đã huỷ bài kiểm tra. Không có kết quả nào được lưu.';
  static const skillTestCancelConfirmTitle = 'Huỷ bài kiểm tra?';
  static const skillTestCancelConfirmBody =
      'Kết quả đang nhập sẽ không được lưu và không tính là trượt.';
  static const skillTestCancelConfirm = 'Huỷ bài';
  static const skillTestKeepGoing = 'Tiếp tục làm bài';
  static const skillTestCardTitle = 'Bài kiểm tra';
  static const skillTestOpen = 'Làm bài kiểm tra';
  static const skillTestFormSlipped = 'Phong độ gần đây chưa đạt';
  static const certifiedBadge = 'Đã chứng nhận';
  static const skillTestDataError = 'Chưa tải được dữ liệu bài kiểm tra.';
  static String skillTestPassed(String drillName, int level) =>
      'Đã chứng nhận $drillName — cấp $level';
  static String skillTestFailed(num score, num mark) =>
      'Chưa đạt: ${skillTestNumber(score)}/${skillTestNumber(mark)}';
  static const skillTestFailedAdvice = 'Tập thêm bài này rồi kiểm tra lại';
  static const skillTestRetakeRule =
      'Cần ít nhất ${SkillTestConstants.retakeSessions} buổi tập mới của bài này trước lần kiểm tra lại.';
  static String skillTestNextLevel(List<String> names) =>
      'Cấp tiếp theo trong nhóm: ${names.join(', ')}';
  static const skillTestNoNextLevel = 'Chưa có cấp tiếp theo trong nhóm này';
  static const skillTestBackToDrill = 'Về bài tập';
  static const skillTestNotFoundTitle = 'Không tìm thấy bài tập';
  static const skillTestNotFoundBody =
      'Bài tập này không còn trong thư viện, nên không thể làm bài kiểm tra.';
  static String skillTestNumber(num n) =>
      n == n.truncate() ? '${n.truncate()}' : '$n'.replaceAll('.', ',');
  static String skillTestGateLine(
    gate.SkillTestGate g, {
    required String Function(String drillId) nameOf,
  }) => switch (g) {
    gate.SkillTestOpen() => 'Đủ điều kiện làm bài kiểm tra',
    gate.AlreadyCertified(:final at) => 'Đã chứng nhận ngày ${shortDate(at)}',
    gate.NeedLowerLevel(:final drillIds) =>
      'Cần chứng nhận ${drillIds.map(nameOf).join(', ')} trước',
    gate.NeedStreak(:final missing) => 'Cần thêm $missing buổi đạt liên tiếp',
    gate.NeedPracticeAfterFail() => skillTestRetakeRule,
  };
  static String skillTestInputError(SkillTestInputError e) => switch (e) {
    SkillTestInputError.scoreInvalid => sessionScoreInvalid,
    SkillTestInputError.scoreNotWhole => 'Số lần đạt phải là số nguyên',
    SkillTestInputError.scoreAboveAttempts =>
      'Số lần đạt không được lớn hơn số lần thử',
    SkillTestInputError.attemptsRequired => sessionAttemptsRequired,
    SkillTestInputError.attemptsInvalid => sessionAttemptsInvalid,
    SkillTestInputError.attemptsNotAllowed =>
      'Bài này không chấm theo số lần thử',
  };

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
  static const signOutPendingTitle = 'Còn dữ liệu chưa đồng bộ';
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
  static const simDisclaimer =
      'Lực và đầu cơ là gợi ý định hướng dựa trên '
      'hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, '
      'người chơi vẫn cần tự canh lực thực tế.';

  /// Gắn sau mức áp phê mà lời khuyên gợi ý, khi mức đó dễ trượt cơ.
  static const simMiscueClause = ' (dễ Trượt cơ)';

  static String get simMiscue =>
      'Lệch ${simTips(miscueTips)} đầu cơ dễ trượt cơ.';

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
    UnmakeableReason.tooThin => 'Góc cắt quá lớn (>${maxCutAngle.round()}°).',
    UnmakeableReason.cueBlocked => 'Đường bi cái tới bi ảo bị bi khác chắn.',
    UnmakeableReason.objectBlocked =>
      'Đường bi mục tiêu vào lỗ bị bi khác chắn.',
  };

  static String simPocketLine(Pocket pocket) => 'Lỗ: ${simPocket(pocket)}';
  static String simAngleLine(double angle) => 'Góc cắt: ${angle.round()}°';
  static String simBandLine(DifficultyBand band) => 'Độ khó: ${simBand(band)}';
  static String simStrokeLine(Stroke stroke) =>
      'Kiểu đánh: ${simStroke(stroke)}';
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

  /// Góc lệch do áp phê, độ, làm tròn 0.5° — thông tin chủ sản phẩm đã
  /// duyệt, không phải lời khuyên ngắm. Có [spin], [bhePercent] và [speed]
  /// thì nối thêm đúng câu áp phê mẫu SAWS mà Coach dùng ([sawsSpinAdvice]);
  /// không còn vế "điểm ngắm cần lệch" hay "ngắm lệch đi" (chủ sản phẩm chốt
  /// Q5, 21/10/2026). Dòng nào cũng kết bằng dấu chấm.
  static String simSquirt(
    double deg, [
    SideSpin? spin,
    int? bhePercent,
    SawsSpeed? speed,
  ]) {
    final base =
        'Bi cái bị lệch do áp phê khoảng ${_rounded(deg.abs(), 0.5)}°.';
    final side = spin?.side;
    if (side == null || bhePercent == null || speed == null) return base;
    return '$base ${sawsSpinAdvice(side, spin!.tips, bhePercent, speed)}';
  }

  /// Chữ chỉ lực của cột SAWS: Chậm / Vừa / Nhanh là lực nhẹ / trung bình /
  /// mạnh (chủ sản phẩm chốt 05/10/2026).
  static String sawsSpeedWord(SawsSpeed speed) => switch (speed) {
    SawsSpeed.slow => 'nhẹ',
    SawsSpeed.medium => 'trung bình',
    SawsSpeed.fast => 'mạnh',
  };

  /// Câu áp phê mẫu SAWS của chủ sản phẩm (05/10/2026): số đầu cơ, "ngắm
  /// như đánh tâm bi", % BHE / FHE và chữ chỉ lực. Một hàm cho cả màn Mô
  /// phỏng, Kế hoạch dọn bàn và Coach. Không có số độ, không có "ngắm lệch".
  static String sawsSpinAdvice(
    SpinSide side,
    double tips,
    int bhePercent,
    SawsSpeed speed,
  ) =>
      'Cú này cần áp phê ${_side(side)} ${simTips(tips)} đầu cơ. '
      'Hãy ngắm như đánh tâm bi, bù trừ áp phê bằng $bhePercent% BHE, '
      '${100 - bhePercent}% FHE với lực ${sawsSpeedWord(speed)}.';

  static String simRailCount(int count) => 'Bi cái chạm băng $count lần.';

  static String simAdvice(Advice advice) => switch (advice) {
    AddSpinToAvoid(:final from, :final to, :final pocket) => _avoidText(
      from,
      to,
      pocket,
    ),
    NoSpinAvoids(:final pocket) =>
      'Bi cái chết cái ở lỗ '
          '${simPocket(pocket)}, áp phê không cứu được — đổi lực hoặc kiểu đánh.',
    OverhitRisk(
      :final margin,
      :final fromPower,
      :final pocket,
      :final saferSpin,
    ) =>
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
  static const planOrderHint =
      'Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…';
  static const planUndo = 'Xoá bi cuối';
  static const planClear = 'Xoá hết';
  static const planStart = 'Lập kế hoạch';

  static String planComputing(int step, int total) =>
      'Đang tính bước $step/$total…';
  static String planStepHeader(int step, int total) => 'Bước $step / $total';
  static String planBallLine(int number) => 'Bi $number';

  /// Số mức lực (trong [samples] mức) mà điểm dừng vẫn trong vùng điều tốt.
  static String planTolerance(int good, int samples) =>
      '$good/$samples mức lực vẫn trong vùng điều tốt';

  /// Thông tin, không phải cảnh báo. Không còn vế "hao khoảng 15% lực":
  /// lõi vật lý tính hao lực thật (spec quyết định 7).
  static String planRailInfo(int count) =>
      'Bi cái chạm băng $count lần rồi tới vùng điều.';

  /// Bước cuối: không có bi kế tiếp, nên không có vùng điều để tới.
  static String planRailInfoLast(int count) => 'Bi cái chạm băng $count lần.';

  /// PRD §6.5, nguyên văn.
  static const planRiskWarning =
      'Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái '
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
  static const planSafetyCheckpoint =
      'Tính toán cơ bản thì đánh như thế này là thủ tốt, '
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
  static String planSetupSummary({required bool hasCue, required int balls}) =>
      hasCue
      ? 'Bàn bày bi. Đã đặt bi cái, $balls bi mục tiêu.'
      : 'Bàn bày bi. Chưa đặt bi cái.';

  static const planResetSummary = 'Bàn kế hoạch. Đang đặt lại bi cái.';

  /// Nhãn semantics của bàn ở màn từng bước (spec mục 7.4): bi, lỗ, kiểu
  /// đánh, lực của bước đang xem; bước phòng thủ có cú thủ thì câu đầu, câu
  /// ngắm và kết quả cho đối thủ. [step] null khi bước đầu còn đang tính.
  static String planSummary(
    PlanStep? step, {
    required int index,
    required int total,
    bool searchingSafety = false,
  }) {
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
  static String safetySnookered(int ballNum) =>
      'Bi cái bị đui bi $ballNum — đánh A băng để thủ.';
  static const safetyNoPot = 'Không còn đường ăn bi — nên thủ bi.';

  static String safetyHeadline(SafetyShot s) =>
      s.reason == SafetyReason.snookered
      ? safetySnookered(s.ballNum)
      : safetyNoPot;

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

  static String _fraction(double thickness) =>
      switch ((thickness * 8).round()) {
        6 => '¾',
        4 => '½',
        2 => '¼',
        1 => '⅛',
        _ => '${(thickness * 100).round()}%',
      };

  /// Độ dày chạm bi, theo hướng nhìn từ bi cái.
  static String safetyThickness(double thickness, ThicknessSide side) =>
      switch (side) {
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

  static String buDrillTitle(String drillId) =>
      '$drillId · ${buDrillName(drillId)}';

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
    1 => const [
      'Chưa từng chơi',
      'Dưới 3 tháng',
      '3 – 6 tháng',
      '6 tháng – 1 năm',
      '1 – 2 năm',
      '2 – 5 năm',
      'Trên 5 năm',
    ],
    2 => const [
      'Dưới 2 giờ / tuần',
      '2 – 5 giờ / tuần',
      '5 – 10 giờ / tuần',
      '10 – 20 giờ / tuần',
      'Trên 20 giờ / tuần',
    ],
    3 => const ['1', '2', '3', '4', '5', '6', '7', '8', 'Dọn bàn (Run Out)'],
    4 => const ['1', '2', '3', '4', '5', '6+', 'Thường xuyên Runout'],
    5 => const [
      'Chưa bao giờ',
      'Đã từng 1–2 lần',
      'Thỉnh thoảng',
      'Khá thường xuyên',
      'Rất thường xuyên',
    ],
    6 => const [
      'Chưa từng',
      'Hơn 100 rack',
      'Khoảng 50 rack',
      'Khoảng 20 rack',
      'Khoảng 10 rack',
      'Khoảng 5 rack',
      'Khoảng 2–3 rack',
      'Gần như rack nào cũng có thể',
    ],
    7 => const [
      'Thường không có bi đánh tiếp',
      'Thường chỉ có 1 bi',
      'Có thể đi tiếp 2–3 bi',
      'Thường có layout thuận lợi',
      'Thường có cơ hội đi chấm',
    ],
    8 => const [
      'Thường xuyên bị khó',
      'Có lúc dễ, có lúc khó',
      'Phần lớn còn bi đánh tiếp',
      'Thường chủ động điều được bi cái',
      'Có thể điều bi chính xác theo ý muốn',
    ],
    _ => throw RangeError.range(question, 1, 8, 'question'),
  };

  static String rankDescription(Rank rank) => switch (rank) {
    Rank.k => 'Người mới làm quen với Pool',
    Rank.i => 'Đã biết luật chơi, kỹ thuật cơ bản',
    Rank.h => 'Người chơi phong trào phổ biến, bắt đầu có khả năng điều bi',
    Rank.g => 'Người chơi phong trào khá, có thể thi đấu ổn định với đa số CLB',
    Rank.f =>
      'Bước đầu tham gia sân chơi thi đấu, trình độ cao trong nhóm phong trào',
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

  static const _ladderRule =
      'Thang vị trí: bắt đầu ở vị trí 4, vào thì lên một vị trí, '
      'trượt thì xuống một (trong khoảng 1–7). Đánh đủ 10 cú. Điểm = vị trí cuối + '
      'số lần vào khi đang ở vị trí 7, tối đa 10.';

  static String buDrillScoring(
    String drillId,
    ExamIIVersion? v,
  ) => switch (drillId) {
    'F1' => _ladderRule,
    'F2' =>
      '$_ladderRule Bi mục tiêu phải vào và bi cái dừng chồng lên vòng bi ảo.',
    'F3' => '$_ladderRule Bi cái dừng trong hoặc chồng lên khung giấy đích.',
    'F4' =>
      '$_ladderRule Tâm bi cái dừng trong hình chữ nhật 2×1 chấm cạnh lỗ giữa.',
    'F5' =>
      '$_ladderRule Đích di chuyển thay cho bi cái: vị trí 1–3 đi thẳng tới đích, '
          '5–7 phải bật băng cuối.',
    'F6' => '10 cú, mỗi cú 1 lượt, không được chết cái. Mỗi bi vào 1 điểm.',
    'F7' => '10 bi đích trên băng, mỗi bi 2 lượt. Vào lỗ và chạm đúng bi đích được 1 điểm.',
    'F8' =>
      '5 đích, mỗi đích 4 lượt. Vào lỗ và bi cái dừng trong hoặc chồng lên đích '
          'được 1 điểm.',
    'S1' =>
      'Đánh theo thứ tự số, 2 lượt, lấy lượt cao hơn. Lượt 1 trọn điểm thì '
          'không cần lượt 2.',
    'S2' => '2 lượt, thứ tự tùy ý, lấy lượt cao hơn. Lượt 1 trọn điểm thì không cần lượt 2.',
    'S3' =>
      '3 thế, mỗi bi hợp lệ theo thứ tự được 1 điểm, cộng 2 thế thấp nhất. Bi 9 '
          'vào sớm thì vẫn đánh nốt các bi còn lại theo thứ tự.'
          '${v == ExamIIVersion.doctorate ? ' Thế 3: phải tới bi 7 và bi 9 bằng 3–4 băng.' : ''}',
    'S4' =>
      '3 thế, mỗi bi trước khi trượt được 1 điểm, cộng 2 thế thấp nhất. '
          'Được chạm bi chướng ngại.',
    'S5' => 'Mỗi vị trí bi cái 2 lượt, mỗi lần bắt đui được 1 điểm.',
    'S6' || 'S7' || 'S8' => 'Mỗi cú thành công 1 điểm.',
    // PDF bản Doctorate: "1 point for each successful shot (CB pocketed, no
    // obstacle-ball contact)" và hình ghi "scratch in the corner" — bản này
    // không có bi mục tiêu, cú thành công là đưa bi cái vào lỗ góc.
    'S9' =>
      'Dùng nhảy bi (Jump) hoặc mát xê (Massé). Mỗi cú thành công 1 điểm.'
          '${v == ExamIIVersion.doctorate ? ' Bản Doctorate: không có bi mục tiêu, cú thành công '
                    'là đưa bi cái vào lỗ góc mà không chạm bi chướng ngại.' : ' Được chết cái.'}',
    'S10' =>
      '3 lần phá, mỗi lần chấm 5 tiêu chí a–e, lấy trung vị điểm của 3 lần.',
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
  static String buDrillSetup(
    String drillId,
    ExamIIVersion? v,
  ) => switch (drillId) {
    'F1' =>
      'Bi cái bắt đầu ở vị trí 4 trên đường chấm 1. Bi mục tiêu trên đường chấm 3, '
          'cách băng cuối một khe bằng một bi; ăn bi mục tiêu vào lỗ góc gần nó. Vào thì '
          'lên một vị trí (xa lỗ hơn), trượt thì xuống một vị trí. Được chết cái. '
          'Có thể đánh từ phía bên kia bàn.',
    'F2' =>
      'Bi cái và bi mục tiêu sát băng trên (bi cái cách băng không quá một chấm); '
          'bi mục tiêu ở nửa chấm cạnh lỗ góc. Dán vòng đánh dấu chỗ bi mục tiêu và bi ảo. '
          'Đánh đứng bi: ăn bi, bi cái dừng chồng lên vòng bi ảo. Bi cái được chạm băng. Ở vị trí 1 '
          'được đặt bi cái trong khoảng vị trí 1–2.',
    'F3' =>
      'Bi cái và bi mục tiêu luôn cách nhau 1 chấm, sát băng trên (bi cái cách băng '
          'không quá một chấm). Khung giấy đích 8.5"×11" (bỏ lõi, chừa viền 1") đặt ở góc. '
          'Đánh cu lê: ăn bi, bi cái theo vào khung. Bi cái và bi mục tiêu được chạm băng.',
    'F4' =>
      'Bi cái và bi mục tiêu sát băng trên; bi mục tiêu ở nửa chấm cạnh lỗ góc. '
          'Hình chữ nhật 2×1 chấm cạnh lỗ giữa cố định, góc đánh dấu bằng vòng dán. Đánh '
          'trô bi: ăn bi, tâm bi cái dừng trong hình. Ở vị trí 1 được đặt bi cái '
          'trong khoảng vị trí 1–2.',
    'F5' =>
      'Bi mục tiêu ở dưới tâm bàn một bi, ăn vào lỗ giữa. Bi cái đặt tự do mỗi cú. '
          'Đánh tâm tiến. Khung giấy đích bắt đầu ở vị trí 4 (cạnh dài áp băng cuối); các vị trí khác có '
          'tâm thẳng chấm băng dài. Vị trí 1–3: bi cái đi thẳng tới đích; 5–7: bật băng cuối.',
    'F6' =>
      'Hai vị trí bi cái, mỗi vị trí 5 cú vào các lỗ như hình. Mỗi cú một lần, '
          'đánh theo thứ tự, không được chết cái.',
    'F7' =>
      'Bi mục tiêu trên đường chấm 1 dưới lỗ giữa; 10 bi đích áp sát băng. Bi cái '
          'đặt tự do mỗi cú. Ăn bi mục tiêu rồi cho bi cái chạm bi đích đang đánh; được '
          'chạm băng ngay cạnh bi đích, không được chạm băng khác. Mỗi bi đích 2 lượt, xong '
          'thì nhấc bi đích ra, bi bị xô lệch thì đặt lại.',
    'F8' =>
      'Bi mục tiêu (bi 1) ở chấm (1, 1), ăn vào lỗ góc gần nó; bi cái như hình. '
          'Năm khung giấy đích: hai cái sát băng trên, hai cái sát băng dưới, một cái giữa '
          'bàn. Mỗi đích 4 lượt, đi đường nào tới đích cũng được.',
    'S1' =>
      'Bi cái đặt tự do. Các bi xếp trên đường giữa bàn, bi 1 cách băng cuối một khe '
          'một bi, giữa các bi là khe ${switch (v) {
            ExamIIVersion.bachelors => 'ba bi',
            ExamIIVersion.masters => 'hai bi',
            _ => 'một bi',
          }}. Ăn theo thứ tự số vào lỗ bất kỳ, không chết cái, không chạm bi còn lại; '
          'chạm bi khác thì bi vừa vào vẫn tính nhưng lượt dừng.',
    'S2' =>
      'Bi cái đặt tự do. Các bi áp sát băng như hình (và một bi ở tâm bàn). Ăn theo '
          'thứ tự tùy ý, không chết cái, không đánh bi kết hợp, không chạm bi còn lại.',
    'S3' =>
      'Bi cái đặt tự do. Xếp bi như hình của từng thế, ăn theo luật 9 bi: luôn chạm '
          'bi số nhỏ nhất trước.',
    'S4' =>
      'Bi cái đặt tự do. Ăn hết bi sọc theo thứ tự tùy ý rồi tới bi 8. Bi xám là bi '
          'chướng ngại.',
    'S5' =>
      'Bi 1 ở (2, 3). Cụm 9 bi chướng ngại xếp khít trong khung giấy đích 8.5"×11" '
          'tâm (6, 1). Từ mỗi vị trí bi cái (${switch (v) {
            ExamIIVersion.bachelors => '3',
            ExamIIVersion.masters => '5',
            _ => '7',
          }} vị trí), đánh hợp lệ để bi 1 bị cụm bi che khỏi bi cái. Không được ăn bi 1; được '
          'chạm cụm bi nhưng mọi bi phải còn trong hoặc chồng lên khung.',
    'S6' => switch (v) {
      ExamIIVersion.bachelors =>
        'Bi cái cố định ở (1, 1). A băng (băng dài dưới) vào '
            'từng bi 1–3. Không chết cái, bi chạm băng sau va chạm.',
      ExamIIVersion.masters =>
        'Cú 1–4: bi cái cố định ở (1, 1), A băng một băng dài '
            'vào từng bi 1–4. Cú 5: bi cái đặt tự do, A băng hai băng bất kỳ vào bi 1.',
      _ =>
        'Cú 1–4: bi cái cố định ở (1, 1), A băng một băng dài vào từng bi 1–4. Cú 5, '
            '6: bi cái đặt tự do, A băng hai băng bất kỳ vào bi 1 và bi 3. Cú 7: bi cái đặt '
            'tự do, A băng ba băng bất kỳ vào bi 2.',
    },
    'S7' => switch (v) {
      ExamIIVersion.bachelors =>
        'Bi cái đặt tự do mỗi cú. Cân bi từng bi (cách nhau '
            'một khe một bi) chéo bàn vào lỗ giữa.',
      ExamIIVersion.masters =>
        'Bi mục tiêu ở (3, 3). Từ mỗi vị trí trong 5 vị trí bi '
            'cái, cân bi chéo bàn vào lỗ giữa.',
      _ =>
        'Bi mục tiêu ở (6, 3). Từ mỗi vị trí trong 7 vị trí bi cái, cân bi chéo bàn '
            'vào lỗ góc.',
    },
    'S8' =>
      'Dựng cơ: ăn từng bi mục tiêu vào lỗ góc dưới phải từ vị trí bi cái đã chỉ, '
          'không chết cái. Bi mục tiêu ở giữa bi cái và lỗ. Bi cái áp sát băng, hoặc áp '
          'sát bi chướng ngại thẳng hướng cú đánh.',
    'S9' => switch (v) {
      ExamIIVersion.bachelors =>
        'Bi cái ở (1, 1); hai bi chướng ngại cách nhau một khe '
            'một bi. Nhảy bi qua khe, hoặc mát xê vòng qua một bi (khi mát xê thì nhấc một '
            'bi chướng ngại ra), rồi ăn bi treo miệng lỗ góc.',
      ExamIIVersion.masters =>
        'Bi cái ở (1, 1), một bi chướng ngại trên đường bắn. Nhảy '
            'bi hoặc mát xê qua/vòng bi chướng ngại, rồi ăn bi treo miệng lỗ góc.',
      _ =>
        'Bi cái ở (1, 1), bi chướng ngại cách bi cái một khe hai bi trên đường bắn. '
            'Nhảy bi hoặc mát xê qua/vòng bi chướng ngại, đưa bi cái vào lỗ góc.',
    },
    'S10' =>
      'Phá giá 9 bi, bi cái đặt tự do sau vạch đầu bàn. Vùng đích của bi cái là 4 '
          'chấm ở giữa bàn. Phá 3 lần, chấm từng lần theo tiêu chí a–e.',
    _ => throw ArgumentError.value(
      drillId,
      'drillId',
      'chưa dịch cách xếp bài',
    ),
  };

  // Sơ đồ bài kiểm tra — D12 của kế hoạch.
  static const buLayoutsTitle = 'Sơ đồ bài kiểm tra';
  static const buLayoutsEnd = 'Hết sơ đồ.';

  static String buLayoutCaption(BuLayout l, int k, int n) =>
      'Sơ đồ $k / $n · ${buDrillTitle(l.drillId)}'
      '${l.version == null ? '' : ' · ${buVersionName(l.version!)}'} · hình ${l.variant}';

  static String buLayoutSource(String source) =>
      'Nguồn: Billiard University — $source';

  // Bộ câu hỏi xác định hạng — spec mục 7.2.
  static const onboardingTitle = 'Xác định hạng';
  static const onboardingLater = 'Để sau';
  static const onboardingIntroTitle = 'Xác định hạng của bạn';
  static const onboardingIntroBody =
      'Trả lời 8 câu hỏi ngắn, app gợi ý một hạng. Bạn '
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
  static const onboardingLocked =
      'Hạng của bạn đã được kiểm chứng bằng bài kiểm tra '
      'Billiard University. Từ giờ chỉ bài kiểm tra mới đổi được hạng.';

  /// Câu miễn trừ bắt buộc ở mọi màn hiện hạng (spec mục 4.3).
  static const rankDisclaimer =
      'Đây là bảng hạng riêng của PoolCoachAI, tham khảo cách hiểu ở Hà Nội.';

  // Làm bài kiểm tra — spec mục 7.3.
  static const buTestTitle = 'Bài kiểm tra BU';
  static const buPrepTitle = 'Chuẩn bị';
  static const buPrepIntro =
      'Bài kiểm tra gồm Đề I (Cơ bản) và Đề II (Kỹ năng) của '
      'Billiard University. Mỗi đề mất khoảng 40–60 phút. Điểm Đề I quyết định bản '
      'Đề II (Bachelors, Masters hoặc Doctorate). Đề II làm ngay hoặc để buổi khác đều được.';
  static const buSourceLine =
      'Đề bài: Billiard University (billiarduniversity.org) — '
      'Dr. Dave Alciatore và Bob Jewett.';
  static const buTableSizeLabel = 'Kích thước bàn';
  static String buTableSize(TableSize s) => switch (s) {
    TableSize.sevenFoot => '7 feet',
    TableSize.eightFoot => '8 feet',
    TableSize.nineFootPlus => '9 feet trở lên',
  };
  static const buDoctorateNeedsNine =
      'Bản Doctorate chỉ làm trên bàn 9 feet trở lên.';
  static const buStart = 'Bắt đầu Đề I';
  static String buRetestFrom(DateTime d) =>
      'Lần kiểm tra trước đã hoàn tất. '
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

  static const buExamIReadyTitle = 'Xong Đề I';
  static const buExamIReadyAction = 'Chấm Đề I';
  static String buExamIScore(int s) => 'Điểm Đề I: $s / $examIMax';
  static String buPlacement(ExamIIVersion v) =>
      'Bạn làm Đề II bản ${buVersionName(v)}.';
  static const buPlacementSmallTable =
      'Đề I đạt mức Doctorate nhưng bàn nhỏ hơn 9 feet, nên làm bản Masters.';
  static const buExamIINow = 'Làm Đề II ngay';
  static const buExamIILater = 'Để buổi khác';
  static const buFinishTitle = 'Xong Đề II';
  static const buFinishAction = 'Hoàn tất và xem kết quả';
  static String buCompletionTooSoon(DateTime d) =>
      'Lần kiểm tra trước hoàn tất chưa đủ 14 '
      'ngày. Lần này hoàn tất được từ ngày ${shortDate(d)}; các cú đã nhập vẫn còn nguyên.';
  static const buResultTitle = 'Kết quả kiểm tra';
  static String buDrillScoreLine(String id, int score, int max) =>
      '${buDrillTitle(id)}: $score / $max';
  static String buExamScoreLine(BuExam e, int s, int max) =>
      '${buExamName(e)}: $s / $max';
  static String buTotal(int total) => 'Điểm BU: $total / $buTotalMax';
  static String buBand(BuRankBand b) => 'Mức BU: ${b.buLevels}';
  static String buFargo(BuRankBand b) => 'Fargo tham chiếu: ${b.fargo}';
  static const buResultDone = 'Xong';

  /// Câu kết quả hạng — đúng một câu cho mỗi luật của spec mục 4.2.
  static String rankOutcome(
    RankOutcome o,
    Rank? before,
    Rank result,
  ) => switch (o) {
    RankOutcome.firstRank => 'Bạn nhận hạng ${result.label}, đã kiểm chứng.',
    RankOutcome.promoted =>
      'Lên hạng: ${before!.label} → ${result.label}, đã kiểm chứng.',
    RankOutcome.confirmed => 'Giữ hạng ${result.label}, nay đã kiểm chứng.',
    RankOutcome.warned =>
      'Kết quả tương đương hạng ${result.label}, thấp hơn hạng hiện '
          'tại ${before!.label}. Hạng giữ nguyên và có cảnh báo cho tới khi một lần sau '
          'đạt ${before.label} trở lên.',
  };

  static const buCancelTest = 'Hủy lần kiểm tra này';
  static const buCancelConfirmBody =
      'Hủy lần này? Các cú đã nhập không được tính và hạng không đổi.';
  static const buCancelConfirm = 'Hủy lần này';

  // Hạng trên Hồ sơ, Trang chủ và màn Hạng — spec mục 4.3, 7.4.
  static String rankSource(RankSource s) => switch (s) {
    RankSource.estimated => 'ước lượng',
    RankSource.selfDeclared => 'tự khai',
    RankSource.verified => 'đã kiểm chứng',
  };
  static const rankInfo = 'Về bảng hạng';
  static const rankInfoTitle = 'Bảng hạng PoolCoachAI';
  static const rankTableTitle = 'Quy đổi điểm Billiard University sang hạng';
  static String rankBandRange(BuRankBand b) => '${b.min}–${b.max} điểm';
  static String rankBandLevels(BuRankBand b) =>
      'Mức BU: ${b.buLevels} · Fargo ${b.fargo}';
  static const rankProNote =
      'PRO chỉ có khi tự khai. Bài kiểm tra BU cao nhất ra hạng A.';
  static const rankNone = 'Bạn chưa có hạng.';
  static String rankWarning(Rank w) =>
      'Lần kiểm tra gần nhất cho kết quả tương đương hạng '
      '${w.label}, thấp hơn hạng hiện tại.';
  static String rankLastTest(DateTime d, int total, Rank r) =>
      'Lần kiểm tra gần nhất: ${shortDate(d)} · $total điểm · hạng ${r.label}';
  static const rankContinueTest = 'Làm tiếp';
  static const rankDetermine = 'Xác định hạng';
  static const rankTakeTest = 'Làm bài kiểm tra';
  static const rankDetails = 'Xem chi tiết hạng';
  static const rankScreenTitle = 'Hạng của bạn';
  static const rankRetakeQuestionnaire = 'Làm lại bộ câu hỏi';
  static const rankShowLayouts = 'Xem sơ đồ các bài';
  static const rankHistoryTitle = 'Lịch sử kiểm tra';
  static const rankHistoryEmpty = 'Chưa có lần kiểm tra nào.';
  static String rankHistoryCompleted(DateTime d, int total, Rank r) =>
      '${shortDate(d)} · $total điểm · hạng ${r.label}';
  static String rankHistoryCancelled(DateTime d) => '${shortDate(d)} · đã hủy';
  static const homeRankCardTitle = 'Xác định hạng của bạn';
  static const homeRankCardBody =
      'Trả lời 8 câu hỏi để có hạng gợi ý, hoặc làm bài kiểm tra '
      'Billiard University để có hạng đã kiểm chứng.';
  static String signOutPendingAssessment(int n) =>
      'Còn $n mục hạng hoặc bài kiểm tra chưa đồng bộ, đăng xuất sẽ mất.';
  static const signOutActiveTest =
      'Lần kiểm tra đang làm dở sẽ mất khi đăng xuất.';

  static String signOutPendingRoadmap(int count) =>
      'Còn $count mục tiêu hoặc thành tích chưa lên máy chủ — đăng xuất bây giờ sẽ mất.';
  static String signOutPendingCoach(int count) =>
      'Còn $count lần làm tình huống Coach chưa đồng bộ — đăng xuất bây giờ sẽ mất.';
  static String signOutPendingPractice(int count) =>
      'Còn $count trận, giải đấu, buổi tập tự do hoặc lịch tập chưa đồng bộ — đăng xuất bây giờ sẽ mất.';
  static String signOutPendingEquipment(int count) =>
      'Còn $count hồ sơ cơ chưa đồng bộ — đăng xuất bây giờ sẽ mất.';

  // ─── Lộ trình (spec 2026-10-15) ─────────────────────────────────────────────
  //
  // Mọi câu là khuôn; con số do các hàm trong lib/domain/roadmap tính ra.
  static const roadmapTitle = 'Lộ trình';
  static const roadmapCardBody = 'Chọn mục tiêu, xem các bước tập dẫn tới đó.';

  static String goalKind(GoalKind kind) => switch (kind) {
    GoalKind.lenHang => 'Lên hạng',
    GoalKind.thuanThucKyNang => 'Thuần thục kỹ năng',
    GoalKind.chuanBiGiai => 'Chuẩn bị giải',
  };

  static String goalKindBody(GoalKind kind) => switch (kind) {
    GoalKind.lenHang =>
      'Chọn hạng đích, từ hạng ngay trên tới hạng A, theo điểm BU còn thiếu.',
    GoalKind.thuanThucKyNang =>
      'Chọn một nhóm kỹ năng, tập tới khi đạt ${PracticeConstants.strongCutoff} '
          'và ${PracticeConstants.readyStreak} buổi đạt liên tiếp.',
    GoalKind.chuanBiGiai =>
      'Chọn ngày giải; bước nào không kịp sẽ được xếp riêng.',
  };

  static const goalPickTitle = 'Chọn mục tiêu';
  static const goalPickDate = 'Chọn ngày giải';
  static const goalTargetRankTitle = 'Lên tới hạng';

  static String goalBlocked(LenHangBlock block) => switch (block) {
    LenHangBlock.noRank => 'Cần có hạng trước khi đặt mục tiêu lên hạng.',
    LenHangBlock.topRank =>
      'Hạng A là hạng cao nhất bài BU xác nhận được; PRO chỉ tự khai.',
  };

  static const goalNeedRank = 'Xác định hạng';
  static const goalChange = 'Đổi mục tiêu';
  static const goalClear = 'Bỏ mục tiêu';
  static const goalCancelChange = 'Giữ mục tiêu cũ';

  static String roadmapHeadline(Roadmap roadmap, {String? tournamentName}) =>
      switch (roadmap.goal.kind) {
        GoalKind.lenHang =>
          roadmap.from == null || roadmap.target == null
              ? goalKind(GoalKind.lenHang)
              : 'Lên hạng: ${roadmap.from!.label} → ${roadmap.target!.label}',
        GoalKind.thuanThucKyNang =>
          'Thuần thục: ${skill(roadmap.goal.category!)}',
        GoalKind.chuanBiGiai =>
          tournamentName == null
              ? 'Chuẩn bị giải ngày ${shortDate(roadmap.goal.eventDate!)}'
              : 'Chuẩn bị giải $tournamentName — ngày '
                    '${shortDate(roadmap.goal.eventDate!)}',
      };

  /// Dòng phụ của mục tiêu Lên hạng; null với hai mục tiêu kia.
  static String? roadmapNeed(Roadmap roadmap) {
    if (roadmap.goal.kind != GoalKind.lenHang || roadmap.target == null) {
      return null;
    }
    final needed = roadmap.pointsNeeded;
    if (needed == null) {
      return 'Chưa có bài BU hoàn chỉnh: xếp bước theo nhóm yếu nhất.';
    }
    if (needed <= 0) return 'Điểm BU gần nhất đã đủ, chỉ còn làm bài BU.';
    return 'Cần thêm $needed điểm BU (hạng ${roadmap.target!.label} từ '
        '${buFloor(roadmap.target!)} điểm).';
  }

  static String finishLine(Estimate estimate) => estimate.date == null
      ? 'Dự kiến xong: chưa đủ dữ liệu'
      : 'Dự kiến xong: ${shortDate(estimate.date!)}';

  static const roadmapAchieved = 'Đã đạt mục tiêu.';

  static String stepStatus(StepStatus status) => switch (status) {
    StepStatus.dangLam => 'Đang làm',
    StepStatus.xong => 'Xong',
    StepStatus.chuaToi => 'Chưa tới',
    StepStatus.khongKip => 'Không kịp trước giải',
  };

  static String stepTitle(RoadmapStep step, {String? drillName}) =>
      switch (step.kind) {
        StepKind.xacDinhHang => 'Xác định hạng',
        StepKind.nhom =>
          drillName == null
              ? skill(step.category!)
              : '${skill(step.category!)} · $drillName',
        StepKind.buLe => 'Tập lại ${step.buDrillIds.join('/')} trên bàn BU',
        StepKind.baiTap => drillName ?? step.drillId!,
        StepKind.lamBaiBu => switch (step.reason) {
          RankMilestone(:final rank, :final retake) =>
            '${retake ? 'Làm lại' : 'Làm'} bài BU — mốc hạng ${rank.label}',
          _ => 'Làm bài BU',
        },
        StepKind.dauTap => switch (step.reason) {
          NotEnoughMatches(:final have, :final need) =>
            'Đấu tập: ghi ít nhất ${need - have} trận có ghi cú',
          _ => 'Đấu tập',
        },
      };

  static String stepProgress(int? mastery, int streak) =>
      '${mastery == null ? 'Độ thuần thục: chưa đo' : 'Độ thuần thục: $mastery / ${PracticeConstants.strongCutoff}'}'
      ' · ${stepStreak(streak)}';

  static String stepStreak(int streak) =>
      'Buổi đạt liên tiếp: $streak / ${PracticeConstants.readyStreak}';

  static String stepReason(StepReason reason) => switch (reason) {
    LostBuPoints(:final points, :final drillIds) =>
      'Mất $points điểm BU ở ${drillIds.join(', ')}.',
    Unmeasured(:final sessions) =>
      'Tập đủ ${PracticeConstants.minSessions} buổi để đo (đã có $sessions).',
    BelowStrong(:final mastery) =>
      'Còn thiếu ${PracticeConstants.strongCutoff - mastery} điểm để đạt '
          '${PracticeConstants.strongCutoff}.',
    NeedStreak() =>
      'Đã đạt ${PracticeConstants.strongCutoff}, cần '
          '${PracticeConstants.readyStreak} buổi đạt liên tiếp.',
    DrillLevel(:final level) => 'Bài cấp $level của nhóm.',
    RetestFrom(:final from) =>
      from == null ? 'Làm được ngay.' : 'Mở từ ngày ${shortDate(from)}.',
    RankMilestone(:final rank) =>
      'Đạt ${buFloor(rank)} điểm BU là lên hạng ${rank.label}.',
    NeedRank() => 'Làm bộ câu hỏi hoặc bài BU để có hạng.',
    MatchWeakness(:final failures, :final attempts) =>
      'Hỏng $failures/$attempts lần trong các trận gần đây.',
    NotEnoughMatches(:final have, :final need) =>
      'Có $have/$need trận có ghi cú trong '
          '${MatchAnalysisConstants.matchWindowDays} ngày qua.',
  };

  static String estimateLine(Estimate estimate) => estimate.date == null
      ? 'Dự kiến: chưa đủ dữ liệu'
      : 'Dự kiến: ${shortDate(estimate.date!)}';

  static const stepTrain = 'Tập ngay';
  static const stepRecordMatch = 'Ghi trận';
  static const stepOpenTest = 'Làm bài kiểm tra';
  static const roadmapMissedTitle = 'Không kịp trước giải';
  static const achievementsTitle = 'Thành tích';
  static const achievementsEmpty =
      'Chưa có thành tích. Thành tích chỉ đến từ buổi tập thật.';

  static String achievement(AchievementKind kind, String subject) =>
      switch (kind) {
        AchievementKind.xongBuoc => 'Xong bước: $subject',
        AchievementKind.duDieuKienLenCap => 'Đủ điều kiện lên cấp: $subject',
        AchievementKind.chuoiNgay => 'Chuỗi $subject ngày tập liên tiếp',
        AchievementKind.chungNhan => 'Chứng nhận: $subject',
      };

  static String homeCurrentStep(String step) => 'Bước hiện tại: $step';

  /// Gợi ý làm lại bài BU (spec 2026-10-28 mục 6.5): nhóm và hạng do
  /// rankCheckSignal điền, không có suy diễn nào ngoài dữ liệu.
  static String rankCheck(RankCheckSignal s) {
    final skills = s.categories.map(skill).join(', ');
    final rank = s.rank.label;
    return switch ((s.direction, s.basis)) {
      (RankCheckDirection.down, RankCheckBasis.drills) =>
        'Kết quả tập gần đây ở $skills đang đi xuống — làm lại bài BU để kiểm tra hạng $rank.',
      (RankCheckDirection.down, RankCheckBasis.matches) =>
        'Khi thi đấu gần đây, $skills đang yếu — làm lại bài BU để kiểm tra hạng $rank.',
      (RankCheckDirection.up, _) =>
        'Kết quả tập gần đây ở $skills đang đi lên — làm lại bài BU để thử hạng $rank.',
    };
  }

  // ─── Coach tình huống — docs/superpowers/specs/2026-10-21-poolcoachai-coach-design.md mục 15.
  // Mọi câu có tham số đều do hàm thuần của lib/domain/coach điền; ở đây chỉ
  // ghép chữ. Không câu nào có số độ, "ngắm lệch" hay "tối ưu" (spec D8, C7).

  // Màn Coach và thẻ gợi ý.
  static const coachSituationsTitle = 'Tình huống';
  static const coachSituationsBody =
      'Xem một thế bàn, chọn cú đánh, app chấm theo cách chấm của Kế hoạch dọn bàn.';
  static const coachTopicLabel = 'Nhóm kỹ năng';
  static const coachDifficultyLabel = 'Độ khó';

  static String coachDifficulty(CoachDifficulty d) => switch (d) {
    CoachDifficulty.easy => 'Dễ',
    CoachDifficulty.medium => 'Vừa',
    CoachDifficulty.hard => 'Khó',
  };

  /// Tên nhóm tình huống: đúng tên nhóm kỹ năng.
  static String coachTopic(CoachTopic t) => skill(categoryOf(t));

  static const coachStart = 'Bắt đầu';
  static const coachLibraryLink = 'Thư viện tình huống ›';
  static const coachLibraryTitle = 'Thư viện tình huống';
  static String coachLibraryCaption(String id, int k, int n) =>
      'Tình huống $k/$n · $id';
  static String coachLibrarySource(String source) => 'Nguồn: $source';
  static const coachLibraryEnd = 'Hết thư viện.';

  // Hỏi huấn luyện viên — chat tự do, Giai đoạn B (spec mục 3, Task 10).
  static const coachChatTitle = 'Hỏi huấn luyện viên';
  static const coachChatSubtitle = 'Trả lời dựa trên số liệu tập luyện của bạn';
  static const coachChatSamples = <String>[
    'Hôm nay tôi nên tập gì?',
    'Tại sao tôi thua trận vừa rồi?',
    'Tôi đang yếu kỹ năng nào?',
  ];
  static const coachChatOpen = 'Mở trò chuyện';
  static const coachChatClear = 'Xoá cuộc trò chuyện';
  static const coachChatThinking = 'Huấn luyện viên đang trả lời…';
  static const coachChatInsufficient = 'Chưa đủ dữ liệu để trả lời câu này.';
  static String coachChatRemaining(int n) => 'Còn $n lượt hỏi hôm nay';
  static const coachChatQuotaOut = 'Hết lượt hỏi hôm nay, mai hỏi tiếp.';
  static const coachChatRetry = 'Thử lại';
  static const coachChatDisclaimer =
      'Huấn luyện viên AI chỉ diễn giải số liệu của bạn và có thể sai.';

  static const coachChatClearBody =
      'Xoá mọi tin nhắn với huấn luyện viên trên máy này? Không lấy lại được.';
  static const coachChatClearYes = 'Xoá';
  static const coachChatInputHint = 'Hỏi về việc tập của bạn';
  static const coachChatSend = 'Gửi';
  static const coachChatInsufficientHint =
      'Ghi thêm buổi tập, trận đấu hoặc tình huống Coach rồi hỏi lại.';
  static const coachChatError = 'Chưa gửi được câu hỏi.';
  static const coachChatContextError =
      'Chưa đọc được số liệu tập luyện của bạn, nên chưa hỏi được.';
  static const coachChatFromPlayer = 'Bạn';
  static const coachChatFromCoach = 'Huấn luyện viên';

  static const coachRecTitle = 'Nên luyện gì';

  static String coachRecReason(CoachTopicReason reason, CoachTopic topic) =>
      switch (reason) {
        CoachTopicReason.sameAsToday =>
          'Cùng nhóm với gợi ý hôm nay: ${coachTopic(topic)}.',
        CoachTopicReason.weakest =>
          '${coachTopic(topic)} là nhóm yếu nhất có tình huống để luyện.',
        CoachTopicReason.matchWeakness =>
          '${coachTopic(topic)} đang yếu trong các trận gần đây.',
        CoachTopicReason.lowest => 'Bắt đầu với ${coachTopic(topic)}.',
      };

  static String coachTopicUnsupported(SkillCategory cat) =>
      'Chưa có tình huống cho nhóm ${skill(cat)}.';
  static String coachRecSolved(int solved, int total) =>
      'Giải được $solved/$total tình huống gần nhất mà không xem đáp án.';
  static String coachRecNotEnough(int n, int min) =>
      'Mới làm $n tình huống — cần $min để nhận xét.';
  static String coachRecRecurring(
    CoachFaultGroup group,
    int count,
    int total,
  ) => 'Lỗi lặp lại: ${coachFaultGroup(group)} ($count/$total lần gần nhất).';

  static String coachFaultGroup(CoachFaultGroup g) => switch (g) {
    CoachFaultGroup.pocketChoice => 'chọn lỗ',
    CoachFaultGroup.scratch => 'chết cái',
    CoachFaultGroup.blockedPath => 'đường bi bị chắn',
    CoachFaultGroup.cuePosition => 'vị trí bi cái',
    CoachFaultGroup.extraSpin => 'áp phê thừa',
    CoachFaultGroup.potOrSafety => 'chọn ăn hay thủ',
  };

  static const coachRecToolSimulator = 'Tập chọn lỗ với Mô phỏng góc cắt';
  static const coachRecToolPlanner = 'Xem đường bi cái với Kế hoạch dọn bàn';
  static String coachRecToolArticle(String title) => 'Đọc: $title';
  static String coachRecPractice(CoachTopic topic) =>
      'Luyện tình huống ${coachTopic(topic)}';

  // Màn tình huống.
  static String coachSituationTitle(CoachTopic topic) =>
      'Tình huống — ${coachTopic(topic)}';
  static String coachPrompt(int ball) =>
      'Tới lượt bạn. Bi phải chạm: bi $ball. Bạn đánh thế nào?';
  static const coachChoicePot = 'Ăn bi';
  static const coachChoiceSafety = 'Phòng thủ';
  static const coachPickPocket = 'Chạm vào lỗ bạn chọn.';
  static const coachStrokeLabel = 'Kiểu đánh';
  static const coachPowerLabel = 'Lực';
  static const coachSubmit = 'Chấm';
  static const coachComputing = 'Đang tính…';
  static String coachTryCount(int k, int max) => 'Lần thử $k/$max';
  static const coachShowAnswer = 'Xem đáp án';
  static const coachShowAnswerConfirm =
      'Xem đáp án ngay? Tình huống này sẽ tính là chưa tự giải.';
  static const coachShowAnswerYes = 'Xem';
  static const coachShowAnswerNo = 'Tự làm tiếp';
  static const coachSameAnswer =
      'Bạn vừa chọn đúng cú này — thử đổi một thông số.';
  static const coachNext = 'Tình huống mới';
  static String coachGenerateFailed(CoachTopic topic) =>
      'Chưa tạo được tình huống ${coachTopic(topic)} mới — đây là một tình huống trong thư viện.';
  static String coachNoSituation(CoachTopic topic) =>
      'Chưa có tình huống ${coachTopic(topic)}.';
  static const coachModelNote =
      'Chấm theo mô phỏng và cách chấm của Kế hoạch dọn bàn — bàn thật có thể khác.';
  static String coachTableSummary(int count, int ball) =>
      'Bàn tình huống: bi cái và $count bi. Bi phải chạm: bi $ball.';
  static String coachPocketButton(Pocket pocket) => 'Lỗ ${simPocket(pocket)}';

  // Kết luận.
  static String coachVerdict(CoachVerdict v) => switch (v.outcome) {
    CoachOutcome.best =>
      'Đạt — đúng cú tốt nhất theo cách chấm của Kế hoạch dọn bàn.',
    CoachOutcome.equivalent =>
      'Đạt — gần bằng cú tốt nhất, chênh trong mức cho phép.',
    CoachOutcome.better =>
      v.noPlannerPot
          ? 'Đạt — Kế hoạch dọn bàn không tìm được cú ăn ở lỗ dễ nhất; '
                'theo mô phỏng, cú của bạn vào lỗ.'
          : 'Đạt — Kế hoạch dọn bàn chỉ xét lỗ có góc cắt dễ nhất; '
                'cú của bạn được chấm tốt hơn cú đó.',
    CoachOutcome.wrong => 'Chưa đạt.',
    CoachOutcome.undecided => switch (v.undecided!) {
      CoachUndecidedReason.timeout => 'Chưa đủ dữ liệu để chấm: không mô phỏng được cú bạn chọn. Lần này không tính.',
      CoachUndecidedReason.potVsSafety =>
        'Chưa đủ dữ liệu để chấm: có cú ăn nhưng vị trí sau đó không tốt, '
            'và Kế hoạch dọn bàn không so cú ăn với cú thủ.',
    },
  };

  // Gợi ý 1: câu hỏi về hậu quả.
  static String coachHintOne(HintOne h) => switch (h) {
    HintPathBlocked(:final ball, :final pocket) =>
      'Từ bi cái, có đường thông tới bi ảo để đưa bi $ball vào lỗ ${simPocket(pocket)} không?',
    HintTooThin(:final pocket) =>
      'Cắt vào lỗ ${simPocket(pocket)} có quá mỏng không?',
    HintGhostOff(:final pocket) =>
      'Bi ảo cho lỗ ${simPocket(pocket)} nằm ở đâu — bi cái có tới được chỗ đó không?',
    HintScratch(:final pocket) =>
      'Xem đường bi cái của cú bạn chọn: sau khi chạm bi, bi cái đi về đâu? '
          'Chuyện gì xảy ra ở lỗ ${simPocket(pocket)}?',
    HintMissed(:final ball, :final pocket) =>
      'Với cú này, bi $ball có vào lỗ ${simPocket(pocket)} không?',
    HintBlocker(:final blocker) =>
      'Đường đi của cú này có lọt qua bi $blocker không?',
    HintNoNext(:final next) =>
      'Bi cái dừng ở vòng trắng. Từ đó, bi $next còn lỗ nào đánh được không?',
    HintPosition(:final next) =>
      'Bi cái dừng ở vòng trắng. Từ đó, đánh bi $next vào lỗ nào được, và có dễ không?',
    HintSimpler() => 'Bi cái tới được vị trí — có cách nào ít xoáy hơn hoặc lực nhẹ hơn mà vẫn tới đó không?',
    HintShouldPot(:final ball) =>
      'Bi $ball thật sự không có lỗ nào đánh được sao? Nhìn lại từng lỗ trước khi chọn phòng thủ.',
  };

  // Gợi ý 2: thông số cần đổi, không nói giá trị đúng.
  static String coachHintTwo(HintTwo h) => switch (h) {
    Hint2Pocket(:final ball) => 'Thử lỗ khác cho bi $ball.',
    Hint2NoSpin() => 'Thử không áp phê.',
    Hint2NeedSpin() =>
      'Không áp phê thì không cú nào ổn ở lỗ này — thử áp phê.',
    Hint2Spin() => 'Giữ lỗ và kiểu đánh, thử đổi áp phê.',
    Hint2Stroke() => 'Giữ lỗ này, thử đổi kiểu đánh.',
    Hint2PowerLess() => 'Giữ lỗ và kiểu đánh, thử lực nhẹ hơn.',
    Hint2PowerMore() => 'Giữ lỗ và kiểu đánh, thử lực mạnh hơn.',
    Hint2Pot(:final ball) => 'Bi $ball có cú ăn được — thử chọn Ăn bi.',
    Hint2Safety(:final ball) =>
      'Bi $ball không có cú ăn chắc chắn — cân nhắc phòng thủ.',
  };

  static String coachHint2Zone(int next) =>
      'Ô xanh là chỗ bi cái nên dừng để đánh bi $next dễ; ô vàng là tạm được.';

  // Đáp án.
  static const coachRevealTitle = 'Đáp án';
  static const coachSolutionTitle = 'Lời giải';
  static String coachRevealShot(
    int ball,
    Pocket pocket,
    Stroke stroke,
    double power,
  ) =>
      'Bi $ball vào lỗ ${simPocket(pocket)} — ${simStroke(stroke)}, lực ${power.round()}%.';

  /// Câu áp phê của đáp án: đúng câu mẫu SAWS của chủ sản phẩm.
  static String coachRevealSpin(RevealSpin s) =>
      sawsSpinAdvice(s.side, s.tips, s.bhe, s.speed);

  static const coachRevealWhy = 'Vì sao';

  static String coachZoneWord(CoachZone z) => switch (z) {
    CoachZone.good => 'tốt',
    CoachZone.fair => 'tạm được',
    CoachZone.hard => 'khó',
  };

  static String coachReason(RevealReason r) => switch (r) {
    ReasonZone(:final zone, :final next) =>
      'Bi cái dừng ở vùng ${coachZoneWord(zone)} cho bi $next.',
    ReasonYourZone(:final zone, :final next) =>
      'Cú của bạn: bi cái dừng ở vùng ${coachZoneWord(zone)} cho bi $next.',
    ReasonYourScratch(:final pocket) =>
      'Cú của bạn: bi cái rơi lỗ ${simPocket(pocket)} (chết cái).',
    ReasonYourBlocked(:final blocker) =>
      'Cú của bạn: đường bi đi qua bi $blocker.',
    ReasonYourMissed(:final ball, :final pocket) =>
      'Cú của bạn: bi $ball không vào lỗ ${simPocket(pocket)}.',
    ReasonYourNoNext(:final next) =>
      'Cú của bạn: từ chỗ bi cái dừng, bi $next không còn lỗ nào đánh được.',
    ReasonYourUnmakeable(:final ball, :final pocket) =>
      'Cú của bạn: không có đường đưa bi $ball vào lỗ ${simPocket(pocket)}.',
    ReasonNoSpin() => 'Không cần áp phê — càng ít xoáy càng ít sai số.',
    ReasonStroke(:final best, :final yours) =>
      '${simStroke(best)} ít sai số hơn ${simStroke(yours)} ở thế này, '
          'theo cách chấm của Kế hoạch dọn bàn.',
    ReasonPower(:final best, :final yours) =>
      'Lực ${best.round()}% đã đủ đưa bi cái tới vị trí; lực ${yours.round()}% dễ sai số hơn.',
  };

  static const coachRevealEquivalents = 'Các cú cũng đạt:';
  static const coachRevealSafetyNote =
      'Phần này chỉ chấm lựa chọn phòng thủ; cú thủ bên dưới là cú Kế hoạch dọn bàn '
      'tìm được, chưa chấm cú thủ của bạn.';
  static const coachRevealPotVsSafety =
      'Kế hoạch dọn bàn tìm được cú ăn dưới đây, nhưng không so nó với cú thủ — '
      'cả hai lựa chọn đều chưa thể chấm là sai.';
}
