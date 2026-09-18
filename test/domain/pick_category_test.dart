import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

final _today = DateTime(2026, 9, 17); // Thứ Năm -> day index 3

Drill _drill(String id, SkillCategory cat) => Drill(
      id: id,
      cat: cat,
      name: 'Bài $id',
      level: 1,
      unit: 'lần trúng / 10',
      goal: 'g',
      steps: const ['s'],
      passThreshold: 0.8,
    );

DrillLog _log(String drillId, DateTime date, num score) => DrillLog(
      id: '$drillId-${date.day}',
      drillId: drillId,
      date: date,
      score: score,
      attempts: 10,
    );

final _drills = [
  _drill('aim1', SkillCategory.aiming),
  _drill('pos1', SkillCategory.position),
  _drill('brk1', SkillCategory.breakShot),
  _drill('saf1', SkillCategory.safety),
  _drill('kic1', SkillCategory.kick),
  _drill('ban1', SkillCategory.bank),
];

({SkillCategory cat, PickReason reason}) _pick({
  List<DrillLog> logs = const [],
  List<ScheduleSlot> schedule = const [],
  List<TimerSession> timers = const [],
}) {
  final pi = computePlayerIntelligence(drills: _drills, logs: logs);
  return pickCategoryForToday(
    pi: pi,
    drills: _drills,
    logs: logs,
    timerSessions: timers,
    schedule: schedule,
    today: _today,
  );
}

void main() {
  group('pickCategoryForToday', () {
    test('case A — chưa có log nào thì theo thứ tự làm quen, bắt đầu Ngắm bi',
        () {
      final result = _pick();
      expect(result.cat, SkillCategory.aiming);
      expect(result.reason, PickReason.newcomer);
    });

    test('case B — sắp mất streak thắng luật điểm yếu', () {
      // Có log cũ (5 ngày trước) cho thấy Phòng thủ rất yếu, nhưng hôm
      // nay và hôm qua đều trống -> phải ưu tiên kéo người quay lại.
      final old = _today.subtract(const Duration(days: 5));
      final result = _pick(
        logs: [
          _log('saf1', old, 2),
          _log('saf1', old.add(const Duration(days: 1)), 2),
          _log('saf1', old.add(const Duration(days: 2)), 2),
        ],
      );

      expect(result.reason, PickReason.streakAtRisk);
    });

    test('case C — lịch hôm nay thắng mọi luật khác', () {
      final old = _today.subtract(const Duration(days: 5));
      final result = _pick(
        logs: [
          _log('saf1', old, 2),
          _log('saf1', old.add(const Duration(days: 1)), 2),
          _log('saf1', old.add(const Duration(days: 2)), 2),
        ],
        schedule: [
          const ScheduleSlot(
            id: 's1',
            day: 3, // Thứ Năm
            time: '19:00',
            label: 'Tập tối',
            cat: SkillCategory.breakShot,
          ),
        ],
      );

      expect(result.cat, SkillCategory.breakShot);
      expect(result.reason, PickReason.scheduled);
    });

    test('có tập hôm qua nên không tính là sắp mất streak, chọn nhóm yếu nhất',
        () {
      final yesterday = _today.subtract(const Duration(days: 1));
      final result = _pick(
        logs: [
          _log('saf1', yesterday.subtract(const Duration(days: 2)), 2),
          _log('saf1', yesterday.subtract(const Duration(days: 1)), 2),
          _log('saf1', yesterday, 2),
        ],
      );

      expect(result.cat, SkillCategory.safety);
      expect(result.reason, PickReason.weakest);
    });

    test('lịch hôm nay không gắn nhóm thì không kích hoạt luật 1', () {
      final result = _pick(
        schedule: [
          const ScheduleSlot(
            id: 's1',
            day: 3,
            time: '19:00',
            label: 'Tập tự do',
          ),
        ],
      );

      expect(result.reason, isNot(PickReason.scheduled));
    });

    test('lịch của thứ khác không ảnh hưởng hôm nay', () {
      final result = _pick(
        schedule: [
          const ScheduleSlot(
            id: 's1',
            day: 0, // Thứ Hai, hôm nay là Thứ Năm
            time: '19:00',
            label: 'Tập tối',
            cat: SkillCategory.kick,
          ),
        ],
      );

      expect(result.reason, isNot(PickReason.scheduled));
    });

    test('thứ tự làm quen phủ hết mọi nhóm kỹ năng', () {
      // Thiếu một nhóm trong thứ tự nghĩa là luật 4 rơi xuống luật khác
      // khi nhóm đó là nhóm duy nhất chưa có dữ liệu.
      expect(newcomerOrder.toSet(), SkillCategory.values.toSet());
    });
  });
}
