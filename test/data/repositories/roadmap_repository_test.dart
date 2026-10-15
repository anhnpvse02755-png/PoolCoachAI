import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  late AppDatabase db;
  var clock = DateTime(2026, 10, 15, 9);
  var ids = 0;

  RoadmapRepository repo(String userId) =>
      RoadmapRepository(db, userId: userId, now: () => clock, newId: () => 'g${++ids}');

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = DateTime(2026, 10, 15, 9);
    ids = 0;
  });
  tearDown(() => db.close());

  test('đặt mục tiêu ghi xuống Drift, chưa đồng bộ', () async {
    await repo('u1').setGoal(kind: GoalKind.thuanThucKyNang, category: SkillCategory.kick);
    final g = await repo('u1').watchGoal().first;
    expect(g!.goal!.kind, GoalKind.thuanThucKyNang);
    expect(g.goal!.category, SkillCategory.kick);
    expect(g.goal!.goalId, 'g1');
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, isNull);
  });

  test('đổi mục tiêu ra id mới và ngày tạo mới', () async {
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    clock = DateTime(2026, 10, 16, 9);
    await repo('u1').setGoal(kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2, 18));
    final g = (await repo('u1').watchGoal().first)!.goal!;
    expect(g.goalId, 'g2');
    expect(g.createdAt, clock);
    expect(g.eventDate, DateTime(2026, 11, 2), reason: 'ngày giải chỉ giữ ngày');
  });

  test('đổi từ Thuần thục sang Lên hạng thì không còn nhóm cũ', () async {
    // Ghi đè một dòng có cột null: cột cũ phải về null, không được giữ lại.
    await repo('u1').setGoal(kind: GoalKind.thuanThucKyNang, category: SkillCategory.kick);
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    expect((await db.select(db.playerGoalRows).getSingle()).category, isNull);
  });

  test('bỏ mục tiêu để lại dòng rỗng mới hơn (R2)', () async {
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    clock = DateTime(2026, 10, 16, 9);
    await repo('u1').clearGoal();
    final g = await repo('u1').watchGoal().first;
    expect(g!.goal, isNull);
    expect(g.updatedAt, clock);
  });

  test('ghi thành tích hai lần chỉ còn một dòng; mới nhất trước', () async {
    final a = Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: DateTime(2026, 10, 10));
    final b = Achievement(kind: AchievementKind.duDieuKienLenCap, refId: 'd1', achievedAt: DateTime(2026, 10, 12));
    await repo('u1').recordAchievements([a]);
    await repo('u1').recordAchievements([a, b]);
    expect(await repo('u1').watchAchievements().first, [b, a]);
  });

  test('mục tiêu và thành tích tách theo người', () async {
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    await repo('u1').recordAchievements(
        [Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: DateTime(2026, 10, 10))]);
    expect(await repo('u2').watchGoal().first, isNull);
    expect(await repo('u2').watchAchievements().first, isEmpty);
  });
}
