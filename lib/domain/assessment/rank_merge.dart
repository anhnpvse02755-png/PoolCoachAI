import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Bản hạng nào thắng khi máy này và máy chủ khác nhau (spec mục 6.2).
///
/// Luôn trả **một trong hai** đối số: bên đồng bộ dựa vào đó để biết phải
/// ghi bản máy chủ xuống máy hay đẩy bản máy lên.
///
/// 1. Bản có hạng thắng bản chưa có hạng: bấm *Để sau* trên máy mới đang
///    mất mạng không được xoá hạng đã có (D16 của kế hoạch).
/// 2. Bản đã kiểm chứng không bao giờ thua bản ước lượng / tự khai.
/// 3. Hai bản đã kiểm chứng khác hạng: hạng cao hơn thắng, dù cũ hơn — app
///    không tự hạ hạng (Q5; chủ sản phẩm chọn phương án này cho D4).
/// 4. Còn lại bản mới hơn thắng; hoà giờ giữ bản trên máy.
PlayerRank? mergeRank(PlayerRank? local, PlayerRank? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  if (local.hasRank != remote.hasRank) return local.hasRank ? local : remote;
  if (local.isVerified != remote.isVerified) return local.isVerified ? local : remote;
  if (local.isVerified && remote.isVerified && local.rank != remote.rank) {
    // Hai lần kiểm chứng khác nhau: hạng cao hơn thắng, app không tự hạ hạng (Q5).
    return local.rank!.index > remote.rank!.index ? local : remote;
  }
  return remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
}

/// Bản thua của [mergeRank] là một lần kiểm chứng **thấp hơn và mới hơn**
/// bản thắng: lần đó thành cảnh báo trên bản thắng, đúng như luật 4 khi cả
/// hai lần làm trên cùng một máy (D4).
///
/// Lần thấp hơn mà cũ hơn bản thắng thì không cảnh báo: lần kiểm chứng
/// bằng/cao hơn về sau đã xoá nó (luật 4). Không có gì để đổi thì trả đúng
/// [winner] — bên đồng bộ dựa vào `identical` để biết có bản gộp mới.
PlayerRank warnOfLowerTest(PlayerRank winner, PlayerRank? loser) {
  if (loser == null || !winner.isVerified || !loser.isVerified) return winner;
  if (loser.rank!.index >= winner.rank!.index) return winner;
  if (!loser.updatedAt.isAfter(winner.updatedAt)) return winner;
  if (winner.warningTestId == loser.testId) return winner;
  return PlayerRank(
    rank: winner.rank,
    source: winner.source,
    buScore: winner.buScore,
    testId: winner.testId,
    answers: winner.answers,
    onboardingState: winner.onboardingState,
    warningRank: loser.rank,
    warningTestId: loser.testId,
    updatedAt: loser.updatedAt,
  );
}
