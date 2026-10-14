import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Lần lấy hạng từ máy chủ của người đang đăng nhập (spec mục 8).
enum RankFetch {
  /// Chưa có lượt đồng bộ nào trả lời.
  pending,

  /// Máy chủ trả lời: tài khoản chưa có dòng hạng nào.
  foundNone,

  /// Máy chủ trả lời: có dòng hạng (đã gộp xuống máy).
  found,

  /// Lượt đồng bộ hỏng trước khi lấy được hạng.
  failed,
}

enum OnboardingCheck { required, notRequired }

/// Có chuyển người chơi tới bộ câu hỏi không (spec mục 7.1, 8).
///
/// Chỉ khi chắc chắn tài khoản chưa có dòng hạng: dòng trên máy còn ở
/// `notStarted`, hoặc máy chưa có dòng và máy chủ đã trả lời là không có.
/// Chưa biết (Drift chưa trả lời, máy chủ chưa trả lời, mất mạng, hay máy
/// chủ có dòng mà stream chưa kịp bắn) thì không chuyển.
OnboardingCheck decideOnboarding({
  required bool rankLoaded,
  required PlayerRank? local,
  required RankFetch fetch,
}) {
  if (!rankLoaded) return OnboardingCheck.notRequired;
  if (local != null) {
    return local.onboardingState == OnboardingState.notStarted
        ? OnboardingCheck.required
        : OnboardingCheck.notRequired;
  }
  return fetch == RankFetch.foundNone ? OnboardingCheck.required : OnboardingCheck.notRequired;
}
