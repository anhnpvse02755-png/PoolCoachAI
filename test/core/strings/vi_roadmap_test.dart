import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final at = DateTime(2026, 10, 15);

  RoadmapStep step(
    StepKind kind,
    StepReason reason, {
    SkillCategory? category,
    List<String> bu = const [],
  }) =>
      RoadmapStep(
        kind: kind,
        status: StepStatus.dangLam,
        reason: reason,
        category: category,
        buDrillIds: bu,
      );

  test('lý do mang đúng con số của hàm tính', () {
    expect(
      Vi.stepReason(const LostBuPoints(18, ['F3', 'F5'])),
      'Mất 18 điểm BU ở F3, F5.',
    );
    expect(Vi.stepReason(const Unmeasured(1)), 'Tập đủ 3 buổi để đo (đã có 1).');
    expect(Vi.stepReason(const BelowStrong(62)), 'Còn thiếu 13 điểm để đạt 75.');
    expect(
      Vi.stepReason(const NeedStreak()),
      'Đã đạt 75, cần 3 buổi đạt liên tiếp.',
    );
    expect(Vi.stepReason(const DrillLevel(2)), 'Bài cấp 2 của nhóm.');
    expect(Vi.stepReason(const RetestFrom(null)), 'Làm được ngay.');
    expect(
      Vi.stepReason(RetestFrom(DateTime(2026, 10, 28))),
      'Mở từ ngày 28/10/2026.',
    );
  });

  test('lý do và tên của bước dùng dữ liệu trận', () {
    expect(Vi.stepReason(const MatchWeakness(7, 12)), 'Hỏng 7/12 lần trong các trận gần đây.');
    expect(Vi.stepReason(const NotEnoughMatches(1, 3)), 'Có 1/3 trận có ghi cú trong 28 ngày qua.');
    expect(Vi.stepTitle(step(StepKind.dauTap, const NotEnoughMatches(1, 3))),
        'Đấu tập: ghi ít nhất 2 trận có ghi cú');
    expect(Vi.stepRecordMatch, 'Ghi trận');
  });

  test('tên bước', () {
    expect(
      Vi.stepTitle(
        step(
          StepKind.buLe,
          const LostBuPoints(3, ['S8', 'S9']),
          bu: ['S8', 'S9'],
        ),
      ),
      'Tập lại S8/S9 trên bàn BU',
    );
    expect(
      Vi.stepTitle(
        step(
          StepKind.nhom,
          const Unmeasured(0),
          category: SkillCategory.kick,
        ),
        drillName: 'Bài A',
      ),
      'A băng · Bài A',
    );
    expect(
      Vi.stepTitle(step(StepKind.lamBaiBu, const RetestFrom(null))),
      'Làm bài BU',
    );
  });

  test('mốc hạng: tên bước và lý do mang hạng và sàn điểm BU', () {
    expect(
      Vi.stepTitle(step(StepKind.lamBaiBu, const RankMilestone(Rank.g))),
      'Làm lại bài BU — mốc hạng G',
    );
    expect(
      Vi.stepTitle(step(StepKind.lamBaiBu, const RankMilestone(Rank.g, retake: false))),
      'Làm bài BU — mốc hạng G',
    );
    expect(Vi.stepReason(const RankMilestone(Rank.g)), 'Đạt 70 điểm BU là lên hạng G.');
    expect(Vi.goalTargetRankTitle, 'Lên tới hạng');
    expect(
      Vi.goalKindBody(GoalKind.lenHang),
      'Chọn hạng đích, từ hạng ngay trên tới hạng A, theo điểm BU còn thiếu.',
    );
    final roadmap = Roadmap(
      goal: PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at, targetRank: Rank.f),
      steps: const [],
      from: Rank.h,
      target: Rank.f,
      pointsNeeded: 45,
    );
    expect(Vi.roadmapHeadline(roadmap), 'Lên hạng: H → F');
  });

  test('ngày dự kiến: có ngày hoặc nói thẳng chưa đủ dữ liệu', () {
    expect(
      Vi.estimateLine(Estimate.on(DateTime(2026, 11, 2))),
      'Dự kiến: 02/11/2026',
    );
    expect(
      Vi.estimateLine(const Estimate.notEnoughData()),
      'Dự kiến: chưa đủ dữ liệu',
    );
    expect(
      Vi.finishLine(const Estimate.notEnoughData()),
      'Dự kiến xong: chưa đủ dữ liệu',
    );
  });

  test('đầu trang Lên hạng nói điểm còn thiếu và sàn của hạng đích', () {
    final roadmap = Roadmap(
      goal: PlayerGoal(
        goalId: 'g',
        kind: GoalKind.lenHang,
        createdAt: at,
      ),
      steps: const [],
      from: Rank.d,
      target: Rank.c,
      pointsNeeded: 3,
    );
    expect(Vi.roadmapHeadline(roadmap), 'Lên hạng: D → C');
    expect(
      Vi.roadmapNeed(roadmap),
      'Cần thêm 3 điểm BU (hạng C từ 140 điểm).',
    );
  });

  test('thành tích', () {
    expect(Vi.achievement(AchievementKind.chungNhan, 'Bài A'), 'Chứng nhận: Bài A');
    expect(
      Vi.achievement(AchievementKind.chuoiNgay, '7'),
      'Chuỗi 7 ngày tập liên tiếp',
    );
    expect(
      Vi.achievement(AchievementKind.duDieuKienLenCap, 'Bài A'),
      'Đủ điều kiện lên cấp: Bài A',
    );
  });

  test('không dùng từ đã bị chủ sản phẩm sửa', () {
    final texts = [
      for (final kind in GoalKind.values) ...[
        Vi.goalKind(kind),
        Vi.goalKindBody(kind),
      ],
      for (final block in LenHangBlock.values) Vi.goalBlocked(block),
      for (final status in StepStatus.values) Vi.stepStatus(status),
      Vi.roadmapCardBody,
      Vi.achievementsEmpty,
      Vi.roadmapMissedTitle,
    ];
    for (final text in texts) {
      for (final banned in ['kim cương', 'bi ma', 'lọt bi cái']) {
        expect(text.toLowerCase(), isNot(contains(banned)), reason: text);
      }
    }
  });
}
