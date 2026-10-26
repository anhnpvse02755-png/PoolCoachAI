import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import 'coach_fixtures.dart' show attempt;

/// Tên mẫu dùng trong cố định Coach Chat — không bao giờ xuất hiện trong facts.
const samplePlayerName = 'Nguyễn Văn An';
const sampleOpponentName = 'Trần Thị Bình';

/// Gợi ý "Hôm nay" mẫu cho các test Coach Chat.
TodayRecommendation sampleToday() => const TodayRecommendation(
      cat: SkillCategory.safety,
      reason: PickReason.weakest,
      drill: Drill(
        id: 'd7',
        cat: SkillCategory.safety,
        name: 'Bài 3: thủ sau bi 9',
        level: 3,
        unit: 'lần đạt / 10',
        passThreshold: 0.7,
        goal: 'g',
        steps: [],
      ),
      article: KnowledgeArticle(
        id: 'ka-safety-1',
        cat: SkillCategory.safety,
        title: 'Phòng thủ bắt đui',
        body: 'b',
      ),
      readyDrillIds: [],
      streak: 4,
      practiceSecondsThisWeek: 5430,
      todaySchedule: [
        ScheduleSlot(id: 'sch-1', day: 0, time: '19:00', label: 'Tập thủ 19:00', cat: SkillCategory.safety),
      ],
    );

var _matchShotCounter = 0;

/// Một cú đánh trong trận, cho các test Coach Chat.
MatchShot matchShot(
  RackWinner shooter,
  MatchShotType type,
  MatchShotOutcome outcome, {
  PositionOutcome? position,
}) {
  _matchShotCounter++;
  return MatchShot(
    id: 'ms$_matchShotCounter',
    rackNumber: 1,
    shotNumber: _matchShotCounter,
    shooter: shooter,
    type: type,
    outcome: outcome,
    positionOutcome: position,
    recordedAt: DateTime(2026, 10, 1, 8).add(Duration(minutes: _matchShotCounter)),
  );
}

/// Một trận đã xong, cho các test Coach Chat — chín bi, tên mẫu.
PoolMatch finishedMatch(
  String id,
  List<RackWinner> racks, {
  required DateTime completedAt,
  List<MatchShot> shots = const [],
  int target = 3,
}) =>
    PoolMatch(
      id: id,
      gameType: PoolGameType.nineBall,
      playerName: samplePlayerName,
      opponentName: sampleOpponentName,
      targetRacks: target,
      rackWinners: racks,
      startedAt: completedAt.subtract(const Duration(hours: 1)),
      shots: shots,
      completedAt: completedAt,
    );

/// Một trận đang đánh (chưa xong), cho các test Coach Chat.
PoolMatch openMatch(
  String id,
  List<RackWinner> racks, {
  required DateTime startedAt,
}) =>
    PoolMatch(
      id: id,
      gameType: PoolGameType.nineBall,
      playerName: samplePlayerName,
      opponentName: sampleOpponentName,
      // Đích luôn cao hơn số rack đã chơi, nên trận không bao giờ "đã xong".
      targetRacks: racks.length + 1,
      rackWinners: racks,
      startedAt: startedAt,
    );

final _fixtureDrills = <Drill>[
  const Drill(
    id: 'fx-safety',
    cat: SkillCategory.safety,
    name: 'fx-safety',
    level: 1,
    unit: 'lần đạt / 10',
    passThreshold: 0.8,
    goal: 'g',
    steps: [],
  ),
  const Drill(
    id: 'fx-aiming',
    cat: SkillCategory.aiming,
    name: 'fx-aiming',
    level: 1,
    unit: 'lần đạt / 10',
    passThreshold: 0.8,
    goal: 'g',
    steps: [],
  ),
];

/// Nhật ký mẫu: yếu Phòng thủ, mạnh Ngắm bi — đủ 3 buổi mỗi nhóm
/// ([PracticeConstants.minSessions]) để `weak`/`strong` đều khác rỗng.
List<DrillLog> _fixtureLogs() => [
      for (var i = 0; i < 3; i++)
        DrillLog(id: 'fx-safety-$i', drillId: 'fx-safety', date: DateTime(2026, 10, 19 + i), score: 2, attempts: 10),
      for (var i = 0; i < 3; i++)
        DrillLog(id: 'fx-aiming-$i', drillId: 'fx-aiming', date: DateTime(2026, 10, 19 + i), score: 10, attempts: 10),
    ];

// `attempt()` dùng bộ đếm dùng chung (coach_fixtures.dart): gọi một lần,
// dùng lại cho mọi lần gọi `fullCoachContext()`, để facts tất định — gọi
// lại mỗi lần sẽ đổi `situationKey` dù không có gì khác thay đổi.
final _fixtureAttempt =
    attempt(CoachAttemptOutcome.revealed, topic: CoachTopic.safety, fault: CoachFault.scratch);

/// Ngữ cảnh đầy đủ cho Coach Chat: mọi nhánh của facts đều khác null.
CoachContext fullCoachContext() => buildCoachContext(
      pi: computePlayerIntelligence(drills: _fixtureDrills, logs: _fixtureLogs()),
      rank: Rank.g,
      currentStep: const RoadmapStep(
        kind: StepKind.nhom,
        status: StepStatus.dangLam,
        reason: NeedStreak(),
        category: SkillCategory.safety,
        mastery: 50,
      ),
      attempts: [_fixtureAttempt],
      today: sampleToday(),
      matches: [
        finishedMatch(
          'fm-1',
          [RackWinner.player, RackWinner.opponent, RackWinner.player, RackWinner.player],
          completedAt: DateTime(2026, 10, 20),
          shots: [
            matchShot(RackWinner.player, MatchShotType.breakShot, MatchShotOutcome.made),
            matchShot(RackWinner.player, MatchShotType.normal, MatchShotOutcome.made, position: PositionOutcome.successful),
          ],
        ),
      ],
    );
