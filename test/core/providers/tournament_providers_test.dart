import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/domain/tournament/tournament_goal.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';
import '../../support/tournament_fixtures.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

ProviderContainer make({
  List<Tournament>? ts,
  List<PoolMatch>? ms,
  GoalRecord? goal,
  AsyncValue<List<Tournament>>? async,
  AsyncValue<GoalRecord?>? goalAsync,
  AsyncValue<List<PoolMatch>>? matchesAsync,
}) {
  final c = testContainer(
    tournaments: ts,
    matches: ms,
    goal: goal,
    tournamentsAsync: async,
    goalAsync: goalAsync,
    matchesAsync: matchesAsync,
    now: tToday,
  );
  addTearDown(c.dispose);
  for (final p in [
    tournamentsByIdProvider,
    tournamentGroupsProvider,
    featuredTournamentProvider,
    tournamentSummariesProvider,
    tournamentComparisonProvider,
    linkedTournamentProvider,
  ]) {
    c.listen(p, (_, _) {});
  }
  c.listen(tournamentViewProvider('on'), (_, _) {});
  c.listen(tournamentGoalStateProvider('up'), (_, _) {});
  return c;
}

final on = tour('on', start: tDay(-1), end: tDay(1));
final up = tour('up', start: tDay(5));

void main() {
  test('nhóm, giải nổi bật, tổng kết và trang giải tính từ dữ liệu', () async {
    final c = make(
      ts: [on, up],
      ms: [
        tMatch('a', tournamentId: 'on'),
        tMatch('b', tournamentId: 'on', won: 1, lost: 3),
      ],
    );
    await settle();
    expect(c.read(featuredTournamentProvider).value, (
      tournament: on,
      status: TournamentStatus.dangDienRa,
      hasAny: true,
    ));
    expect(
      c.read(tournamentStatusProvider('up')).value,
      TournamentStatus.sapToi,
    );
    expect(c.read(tournamentStatusProvider('zz')).value, isNull);
    expect(c.read(tournamentsByIdProvider).value!.keys, {'on', 'up'});
    expect(c.read(tournamentGroupsProvider).value!.sapToi, [up]);
    expect(c.read(tournamentSummariesProvider).value!['on']!.matchesWon, 1);
    expect(
      c.read(tournamentViewProvider('on')).value!.matches.map((m) => m.id),
      ['a', 'b'],
    );
    expect(c.read(tournamentComparisonProvider).value!.enough, isFalse);
  });

  test(
    'mục tiêu nối giải sắp tới: liên kết, trạng thái nút và loại mục tiêu',
    () async {
      final c = make(
        ts: [on, up],
        goal: GoalRecord(
          updatedAt: tToday,
          goal: prepGoal(tDay(5), tournamentId: 'up'),
        ),
      );
      await settle();
      expect(c.read(linkedTournamentProvider).value, up);
      expect(c.read(tournamentGoalStateProvider('up')).value, (
        state: TournamentGoalState.linked,
        currentKind: GoalKind.chuanBiGiai,
      ));
    },
  );

  test('không có mục tiêu: noGoal và loại mục tiêu null', () async {
    final c = make(ts: [up]);
    await settle();
    expect(c.read(tournamentGoalStateProvider('up')).value, (
      state: TournamentGoalState.noGoal,
      currentKind: null,
    ));
  });

  test('id không còn: trạng thái nút là null, không ném', () async {
    final c = make(ts: [on]);
    await settle();
    expect(
      [
        c.read(tournamentGoalStateProvider('up')).hasValue,
        c.read(tournamentGoalStateProvider('up')).value,
      ],
      [true, null],
    );
    expect(c.read(tournamentViewProvider('on')).value, isNotNull);
  });

  test('nguồn giải lỗi: mọi provider thành lỗi, không quay mãi', () async {
    final c = make(
      async: AsyncError<List<Tournament>>(StateError('hỏng'), StackTrace.empty),
    );
    await settle();
    expect(
      [
        c.read(tournamentsByIdProvider).hasError,
        c.read(featuredTournamentProvider).hasError,
        c.read(tournamentComparisonProvider).hasError,
        c.read(linkedTournamentProvider).hasError,
        c.read(tournamentGoalStateProvider('up')).hasError,
        c.read(tournamentStatusProvider('up')).hasError,
      ],
      [true, true, true, true, true, true],
    );
  });

  test('nguồn mục tiêu lỗi: trạng thái nút thành lỗi', () async {
    final c = make(
      ts: [up],
      goalAsync: AsyncError<GoalRecord?>(StateError('hỏng'), StackTrace.empty),
    );
    await settle();
    expect(c.read(tournamentGoalStateProvider('up')).hasError, isTrue);
    expect(c.read(linkedTournamentProvider).hasError, isTrue);
  });

  test(
    'đang tải lại còn giải của người trước: là đang tải, không lộ tên cũ',
    () async {
      // ignore: invalid_use_of_internal_member
      final stale = const AsyncLoading<List<Tournament>>().copyWithPrevious(
        AsyncData<List<Tournament>>([on]),
      );
      final c = make(
        async: stale,
        goal: GoalRecord(
          updatedAt: tToday,
          goal: prepGoal(tDay(-1), tournamentId: 'on'),
        ),
      );
      await settle();
      expect(
        [
          c.read(tournamentsByIdProvider).isLoading,
          c.read(tournamentsByIdProvider).value,
          c.read(featuredTournamentProvider).value,
          c.read(linkedTournamentProvider).value,
          c.read(tournamentStatusProvider('on')).isLoading,
        ],
        [true, null, null, null, true],
      );
    },
  );

  test('đang tải lại còn mục tiêu của người trước: trạng thái nút là đang tải, '
      'không lộ loại cũ', () async {
    // ignore: invalid_use_of_internal_member
    final stale = const AsyncLoading<GoalRecord?>().copyWithPrevious(
      AsyncData<GoalRecord?>(
        GoalRecord(
          updatedAt: tToday,
          goal: prepGoal(tDay(5), tournamentId: 'up'),
        ),
      ),
    );
    final c = make(ts: [up], goalAsync: stale);
    await settle();
    final s = c.read(tournamentGoalStateProvider('up'));
    expect([s.isLoading, s.value], [true, null]);
    expect(c.read(linkedTournamentProvider).value, isNull);
  });

  test(
    'đổi tài khoản: không lộ giải và mục tiêu của tài khoản trước',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await TournamentRepository(
        db,
        userId: 'u1',
        now: () => tToday,
        newId: () => 'u1-giai',
      ).create(TournamentDraft(name: 'Giải của u1', startDate: tDay(5)));
      await RoadmapRepository(
        db,
        userId: 'u1',
        now: () => tToday,
        newId: () => 'g1',
      ).setGoal(
        kind: GoalKind.chuanBiGiai,
        eventDate: tDay(5),
        tournamentId: 'u1-giai',
      );

      final auth = FakeAuthRepository.signedIn(userId: 'u1');
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appDatabaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => tToday),
        ],
      );
      addTearDown(c.dispose);
      c.listen(tournamentsByIdProvider, (_, _) {});
      c.listen(linkedTournamentProvider, (_, _) {});
      c.listen(tournamentGoalStateProvider('u1-giai'), (_, _) {});
      await settle();
      expect(c.read(tournamentsByIdProvider).value!.keys, ['u1-giai']);
      expect(c.read(linkedTournamentProvider).value?.name, 'Giải của u1');
      expect(c.read(tournamentGoalStateProvider('u1-giai')).value, (
        state: TournamentGoalState.linked,
        currentKind: GoalKind.chuanBiGiai,
      ));

      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      await settle();
      expect(c.read(tournamentsByIdProvider).value, isEmpty);
      expect(c.read(linkedTournamentProvider).value, isNull);
      expect(c.read(tournamentGoalStateProvider('u1-giai')).value, isNull);
    },
  );

  test('nguồn trận lỗi: tổng kết, so sánh, trang giải và đầu vào bắt đầu trận '
      'thành lỗi, không quay mãi', () async {
    final c = make(
      ts: [on],
      matchesAsync: AsyncError<List<PoolMatch>>(
        StateError('hỏng'),
        StackTrace.empty,
      ),
    );
    c.listen(startMatchInputsProvider, (_, _) {});
    await settle();
    expect(
      [
        c.read(tournamentSummariesProvider).hasError,
        c.read(tournamentComparisonProvider).hasError,
        c.read(tournamentViewProvider('on')).hasError,
        c.read(startMatchInputsProvider).hasError,
        // Không phụ thuộc trận: vẫn dùng được.
        c.read(tournamentGroupsProvider).hasValue,
      ],
      [true, true, true, true, true],
    );
  });

  test('đang tải lại còn trận của người trước: là đang tải, không lộ tổng kết '
      'cũ', () async {
    // ignore: invalid_use_of_internal_member
    final stale = const AsyncLoading<List<PoolMatch>>().copyWithPrevious(
      AsyncData<List<PoolMatch>>([tMatch('a', tournamentId: 'on')]),
    );
    final c = make(ts: [on], matchesAsync: stale);
    c.listen(startMatchInputsProvider, (_, _) {});
    await settle();
    expect(
      [
        c.read(tournamentSummariesProvider),
        c.read(tournamentComparisonProvider),
        c.read(tournamentViewProvider('on')),
        c.read(startMatchInputsProvider),
      ].map((v) => [v.isLoading, v.value]),
      everyElement([true, null]),
    );
  });

  test(
    'mã giải không có: trang giải là dữ liệu null, không phải lỗi hay tải',
    () async {
      final c = make(ts: [on]);
      c.listen(tournamentViewProvider('missing'), (_, _) {});
      await settle();
      final v = c.read(tournamentViewProvider('missing'));
      expect(
        [v.hasValue, v.isLoading, v.hasError, v.value],
        [true, false, false, null],
      );
    },
  );

  test('mục tiêu cũ còn tournament_id nhưng sai loại: không có liên kết và '
      'trạng thái nút là mục tiêu khác', () async {
    final stale = PlayerGoal(
      goalId: 'g',
      kind: GoalKind.thuanThucKyNang,
      category: SkillCategory.aiming,
      createdAt: tToday,
      tournamentId: 'up',
    );
    final c = make(
      ts: [up],
      goal: GoalRecord(updatedAt: tToday, goal: stale),
    );
    await settle();
    expect(c.read(linkedTournamentProvider).value, isNull);
    expect(c.read(tournamentGoalStateProvider('up')).value, (
      state: TournamentGoalState.otherGoal,
      currentKind: GoalKind.thuanThucKyNang,
    ));
  });

  group('startMatchInputsProvider (qua cổng)', () {
    test('đủ nguồn: cơ, trận và giải', () async {
      final c = make(
        ts: [on, up],
        ms: [tMatch('a', tournamentId: 'on')],
      );
      c.listen(startMatchInputsProvider, (_, _) {});
      await settle();
      final v = c.read(startMatchInputsProvider).value!;
      expect(
        [v.cues, v.matches.map((m) => m.id), v.tournamentsById.keys],
        [
          isEmpty,
          ['a'],
          ['on', 'up'],
        ],
      );
    });

    test(
      'cơ hay trận chưa tới: đang tải, không thay bằng danh sách rỗng',
      () async {
        for (final build in [
          () => testContainer(
            tournaments: [up],
            equipmentStream: StreamController<List<CueEquipment>>().stream,
          ),
          () => testContainer(
            tournaments: [up],
            matchesStream: StreamController<List<PoolMatch>>().stream,
          ),
        ]) {
          final c = build();
          addTearDown(c.dispose);
          c.listen(startMatchInputsProvider, (_, _) {});
          await settle();
          final v = c.read(startMatchInputsProvider);
          expect([v.isLoading, v.value], [true, null]);
        }
      },
    );

    test('nguồn giải lỗi: thành lỗi', () async {
      final c = make(
        async: AsyncError<List<Tournament>>(
          StateError('hỏng'),
          StackTrace.empty,
        ),
      );
      c.listen(startMatchInputsProvider, (_, _) {});
      await settle();
      expect(c.read(startMatchInputsProvider).hasError, isTrue);
    });
  });

  test('chưa đăng nhập: không có repository, danh sách rỗng', () async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const SignedOut()),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(tournamentsProvider, (_, _) {});
    await settle();
    expect(
      [c.read(tournamentRepositoryProvider), c.read(tournamentsProvider).value],
      [null, isEmpty],
    );
  });
}
