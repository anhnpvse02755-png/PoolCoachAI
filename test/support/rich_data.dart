import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

import 'roadmap_fixtures.dart';
import 'skill_test_fixtures.dart';
import 'test_data.dart';

const _longPlayer = 'Nguyễn Văn Trường Giang';
const _longOpponent = 'Trần Thị Bích Ngọc Hạnh';

/// Câu hỏi khoảng 200 ký tự, câu trả lời khoảng 600 ký tự — quét chiều
/// rộng và chữ lớn phải gặp bong bóng thật, không chỉ chuỗi ngắn.
const _longQuestion =
    'Tuần này tôi tập Ngắm bi và Vị trí đều đặn mỗi tối, nhưng trận vừa rồi '
    'vẫn thua liên tiếp ba rack vì hỏng bi cắt mỏng và không giữ được vị trí '
    'cho cú kế tiếp, vậy tôi nên đổi cách tập thế nào cho tuần sau?';
const _longAnswer =
    'Theo số liệu bạn ghi lại, nhóm Ngắm bi của bạn đạt 7 trên 10 lần gần '
    'nhất còn nhóm Vị trí chỉ đạt 4 trên 10, nên phần hỏng vị trí đang kéo '
    'điểm xuống nhiều hơn phần ngắm bi. Trận vừa rồi cả ba rack thua đều có '
    'ít nhất một cú hỏng vị trí ngay trước cú hỏng bi cuối cùng, nên hai '
    'việc này có liên quan tới nhau: giữ bi cái đúng chỗ thì cú cắt mỏng '
    'tiếp theo mới dễ hơn. Tuần sau nên ưu tiên bài tập Vị trí thêm hai '
    'buổi, giữ nguyên lịch Ngắm bi đang có, và ghi lại từng buổi để tuần '
    'sau nữa so sánh được số liệu thật, không phải cảm giác. Khi nào hai '
    'nhóm cùng đạt trên bảy trên mười lần gần nhất thì mới nên tăng độ khó '
    'của bài tập Vị trí lên mức tiếp theo.';

/// Lượt chat dài cho quét chiều rộng và chữ lớn: một câu hỏi ~200 ký tự,
/// một câu trả lời ~600 ký tự, và một lượt bị chặn (chưa đủ dữ liệu).
final coachChatTurnsRich = <CoachChatEntry>[
  (
    id: 1,
    at: DateTime(2026, 10, 20, 9),
    fromPlayer: true,
    text: _longQuestion,
    insufficient: false,
  ),
  (
    id: 2,
    at: DateTime(2026, 10, 20, 9, 1),
    fromPlayer: false,
    text: _longAnswer,
    insufficient: false,
  ),
  (
    id: 3,
    at: DateTime(2026, 10, 21, 9),
    fromPlayer: true,
    text: 'Tôi hợp cơ nào nhất?',
    insufficient: false,
  ),
  (
    id: 4,
    at: DateTime(2026, 10, 21, 9, 1),
    fromPlayer: false,
    text: '',
    insufficient: true,
  ),
];

/// Dữ liệu đầy, tên dài: quét tràn phải gặp hàng thật, không chỉ màn trống.
ProviderContainer richContainer() => testContainer(
  logs: sessions('d1', 8, [
    for (var i = 1; i <= 7; i++) testToday.subtract(Duration(days: i)),
  ]),
  timerSessions: [
    TimerSession(
      id: 'timer-1',
      date: testToday,
      durationSec: 3600,
      cueId: 'cue-long',
    ),
    TimerSession(
      id: 'timer-2',
      date: testToday.subtract(const Duration(days: 1)),
      durationSec: 1800,
    ),
  ],
  schedule: const [
    ScheduleSlot(
      id: 's1',
      day: 1,
      time: '19:00',
      label: 'Tập điều bi và dọn bàn 9 bi theo bộ đề BU',
      cat: SkillCategory.position,
    ),
    ScheduleSlot(
      id: 's2',
      day: 3,
      time: '06:30',
      label: 'Ngắm bi cắt mỏng',
      cat: SkillCategory.aiming,
    ),
  ],
  equipment: [
    CueEquipment(
      id: 'cue-long',
      name: 'Cơ chơi Predator Revo 12.4 Carbon ngọn dài bản giới hạn',
      type: CueType.values.first,
      shaftBrand: 'Predator',
      shaftDiameterMm: 12.4,
      tipBrand: 'Kamui Black Super Soft',
      buttBrand: 'Cuetec Cynergy',
      skillCategories: const [SkillCategory.aiming, SkillCategory.position],
      lastTipMaintenance: DateTime(2026, 8, 15),
      tipMaintenanceDueDate: DateTime(2026, 9, 15), // quá hạn so với testToday
    ),
    const CueEquipment(
      id: 'cue-break',
      name: 'Cơ phá nhảy',
      type: CueType.breakJump,
      skillCategories: [SkillCategory.aiming],
    ),
  ],
  tournaments: [
    Tournament(
      id: 't1',
      name:
          'Giải Vô địch Bida Pool 9 bi Mở rộng Thành phố Hồ Chí Minh lần thứ XII',
      startDate: testToday.subtract(const Duration(days: 1)),
      endDate: testToday.add(const Duration(days: 1)),
      location: 'Câu lạc bộ Bida Ngôi Sao, 123 Nguyễn Văn Linh, Quận 7',
      gameType: PoolGameType.nineBall,
      resultNote: 'Vào vòng 16 sau trận căng thẳng với hạt giống số 1',
      notes:
          'Giải mở rộng dành cho mọi trình độ, thi đấu loại trực tiếp sau vòng '
          'bảng, mỗi trận thắng trước năm ván, có trọng tài, lệ phí hai trăm '
          'nghìn đồng, nhớ mang cơ riêng và đến sớm ba mươi phút để bốc thăm.',
    ),
    Tournament(
      id: 't2',
      name: 'Giải Cúp Mùa Đông',
      startDate: testToday.add(const Duration(days: 10)),
    ),
  ],
  matches: [
    // stats_screen_test.dart, đổi tên người chơi cho dài và thêm cơ.
    PoolMatch(
      id: 'match',
      gameType: PoolGameType.nineBall,
      playerName: _longPlayer,
      opponentName: _longOpponent,
      targetRacks: 3,
      rackWinners: const [
        RackWinner.player,
        RackWinner.opponent,
        RackWinner.player,
        RackWinner.player,
      ],
      shots: [
        MatchShot(
          id: 'shot',
          rackNumber: 1,
          shotNumber: 1,
          shooter: RackWinner.player,
          type: MatchShotType.breakShot,
          outcome: MatchShotOutcome.scratch,
          positionOutcome: PositionOutcome.successful,
          recordedAt: testToday,
        ),
      ],
      startedAt: testToday,
      completedAt: testToday,
      cueId: 'cue-long',
      tournamentId: 't1',
      roundLabel: 'Tứ kết',
    ),
    // Một trận đang đánh dở.
    PoolMatch(
      id: 'match-2',
      gameType: PoolGameType.nineBall,
      playerName: _longPlayer,
      opponentName: _longOpponent,
      targetRacks: 3,
      rackWinners: const [RackWinner.opponent],
      startedAt: testToday,
    ),
  ],
  rank: PlayerRank(
    rank: Rank.d,
    source: RankSource.verified,
    buScore: 137,
    testId: 't1',
    onboardingState: OnboardingState.done,
    updatedAt: testToday,
  ),
  tests: [
    BuTest(
      id: 't1',
      startedAt: testToday.subtract(const Duration(days: 4)),
      tableSize: TableSize.nineFootPlus,
      completedAt: testToday.subtract(const Duration(days: 3)),
      examIScore: 60,
      examIIVersion: ExamIIVersion.masters,
      examIIScore: 77,
      totalScore: 137,
      resultRank: Rank.d,
    ),
  ],
  goal: GoalRecord(
    updatedAt: testToday,
    goal: PlayerGoal(
      goalId: 'g',
      kind: GoalKind.thuanThucKyNang,
      category: SkillCategory.aiming,
      createdAt: testToday,
    ),
  ),
  achievements: [
    Achievement(
      kind: AchievementKind.chuoiNgay,
      refId: '7',
      achievedAt: testToday,
    ),
  ],
  buResult: BuResult(
    testId: 't1',
    completedAt: testToday.subtract(const Duration(days: 3)),
    total: 137,
    lost: const {'F1': 5, 'F3': 4, 'S5': 6},
  ),
  coachChatTurns: coachChatTurnsRich,
  // d1 vẫn còn ba buổi đạt sau lần trượt này: testable, Hồ sơ hiện "3/3".
  skillTests: [
    failedTest('d1', 1, testToday.subtract(const Duration(days: 3, hours: 12))),
  ],
);
