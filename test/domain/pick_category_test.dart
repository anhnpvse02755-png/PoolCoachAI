import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

import '../support/match_fixtures.dart';

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
  List<PoolMatch> matches = const [],
}) {
  final pi = computePlayerIntelligence(
    drills: _drills,
    logs: logs,
    matches: matches,
  );
  return pickCategoryForToday(
    pi: pi,
    drills: _drills,
    logs: logs,
    timerSessions: timers,
    schedule: schedule,
    today: _today,
  );
}

const _advDrill = Drill(
  name: 'Bài x1',
  id: 'x1',
  cat: SkillCategory.dungCo,
  level: 1,
  unit: 'u',
  goal: 'g',
  steps: [],
  target: 3,
);

void main() {
  group('nhóm nâng cao', () {
    ({SkillCategory cat, PickReason reason}) pickWith(
        List<Drill> drills, List<DrillLog> logs) {
      final pi = computePlayerIntelligence(drills: drills, logs: logs);
      return pickCategoryForToday(
        pi: pi,
        drills: drills,
        logs: logs,
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );
    }

    final basicLogs = [
      for (final (i, id) in ['aim1', 'pos1', 'brk1', 'saf1', 'kic1', 'ban1'].indexed)
        _log(id, _today.subtract(Duration(days: 1, hours: -i)), 9),
    ];

    test('thứ tự làm quen phủ chín nhóm, ba nhóm nâng cao đứng cuối', () {
      expect(newcomerOrder.toSet(), SkillCategory.values.toSet());
      expect(newcomerOrder.skip(6),
          [SkillCategory.dungCo, SkillCategory.nhayBi, SkillCategory.matXe]);
    });

    test('đã tập đủ sáu nhóm cơ bản, chưa tập nhóm nâng cao: luân phiên không chọn nhóm nâng cao', () {
      final r = pickWith([..._drills, _advDrill], basicLogs);
      expect(r.reason, PickReason.rotation);
      expect(r.cat.isAdvanced, isFalse);
    });

    test('sắp mất streak: không chọn nhóm nâng cao chưa tập', () {
      // Cả sáu nhóm cơ bản đều có log (cách đây 5 ngày) nên nhóm nâng cao
      // (đếm 0) sẽ thắng nếu luật 2 không bỏ nó ra.
      final old = [
        for (final (i, id) in ['aim1', 'pos1', 'brk1', 'saf1', 'kic1', 'ban1'].indexed)
          _log(id, _today.subtract(Duration(days: 5, hours: -i)), 9),
      ];
      final r = pickWith([..._drills, _advDrill], old);
      expect(r.reason, PickReason.streakAtRisk);
      expect(r.cat.isAdvanced, isFalse);
    });

    test('có một buổi Dựng cơ lâu nhất: luân phiên chọn Dựng cơ', () {
      final logs = [
        _log('x1', _today.subtract(const Duration(days: 20)), 2),
        for (final (i, id) in ['aim1', 'pos1', 'brk1', 'saf1', 'kic1', 'ban1'].indexed)
          _log(id, _today.subtract(Duration(days: 1, hours: -i)), 9),
      ];
      final r = pickWith([..._drills, _advDrill], logs);
      expect(r.reason, PickReason.rotation);
      expect(r.cat, SkillCategory.dungCo);
    });
  });

  group('pickCategoryForToday', () {
    group('yếu trong trận', () {
      final yesterday = _today.subtract(const Duration(days: 1));
      final weakAim = [
        _log('aim1', yesterday.subtract(const Duration(days: 2)), 2),
        _log('aim1', yesterday.subtract(const Duration(days: 1)), 2),
        _log('aim1', yesterday, 2),
      ];

      test('yếu trong trận thắng luật yếu theo bài tập', () {
        final result = _pick(
          logs: weakAim,
          matches: matchesWeakAt(SkillCategory.position, at: yesterday),
        );
        expect(result.cat, SkillCategory.position);
        expect(result.reason, PickReason.matchWeakness);
      });

      test('chỉ có yếu trong trận thì vẫn chọn nhóm đó', () {
        final result = _pick(
          logs: [_log('saf1', yesterday, 10)],
          matches: matchesWeakAt(SkillCategory.aiming, at: yesterday),
        );
        expect(result.cat, SkillCategory.aiming);
        expect(result.reason, PickReason.matchWeakness);
      });

      test('lịch hôm nay đứng trên yếu trong trận', () {
        final result = _pick(
          logs: weakAim,
          schedule: [
            const ScheduleSlot(
              id: 's1',
              day: 3,
              time: '19:00',
              label: 'Tối',
              cat: SkillCategory.bank,
            ),
          ],
          matches: matchesWeakAt(SkillCategory.position, at: yesterday),
        );
        expect(result.cat, SkillCategory.bank);
        expect(result.reason, PickReason.scheduled);
      });

      test('sắp mất streak đứng trên yếu trong trận', () {
        final result = _pick(
          logs: [_log('saf1', _today.subtract(const Duration(days: 5)), 10)],
          matches: matchesWeakAt(SkillCategory.position,
              at: _today.subtract(const Duration(days: 5))),
        );
        expect(result.reason, PickReason.streakAtRisk);
      });
    });

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
