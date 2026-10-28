import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Vì sao thẻ Coach chọn nhóm này (spec mục 10.2 bước 1).
enum CoachTopicReason {
  /// Cùng nhóm với gợi ý hôm nay ở Trang chủ.
  sameAsToday,

  /// Nhóm yếu trong các trận gần đây (gợi ý hôm nay hoặc nhóm yếu trong trận
  /// đầu tiên có tình huống).
  matchWeakness,

  /// Nhóm yếu nhất có tình huống.
  weakest,

  /// Nhóm có tình huống mà điểm thuần thục thấp nhất (chưa có điểm đứng trước).
  lowest,
}

/// Công cụ đi kèm lỗi lặp lại (spec mục 10.2 bước 4).
enum CoachTool { simulator, planner, article }

/// Thẻ "Nên luyện gì" trên màn Coach. Không lặp lại bài tập hay bài đọc của
/// Trang chủ: chỉ lấy nhóm của gợi ý hôm nay.
final class CoachRecommendation {
  const CoachRecommendation({
    required this.topic,
    required this.topicReason,
    required this.stats,
    this.unsupported,
    this.tool,
    this.article,
  });

  final CoachTopic topic;
  final CoachTopicReason topicReason;

  /// Nhóm của gợi ý hôm nay khi nhóm đó chưa có tình huống (Phá, Cân bi).
  final SkillCategory? unsupported;
  final CoachTopicStats stats;
  final CoachTool? tool;

  /// Bài đọc khi [tool] là [CoachTool.article].
  final KnowledgeArticle? article;
}

/// Thẻ Coach (spec mục 10.2). Hàm thuần: đổi nhóm yếu hay đổi lần làm Coach
/// thì thẻ tự đổi.
CoachRecommendation computeCoachRecommendation({
  required TodayRecommendation? today,
  required PlayerIntelligence pi,
  required List<CoachAttempt> attempts,
  required List<KnowledgeArticle> articles,
}) {
  final todayTopic = today == null ? null : coachTopicOf(today.cat);
  late final CoachTopic topic;
  late final CoachTopicReason reason;
  final weakTopic = pi.weak.map(coachTopicOf).whereType<CoachTopic>().firstOrNull;
  final matchTopic = pi.matchWeak
      .map((s) => coachTopicOf(s.category))
      .whereType<CoachTopic>()
      .firstOrNull;
  if (todayTopic != null) {
    topic = todayTopic;
    reason = today!.reason == PickReason.matchWeakness
        ? CoachTopicReason.matchWeakness
        : CoachTopicReason.sameAsToday;
  } else if (matchTopic != null) {
    topic = matchTopic;
    reason = CoachTopicReason.matchWeakness;
  } else if (weakTopic != null) {
    topic = weakTopic;
    reason = CoachTopicReason.weakest;
  } else {
    SkillCategory? lowest;
    int? lowestMastery;
    for (final cat in newcomerOrder) {
      if (coachTopicOf(cat) == null) continue;
      // Chưa có điểm đứng trước mọi điểm có số.
      final m = pi.categories[cat]?.mastery ?? -1;
      if (lowestMastery == null || m < lowestMastery) {
        lowest = cat;
        lowestMastery = m;
      }
    }
    topic = coachTopicOf(lowest!)!;
    reason = CoachTopicReason.lowest;
  }

  final stats = summarizeCoachAttempts(attempts)[topic]!;
  final group = stats.recurring;
  KnowledgeArticle? article;
  CoachTool? tool;
  switch (group) {
    case CoachFaultGroup.pocketChoice:
      tool = CoachTool.simulator;
    case CoachFaultGroup.cuePosition || CoachFaultGroup.scratch:
      tool = CoachTool.planner;
    case CoachFaultGroup.extraSpin:
      // Không có bài nhóm Điều bi thì không gợi ý, không thay bài nhóm khác.
      article = articles.where((a) => a.cat == SkillCategory.position).firstOrNull;
      tool = article == null ? null : CoachTool.article;
    case CoachFaultGroup.blockedPath || CoachFaultGroup.potOrSafety || null:
      break;
  }
  return CoachRecommendation(
    topic: topic,
    topicReason: reason,
    unsupported: today != null && todayTopic == null ? today.cat : null,
    stats: stats,
    tool: tool,
    article: article,
  );
}
