import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Hạng đổi thế nào sau một lần kiểm tra BU hoàn tất (spec mục 4.2).
enum RankOutcome {
  /// Chưa có hạng, nhận hạng từ kết quả (luật 6).
  firstRank,

  /// Kết quả cao hơn: lên hạng (luật 2).
  promoted,

  /// Kết quả bằng: giữ hạng, thành đã kiểm chứng (luật 3).
  confirmed,

  /// Kết quả thấp hơn: giữ hạng và nguồn, đặt cảnh báo (luật 4, 5).
  warned,
}

/// Bộ câu hỏi còn đổi được hạng không. Hạng đã kiểm chứng thì chỉ bài
/// kiểm tra BU đổi được, kể cả tự khai PRO cũng khoá (luật 1).
bool canUseQuestionnaire(PlayerRank? current) =>
    current?.source != RankSource.verified;

/// Người chơi chốt hạng ở cuối bộ câu hỏi (luật 1, spec mục 7.2 bước 4).
PlayerRank rankFromQuestionnaire(
  PlayerRank? current, {
  required Rank chosen,
  required Rank suggested,
  required QuestionnaireAnswers answers,
  required DateTime now,
}) {
  if (!canUseQuestionnaire(current)) {
    throw StateError('Hạng đã kiểm chứng chỉ đổi được bằng bài kiểm tra BU');
  }
  if (suggested == Rank.a || suggested == Rank.pro) {
    throw ArgumentError.value(
        suggested, 'suggested', 'bộ câu hỏi không bao giờ gợi ý A hay PRO');
  }
  // Cảnh báo nói "lần kiểm tra cho hạng thấp hơn hạng hiện tại". Hạng mới
  // không còn cao hơn nó thì câu đó sai, nên bỏ (D11 của kế hoạch).
  final warning = current?.warningRank;
  final keepWarning = warning != null && chosen.index > warning.index;
  return PlayerRank(
    rank: chosen,
    source: chosen == suggested ? RankSource.estimated : RankSource.selfDeclared,
    answers: answers,
    warningRank: keepWarning ? warning : null,
    warningTestId: keepWarning ? current!.warningTestId : null,
    onboardingState: OnboardingState.done,
    updatedAt: now,
  );
}

/// Bấm *Để sau*. Đã có bản ghi (đang làm lại bộ câu hỏi) thì không đổi gì:
/// trả đúng [current] để bên ghi biết khỏi ghi.
PlayerRank rankAfterSkip(PlayerRank? current, DateTime now) {
  if (current != null && current.onboardingState != OnboardingState.notStarted) {
    return current;
  }
  return PlayerRank(onboardingState: OnboardingState.skipped, updatedAt: now);
}

/// Áp kết quả một lần kiểm tra BU vừa hoàn tất (luật 2–6).
({PlayerRank rank, RankOutcome outcome}) applyTestResult(
  PlayerRank? current, {
  required Rank result,
  required int buScore,
  required String testId,
  required DateTime now,
}) {
  if (result == Rank.pro) {
    throw ArgumentError.value(result, 'result', 'bài kiểm tra BU không bao giờ ra PRO');
  }
  final before = current?.rank;
  final outcome = before == null
      ? RankOutcome.firstRank
      : result.index > before.index
          ? RankOutcome.promoted
          : result == before
              ? RankOutcome.confirmed
              : RankOutcome.warned;

  if (outcome == RankOutcome.warned) {
    final c = current!;
    return (
      rank: PlayerRank(
        rank: c.rank,
        source: c.source,
        buScore: c.buScore,
        testId: c.testId,
        answers: c.answers,
        onboardingState: c.onboardingState,
        warningRank: result,
        warningTestId: testId,
        updatedAt: now,
      ),
      outcome: outcome,
    );
  }

  return (
    rank: PlayerRank(
      rank: result,
      source: RankSource.verified,
      buScore: buScore,
      testId: testId,
      answers: current?.answers,
      onboardingState: current == null ||
              current.onboardingState == OnboardingState.notStarted
          ? OnboardingState.done
          : current.onboardingState,
      updatedAt: now,
    ),
    outcome: outcome,
  );
}
