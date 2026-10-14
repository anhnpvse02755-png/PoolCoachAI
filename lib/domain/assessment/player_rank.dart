import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Hạng đến từ đâu (spec mục 4.1).
enum RankSource {
  /// Người chơi chấp nhận hạng bộ câu hỏi gợi ý.
  estimated,

  /// Người chơi chọn hạng khác gợi ý, hoặc chọn PRO.
  selfDeclared,

  /// Hạng có từ bài kiểm tra BU.
  verified,
}

enum OnboardingState { notStarted, skipped, done }

/// Bản ghi hạng của một tài khoản (spec mục 4.1).
///
/// [rank] và [source] cùng null khi người chơi đã bấm *Để sau* mà chưa
/// làm bài kiểm tra nào (luật 6 cần trạng thái "chưa có hạng").
final class PlayerRank {
  const PlayerRank({
    required this.onboardingState,
    required this.updatedAt,
    this.rank,
    this.source,
    this.buScore,
    this.testId,
    this.warningRank,
    this.warningTestId,
    this.answers,
  })  : assert((rank == null) == (source == null), 'hạng và nguồn đi cùng nhau'),
        assert(source != RankSource.verified || (buScore != null && testId != null),
            'hạng đã kiểm chứng phải truy được về một lần kiểm tra'),
        assert((warningRank == null) == (warningTestId == null),
            'cảnh báo phải chỉ ra lần kiểm tra gây ra nó');

  final Rank? rank;
  final RankSource? source;

  /// Điểm BU và lần kiểm tra đã kiểm chứng hạng.
  final int? buScore;
  final String? testId;

  /// Cảnh báo đang hiện: một lần kiểm tra cho hạng thấp hơn (luật 4).
  final Rank? warningRank;
  final String? warningTestId;

  final QuestionnaireAnswers? answers;
  final OnboardingState onboardingState;
  final DateTime updatedAt;

  bool get hasRank => rank != null;
  bool get isVerified => source == RankSource.verified;

  @override
  bool operator ==(Object other) =>
      other is PlayerRank &&
      other.rank == rank &&
      other.source == source &&
      other.buScore == buScore &&
      other.testId == testId &&
      other.warningRank == warningRank &&
      other.warningTestId == warningTestId &&
      other.answers == answers &&
      other.onboardingState == onboardingState &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(rank, source, buScore, testId, warningRank,
      warningTestId, answers, onboardingState, updatedAt);

  @override
  String toString() => 'PlayerRank($rank, $source, bu=$buScore, test=$testId, '
      'warning=$warningRank/$warningTestId, $onboardingState, $updatedAt)';
}
