import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/domain/tournament/tournament_goal.dart';

import '../../support/tournament_fixtures.dart';

void main() {
  final up = tour('up', start: tDay(5));
  group('linkedTournament — đủ ba điều kiện', () {
    test('chuẩn bị giải, giải còn, cùng ngày (khác giờ vẫn là cùng ngày)', () {
      expect(linkedTournament(prepGoal(tDay(5), tournamentId: 'up'), [up]), up);
      expect(
        linkedTournament(
          prepGoal(DateTime(2026, 11, 2, 18), tournamentId: 'up'),
          [up],
        ),
        up,
      );
    });
    // Review Focus 1
    test(
      'lệch ngày (đổi ngày giải sau khi đặt mục tiêu): bỏ liên kết',
      () => expect(
        linkedTournament(prepGoal(tDay(6), tournamentId: 'up'), [up]),
        isNull,
      ),
    );
    test(
      'giải đã xóa: bỏ liên kết',
      () => expect(
        linkedTournament(prepGoal(tDay(5), tournamentId: 'up'), const []),
        isNull,
      ),
    );
    test('sai loại (bản cũ để sót tournament_id): bỏ liên kết', () {
      final stale = PlayerGoal(
        goalId: 'g',
        kind: GoalKind.thuanThucKyNang,
        category: SkillCategory.aiming,
        createdAt: tToday,
        tournamentId: 'up',
      );
      expect(linkedTournament(stale, [up]), isNull);
    });
    test('không có mục tiêu hoặc không có tournament_id', () {
      expect(linkedTournament(null, [up]), isNull);
      expect(linkedTournament(prepGoal(tDay(5)), [up]), isNull);
    });
  });
  test('trạng thái nút Chuẩn bị cho giải này', () {
    TournamentGoalState s(Tournament t, PlayerGoal? g) =>
        tournamentGoalState(t, goal: g, live: [up, t], today: tToday);
    expect(
      s(tour('on', start: tDay(0)), null),
      TournamentGoalState.notUpcoming,
    );
    expect(
      s(up, prepGoal(tDay(5), tournamentId: 'up')),
      TournamentGoalState.linked,
    );
    expect(s(up, prepGoal(tDay(5))), TournamentGoalState.linkOnly);
    // Cùng ngày nhưng nối giải khác còn sống: đó là mục tiêu của giải khác.
    final sameDay = tour('same', start: tDay(5));
    expect(
      tournamentGoalState(
        up,
        goal: prepGoal(tDay(5), tournamentId: 'same'),
        live: [up, sameDay],
        today: tToday,
      ),
      TournamentGoalState.otherGoal,
    );
    // Chuẩn bị giải nhưng khác ngày: mục tiêu khác.
    expect(s(up, prepGoal(tDay(6))), TournamentGoalState.otherGoal);
    // Cùng ngày nhưng sai loại mục tiêu.
    expect(
      s(
        up,
        PlayerGoal(
          goalId: 'g',
          kind: GoalKind.thuanThucKyNang,
          category: SkillCategory.aiming,
          eventDate: tDay(5),
          createdAt: tToday,
        ),
      ),
      TournamentGoalState.otherGoal,
    );
    expect(s(up, null), TournamentGoalState.noGoal);
  });
  test(
    'PlayerGoal so sánh cả tournamentId',
    () => expect(
      prepGoal(tDay(5), tournamentId: 'a') ==
          prepGoal(tDay(5), tournamentId: 'b'),
      isFalse,
    ),
  );
}
