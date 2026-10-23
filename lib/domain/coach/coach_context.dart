import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/chat_facts.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
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
    required this.weak,
    required this.strong,
    required this.today,
    required this.matches,
  });

  final Map<SkillCategory, CategoryInsight> skills;
  final Rank? rank;
  final RoadmapStepFacts? currentStep;
  final Map<CoachTopic, CoachTopicStats> coachStats;
  final CoachSituationFacts? lastSituation;

  /// Nhóm dưới ngưỡng yếu, yếu nhất trước (`PlayerIntelligence.weak`).
  final List<SkillCategory> weak;

  /// Nhóm từ ngưỡng mạnh trở lên, mạnh nhất trước (`PlayerIntelligence.strong`).
  final List<SkillCategory> strong;

  /// Gợi ý hôm nay, dạng dữ liệu; `null` khi chưa tính được.
  final TodayFacts? today;

  /// Lịch sử trận gần nhất, dạng dữ liệu.
  final MatchFacts matches;

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
        'skillLevels': {
          'weak': [for (final cat in weak) cat.name],
          'strong': [for (final cat in strong) cat.name],
          'weakBelow': PracticeConstants.weakCutoff,
          'strongFrom': PracticeConstants.strongCutoff,
          'minSessions': PracticeConstants.minSessions,
        },
        'today': today == null
            ? null
            : {
                'category': today!.category.name,
                'reason': today!.reason.name,
                'drillId': today!.drillId,
                'drillName': today!.drillName,
                'articleTitle': today!.articleTitle,
                'streak': today!.streak,
                'practiceMinutesThisWeek': today!.practiceMinutesThisWeek,
                'scheduledToday': today!.scheduledToday,
              },
        'matches': {
          'recent': {
            'played': matches.played,
            'won': matches.won,
            'lost': matches.lost,
          },
          'last': matches.last == null
              ? null
              : {
                  'gameType': matches.last!.gameType.name,
                  'targetRacks': matches.last!.targetRacks,
                  'racksWon': matches.last!.racksWon,
                  'racksLost': matches.last!.racksLost,
                  'won': matches.last!.won,
                  'shots': {
                    for (final type in matches.last!.shots.keys)
                      type.name: {
                        for (final entry in matches.last!.shots[type]!.entries)
                          entry.key.name: entry.value,
                      },
                  },
                  'positionOutcomes': {
                    for (final entry in matches.last!.positionOutcomes.entries)
                      entry.key.name: entry.value,
                  },
                },
        },
      };
}

/// Ngữ cảnh cho Coach Chat, hàm thuần trên dữ liệu đã có.
CoachContext buildCoachContext({
  required PlayerIntelligence pi,
  required Rank? rank,
  required RoadmapStep? currentStep,
  required List<CoachAttempt> attempts,
  required TodayRecommendation? today,
  required List<PoolMatch> matches,
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
    weak: pi.weak,
    strong: pi.strong,
    today: today == null ? null : todayFactsOf(today),
    matches: matchFactsOf(matches),
  );
}

/// Một lượt hội thoại của Coach Chat (Giai đoạn B).
typedef CoachChatTurn = ({bool fromPlayer, String text});

/// Câu trả lời của Coach Chat (Giai đoạn B). `insufficient`: bộ lọc chặn,
/// màn hình nói "chưa đủ dữ liệu".
typedef CoachChatReply = ({String text, bool insufficient});

/// Câu trả lời cùng số lượt hỏi còn lại trong ngày (Task 6: trường
/// `remainingToday` của wire contract).
typedef CoachChatAnswer = ({CoachChatReply reply, int remainingToday});

/// Hết lượt hỏi trong ngày (HTTP 429). [resetAt] là lúc lượt được cấp lại.
final class CoachChatQuotaExceeded implements Exception {
  const CoachChatQuotaExceeded(this.resetAt);

  final DateTime resetAt;

  @override
  String toString() => 'CoachChatQuotaExceeded($resetAt)';
}

/// Không gọi được dịch vụ coach-chat: mất mạng, hết giờ, hay máy chủ lỗi
/// (401, 4xx khác 429, 502 upstream, 503, 500, hay phản hồi hỏng). Tách khỏi
/// [CoachChatQuotaExceeded] và phiên hết hạn vì hai việc đó có hành vi riêng
/// (R4, luật của controller: 401 là vấn đề của lớp auth, không phải quota).
final class CoachChatUnavailable implements Exception {
  const CoachChatUnavailable(this.cause);

  final Object cause;

  @override
  String toString() => 'CoachChatUnavailable($cause)';
}

/// Giao diện của Coach Chat. Giai đoạn B: [RemoteCoachChat] trong
/// `lib/data/remote/coach_chat_client.dart`.
abstract interface class CoachChatBackend {
  Future<CoachChatAnswer> reply(CoachContext context, List<CoachChatTurn> history, String question);

  /// Số lượt hỏi còn lại hôm nay, không phải lúc gửi câu hỏi (ví dụ để hiện
  /// ngay khi mở màn Coach Chat).
  Future<int> remainingToday();
}

/// Một lượt chat đã lưu trên máy — [id] là khoá Drift, dùng để sắp thứ tự
/// ổn định khi hai lượt cùng thời điểm (câu hỏi và câu trả lời ghi cùng
/// lúc).
typedef CoachChatEntry = ({int id, DateTime at, bool fromPlayer, String text, bool insufficient});

/// [coachChatHistoryTurns] lượt cuối, cũ trước; lượt bị chặn gửi
/// [insufficientText] thay cho message rỗng (R19) — đúng câu người chơi đã
/// thấy trên màn hình. Mỗi lượt bị clip tới [coachChatMaxTurnChars] ký tự
/// (UTF-16 code unit, khớp luật kiểm phía máy chủ): một câu trả lời dài của
/// Claude không được làm hỏng việc gửi mọi câu hỏi sau (ruling controller,
/// Task 9).
List<CoachChatTurn> coachChatHistory(List<CoachChatEntry> entries, {required String insufficientText}) {
  final recent = entries.length <= coachChatHistoryTurns
      ? entries
      : entries.sublist(entries.length - coachChatHistoryTurns);
  return [
    for (final entry in recent)
      (
        fromPlayer: entry.fromPlayer,
        text: _clipTurnText(entry.insufficient ? insufficientText : entry.text),
      ),
  ];
}

/// Clip ở [coachChatMaxTurnChars] ký tự, nhưng không cắt giữa một cặp
/// surrogate (vd. emoji): nếu ký tự ngay trước điểm cắt là nửa đầu
/// (high surrogate, 0xD800–0xDBFF) thì lùi điểm cắt lại một ký tự, bỏ cả
/// cặp — tránh để lại một surrogate lẻ không giải mã được (controller
/// review Task 9).
String _clipTurnText(String text) {
  if (text.length <= coachChatMaxTurnChars) return text;
  final lastUnit = text.codeUnitAt(coachChatMaxTurnChars - 1);
  final cutAt = lastUnit >= 0xD800 && lastUnit <= 0xDBFF ? coachChatMaxTurnChars - 1 : coachChatMaxTurnChars;
  return text.substring(0, cutAt);
}
