import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

// Ranh giới Giai đoạn B (spec mục 12). Giai đoạn A chỉ chuẩn bị chỗ nối,
// không gọi LLM nào. Luật cho Giai đoạn B, ghi trước:
// 1. LLM chỉ diễn giải và đặt câu hỏi; mọi con số trong câu trả lời phải có
//    trong [CoachContext.toFacts].
// 2. Gọi LLM qua máy chủ trung gian; khoá API không bao giờ nằm trong app.
// 3. Lọc sau câu trả lời: chặn lời khuyên ngắm theo độ và số không có trong
//    facts; bị chặn thì trả "chưa đủ dữ liệu".
// 4. Câu hỏi về một tình huống được trả lời bằng `Reveal` của Giai đoạn A.

/// Bước hiện tại của Lộ trình, dạng dữ liệu (không câu chữ).
typedef RoadmapStepFacts = ({StepKind kind, StepStatus status, SkillCategory? category, int? mastery});

RoadmapStepFacts roadmapStepFacts(RoadmapStep s) =>
    (kind: s.kind, status: s.status, category: s.category, mastery: s.mastery);

/// Lần làm tình huống gần nhất, dạng dữ liệu.
typedef CoachSituationFacts = ({
  String key,
  CoachTopic topic,
  CoachAttemptOutcome outcome,
  CoachFaultGroup? firstFaultGroup,
  int answers,
});

/// Mọi điều LLM được biết — số đã tính sẵn, LLM không tính lại.
final class CoachContext {
  const CoachContext({
    required this.skills,
    required this.rank,
    required this.currentStep,
    required this.coachStats,
    required this.lastSituation,
  });

  final Map<SkillCategory, CategoryInsight> skills;
  final Rank? rank;
  final RoadmapStepFacts? currentStep;
  final Map<CoachTopic, CoachTopicStats> coachStats;
  final CoachSituationFacts? lastSituation;

  /// JSON khoá ổn định: đổi tên khoá là đổi hợp đồng với Giai đoạn B.
  Map<String, Object?> toFacts() => {
        'skills': {
          for (final cat in SkillCategory.values)
            cat.name: {
              'mastery': skills[cat]?.mastery,
              'trend': skills[cat]?.trend.name,
              'sessions': skills[cat]?.sessionCount ?? 0,
            },
        },
        'rank': rank?.name,
        'currentStep': currentStep == null
            ? null
            : {
                'kind': currentStep!.kind.name,
                'status': currentStep!.status.name,
                'category': currentStep!.category?.name,
                'mastery': currentStep!.mastery,
              },
        'coach': {
          for (final t in CoachTopic.values)
            t.name: {
              'total': coachStats[t]?.total ?? 0,
              'solved': coachStats[t]?.solved ?? 0,
              'enough': coachStats[t]?.enough ?? false,
              'recurring': coachStats[t]?.recurring?.name,
              'recurringCount': coachStats[t]?.recurringCount ?? 0,
            },
        },
        'lastSituation': lastSituation == null
            ? null
            : {
                'key': lastSituation!.key,
                'topic': lastSituation!.topic.name,
                'outcome': lastSituation!.outcome.name,
                'firstFaultGroup': lastSituation!.firstFaultGroup?.name,
                'answers': lastSituation!.answers,
              },
      };
}

/// Ngữ cảnh cho Coach Chat, hàm thuần trên dữ liệu đã có.
CoachContext buildCoachContext({
  required PlayerIntelligence pi,
  required Rank? rank,
  required RoadmapStep? currentStep,
  required List<CoachAttempt> attempts,
}) {
  final last = attempts.isEmpty
      ? null
      : attempts.reduce((a, b) => b.finishedAt.isAfter(a.finishedAt) ? b : a);
  return CoachContext(
    skills: pi.categories,
    rank: rank,
    currentStep: currentStep == null ? null : roadmapStepFacts(currentStep),
    coachStats: summarizeCoachAttempts(attempts),
    lastSituation: last == null
        ? null
        : (
            key: last.situationKey,
            topic: last.topic,
            outcome: last.outcome,
            firstFaultGroup: last.firstFault == null ? null : faultGroupOf(last.firstFault!),
            answers: last.answers.length,
          ),
  );
}

/// Một lượt hội thoại của Coach Chat (Giai đoạn B).
typedef CoachChatTurn = ({bool fromPlayer, String text});

/// Câu trả lời của Coach Chat (Giai đoạn B). `insufficient`: bộ lọc chặn,
/// màn hình nói "chưa đủ dữ liệu".
typedef CoachChatReply = ({String text, bool insufficient});

/// Giao diện của Coach Chat. Giai đoạn A chưa có bản cài nào.
abstract interface class CoachChatBackend {
  Future<CoachChatReply> reply(CoachContext context, List<CoachChatTurn> history, String question);
}
