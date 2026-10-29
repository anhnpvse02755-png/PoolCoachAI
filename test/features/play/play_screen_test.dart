import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/match_repository.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/rich_data.dart';
import '../../support/test_data.dart';

/// Repository giả luôn báo lỗi khi sửa hoặc xóa trận, để kiểm tra thông
/// báo lỗi hiển thị đúng cho từng hành động (không dùng chung thông báo
/// ghi kết quả).
class _FailingMatchRepository implements MatchRepository {
  _FailingMatchRepository(this.match);

  final PoolMatch match;

  @override
  Stream<List<PoolMatch>> watchAll() => Stream.value([match]);

  @override
  Future<void> updateDetails({
    required String matchId,
    required PoolGameType gameType,
    required String playerName,
    required String opponentName,
    required int targetRacks,
    required String? tournamentId,
    required String? roundLabel,
  }) => Future.error(StateError('lỗi giả lập khi sửa trận'));

  @override
  Future<void> remove(String matchId) =>
      Future.error(StateError('lỗi giả lập khi xóa trận'));

  @override
  Future<void> start(PoolMatch match) => throw UnimplementedError();

  @override
  Future<void> recordRack(String matchId, RackWinner winner) =>
      throw UnimplementedError();

  @override
  Future<void> undoLastRack(String matchId) => throw UnimplementedError();

  @override
  Future<void> recordShot(String matchId, MatchShot shot) =>
      throw UnimplementedError();

  @override
  Future<void> undoLastShot(String matchId) => throw UnimplementedError();
}

void main() {
  testWidgets('starts a race, records racks and can correct the last rack', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchStart));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
    await tester.enterText(
      find.byKey(const Key('match-opponent-name')),
      'Bình',
    );
    await tester.tap(find.text(Vi.matchStartAction));
    await tester.pumpAndSettle();

    var matches = await db.select(db.poolMatchRows).get();
    expect(matches, hasLength(1));
    expect(matches.single.userId, 'u1');
    expect(matches.single.gameType, PoolGameType.nineBall.name);
    expect(find.text(Vi.matchScore('An', 0, 0, 'Bình')), findsOneWidget);

    await tester.tap(find.text(Vi.matchRecordShot));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-shot-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchSafetyShot).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-shot-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchShotScratch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-position-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchPositionUnsuccessful).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('match-shot-notes')),
      'Bi cái rơi lỗ',
    );
    await tester.tap(find.text(Vi.matchSaveShot));
    await tester.pumpAndSettle();
    matches = await db.select(db.poolMatchRows).get();
    expect(matches.single.shots, contains('safety'));
    expect(matches.single.shots, contains('scratch'));
    expect(matches.single.shots, contains('unsuccessful'));
    expect(matches.single.shots, contains('Bi cái rơi lỗ'));
    expect(matches.single.shots, contains('rackNumber'));
    expect(find.text(Vi.matchShotCount(1)), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(Vi.matchPlayerWinsRack));
      await tester.pumpAndSettle();
    }
    expect(find.text(Vi.matchScore('An', 5, 0, 'Bình')), findsOneWidget);
    expect(find.text(Vi.matchCompleted), findsOneWidget);

    await tester.tap(find.text(Vi.matchUndoRack));
    await tester.pumpAndSettle();
    expect(find.text(Vi.matchScore('An', 4, 0, 'Bình')), findsOneWidget);
    expect(find.text(Vi.matchInProgress), findsOneWidget);
    matches = await db.select(db.poolMatchRows).get();
    expect(matches.single.completedAt, isNull);
    expect(matches.single.shots, contains('safety'));
  });

  testWidgets('shows an empty state when there is no match history', (
    tester,
  ) async {
    final container = testContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Vi.matchEmpty), findsOneWidget);
    expect(find.text(Vi.matchStart), findsOneWidget);
  });

  testWidgets('requires confirmation before deleting a match', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);
    final repository = DriftMatchRepository(db, userId: 'u1');
    await repository.start(
      PoolMatch(
        id: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 3,
        rackWinners: const [],
        startedAt: DateTime(2026, 10, 20, 10),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-match-m1')));
    await tester.pumpAndSettle();

    expect(find.text(Vi.matchDeleteTitle), findsOneWidget);
    expect(await db.select(db.poolMatchRows).get(), hasLength(1));
    await tester.tap(find.text(Vi.cancel));
    await tester.pumpAndSettle();
    expect(await db.select(db.poolMatchRows).get(), hasLength(1));

    await tester.tap(find.byKey(const Key('delete-match-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchDeleteConfirm));
    await tester.pumpAndSettle();
    // Xóa mềm: dòng ở lại làm tombstone, nhưng màn hình không còn thấy nó.
    expect((await db.select(db.poolMatchRows).get()).single.isDeleted, isTrue);
    expect(find.byKey(const Key('delete-match-m1')), findsNothing);
  });

  testWidgets('edits match details without removing recorded rack results', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);
    final repository = DriftMatchRepository(db, userId: 'u1');
    await repository.start(
      PoolMatch(
        id: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 3,
        rackWinners: const [],
        startedAt: DateTime(2026, 10, 20, 10),
      ),
    );
    await repository.recordRack('m1', RackWinner.player);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-match-m1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit-match-player-name')),
      'An mới',
    );
    await tester.enterText(
      find.byKey(const Key('edit-match-opponent-name')),
      'Bình mới',
    );
    await tester.tap(find.byKey(const Key('edit-match-game-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchEightBall).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchSaveDetails));
    await tester.pumpAndSettle();

    final match = (await db.select(db.poolMatchRows).get()).single;
    expect(match.gameType, PoolGameType.eightBall.name);
    expect(match.playerName, 'An mới');
    expect(match.opponentName, 'Bình mới');
    expect(match.rackWinners, contains('player'));
    expect(
      find.text(Vi.matchScore('An mới', 1, 0, 'Bình mới')),
      findsOneWidget,
    );
  });

  testWidgets(
    'điện thoại dọc, chữ lớn: không vỡ layout với tên dài và nút sửa/xóa',
    (tester) async {
      applyScreen(tester, const Size(360, 640), textScale: 2.0);
      final container = richContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await scrollThroughAll(tester);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the edit-failed message when saving details throws', (
    tester,
  ) async {
    final match = PoolMatch(
      id: 'm1',
      gameType: PoolGameType.nineBall,
      playerName: 'An',
      opponentName: 'Bình',
      targetRacks: 5,
      rackWinners: const [],
      startedAt: DateTime(2026, 10, 20, 10),
    );
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(
          _FailingMatchRepository(match),
        ),
        cueEquipmentProvider.overrideWith(
          (ref) => Stream.value(const <CueEquipment>[]),
        ),
        tournamentsProvider.overrideWith(
          (ref) => Stream.value(const <Tournament>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-match-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchSaveDetails));
    await tester.pumpAndSettle();

    expect(find.text(Vi.matchEditFailed), findsOneWidget);
    expect(find.text(Vi.matchRecordFailed), findsNothing);
  });

  testWidgets('shows the delete-failed message when removing throws', (
    tester,
  ) async {
    final match = PoolMatch(
      id: 'm1',
      gameType: PoolGameType.nineBall,
      playerName: 'An',
      opponentName: 'Bình',
      targetRacks: 5,
      rackWinners: const [],
      startedAt: DateTime(2026, 10, 20, 10),
    );
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(
          _FailingMatchRepository(match),
        ),
        cueEquipmentProvider.overrideWith(
          (ref) => Stream.value(const <CueEquipment>[]),
        ),
        tournamentsProvider.overrideWith(
          (ref) => Stream.value(const <Tournament>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-match-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.text(Vi.matchDeleteFailed), findsOneWidget);
    expect(find.text(Vi.matchRecordFailed), findsNothing);
  });

  testWidgets(
    'blocks lowering the target below the leader\'s wins with an inline '
    'error',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = dbContainer(db);
      addTearDown(container.dispose);
      final repository = DriftMatchRepository(db, userId: 'u1');
      await repository.start(
        PoolMatch(
          id: 'm1',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 9,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 20, 10),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await repository.recordRack('m1', RackWinner.player);
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-match-m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-match-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.matchRaceTo(3)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.matchSaveDetails));
      await tester.pumpAndSettle();

      expect(find.text(Vi.matchTargetBelowLeader(5)), findsOneWidget);
      expect(find.text(Vi.matchEditTitle), findsOneWidget);
      final match = (await db.select(db.poolMatchRows).get()).single;
      expect(match.targetRacks, 9);
    },
  );

  group('cue picker', () {
    late AppDatabase db;
    late ProviderContainer container;
    final at = DateTime(2026, 10, 20, 9);

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = dbContainer(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> addCue(String id, String name) =>
        DriftCueEquipmentRepository(db, userId: 'u1', now: () => at).save(
          CueEquipment(
            id: id,
            name: name,
            type: CueType.playing,
            skillCategories: const [],
          ),
        );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> startWithNames(WidgetTester tester) async {
      await tester.tap(find.text(Vi.matchStart));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
      await tester.enterText(
        find.byKey(const Key('match-opponent-name')),
        'Bình',
      );
    }

    testWidgets(
      'điện thoại ngang, bàn phím mở: hộp thoại bắt đầu trận cuộn được, '
      'nút Bắt đầu trên bàn phím',
      (tester) async {
        applyScreen(tester, const Size(740, 360));
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await addCue('c1', 'Cơ Một');
        await pump(tester);
        await tester.tap(find.text(Vi.matchStart));
        await tester.pumpAndSettle();
        await expectDialogFitsAboveKeyboard(
          tester,
          screenHeight: 360,
          keyboard: 160,
        );
        await scrollThroughAll(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'điện thoại ngang, bàn phím mở: hộp thoại ghi cú đánh cuộn được, '
      'nút Lưu trên bàn phím',
      (tester) async {
        // Tạo trận ở cỡ mặc định như test đầu file, rồi mới xoay ngang.
        await pump(tester);
        await startWithNames(tester);
        await tester.tap(find.text(Vi.matchStartAction));
        await tester.pumpAndSettle();
        // Nút mở hộp thoại nằm dưới vùng bàn phím: mở trước, bàn phím
        // bật lên sau, như khi chạm vào ô ghi chú.
        applyScreen(tester, const Size(740, 360));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(Vi.matchRecordShot));
        await tester.pumpAndSettle();
        await tester.tap(find.text(Vi.matchRecordShot));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await expectDialogFitsAboveKeyboard(
          tester,
          screenHeight: 360,
          keyboard: 160,
        );
        await scrollThroughAll(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('defaults to no cue and lets the player pick one', (
      tester,
    ) async {
      await addCue('c1', 'Cơ Một');
      await addCue('c2', 'Cơ Hai');
      await pump(tester);
      await startWithNames(tester);

      expect(find.text(Vi.timerNoCue), findsOneWidget);
      await tester.tap(find.byKey(const Key('match-cue')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cơ Một'), findsOneWidget);
      await tester.tap(find.textContaining('Cơ Hai').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();

      expect((await db.select(db.poolMatchRows).get()).single.cueId, 'c2');
    });

    testWidgets('defaults to the cue of the most recent match', (tester) async {
      await addCue('c1', 'Cơ Một');
      await addCue('c2', 'Cơ Hai');
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => at);
      await repository.start(
        PoolMatch(
          id: 'old',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 1),
          cueId: 'c1',
        ),
      );
      await repository.start(
        PoolMatch(
          id: 'recent',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 10),
          cueId: 'c2',
        ),
      );
      await pump(tester);
      await startWithNames(tester);

      expect(find.textContaining('Cơ Hai'), findsWidgets);
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();

      final created = (await db.select(db.poolMatchRows).get()).where(
        (row) => row.id != 'old' && row.id != 'recent',
      );
      expect(created.single.cueId, 'c2');
    });

    testWidgets('a deleted cue shows as unknown on the match card', (
      tester,
    ) async {
      await addCue('c1', 'Cơ Một');
      await DriftMatchRepository(db, userId: 'u1', now: () => at).start(
        PoolMatch(
          id: 'm1',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 10),
          cueId: 'c1',
        ),
      );
      await pump(tester);
      expect(find.text(Vi.matchCueLine('Cơ Một')), findsOneWidget);

      await DriftCueEquipmentRepository(
        db,
        userId: 'u1',
        now: () => at,
      ).remove('c1');
      await tester.pumpAndSettle();

      expect(
        find.text(Vi.matchCueLine(Vi.equipmentUnknownCue)),
        findsOneWidget,
      );
      expect((await db.select(db.poolMatchRows).get()).single.cueId, 'c1');
    });
  });

  group('giải đấu trong form trận', () {
    late AppDatabase db;
    late ProviderContainer container;
    const longName =
        'Giải Vô địch Bida Pool 9 bi Mở rộng Thành phố Hồ Chí Minh lần thứ XII';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = dbContainer(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> addTournament(
      String id,
      String name, {
      required DateTime start,
      DateTime? end,
      PoolGameType? gameType,
    }) =>
        TournamentRepository(
          db,
          userId: 'u1',
          now: () => testToday,
          newId: () => id,
        ).create(
          TournamentDraft(
            name: name,
            startDate: start,
            endDate: end,
            gameType: gameType,
          ),
        );

    Future<void> pumpPlay(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openStart(WidgetTester tester) async {
      await pumpPlay(tester);
      await tester.tap(find.text(Vi.matchStart));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
      await tester.enterText(
        find.byKey(const Key('match-opponent-name')),
        'Bình',
      );
    }

    Future<void> pick(WidgetTester tester, Key field, String item) async {
      await tester.ensureVisible(find.byKey(field));
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    Future<void> startMatchIn(String id, {String? tournamentId}) =>
        DriftMatchRepository(db, userId: 'u1', now: () => testToday).start(
          PoolMatch(
            id: id,
            gameType: PoolGameType.nineBall,
            playerName: 'An',
            opponentName: 'Bình',
            targetRacks: 3,
            rackWinners: const [],
            startedAt: testToday,
            tournamentId: tournamentId,
            roundLabel: tournamentId == null ? null : 'Tứ kết',
          ),
        );

    testWidgets(
      'chọn giải và vòng gợi ý: lưu vào trận, thẻ hiện tên giải và vòng',
      (tester) async {
        await addTournament('t1', 'Giải Q1', start: testToday);
        await openStart(tester);
        expect(find.byKey(const Key('match-round')), findsNothing);
        await pick(tester, const Key('match-tournament'), 'Giải Q1');
        await tester.ensureVisible(find.byKey(const Key('match-round-2')));
        await tester.tap(find.byKey(const Key('match-round-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(Vi.matchStartAction));
        await tester.pumpAndSettle();
        final r = await db.select(db.poolMatchRows).getSingle();
        expect([r.tournamentId, r.roundLabel], ['t1', 'Tứ kết']);
        expect(
          find.text(Vi.matchTournamentLabel('Giải Q1', 'Tứ kết')),
          findsOneWidget,
        );
      },
    );

    testWidgets('chỉ giải đã bắt đầu và kết thúc trong 7 ngày gần đây', (
      tester,
    ) async {
      await addTournament(
        'up',
        'Giải ngày mai',
        start: testToday.add(const Duration(days: 1)),
      );
      await addTournament(
        'e8',
        'Xong 8 ngày',
        start: testToday.subtract(const Duration(days: 8)),
      );
      await addTournament(
        'e7',
        'Xong 7 ngày',
        start: testToday.subtract(const Duration(days: 7)),
      );
      await openStart(tester);
      await tester.tap(find.byKey(const Key('match-tournament')));
      await tester.pumpAndSettle();
      expect(
        [
          find.text('Xong 7 ngày').evaluate().isEmpty,
          find.text('Xong 8 ngày').evaluate().isEmpty,
          // Thẻ Giải đấu trên Play đã nêu giải sắp tới này đúng một lần;
          // trong danh sách chọn nó không được xuất hiện thêm.
          find.text('Giải ngày mai').evaluate().length == 1,
        ],
        [false, true, true],
      );
    });

    testWidgets('không có giải chọn được thì không có ô Giải đấu', (
      tester,
    ) async {
      await openStart(tester);
      expect(find.byKey(const Key('match-tournament')), findsNothing);
    });

    testWidgets('chọn giải có loại bi thì điền sẵn loại bi', (tester) async {
      await addTournament(
        't1',
        'Giải 10 bi',
        start: testToday,
        gameType: PoolGameType.tenBall,
      );
      await openStart(tester);
      await pick(tester, const Key('match-tournament'), 'Giải 10 bi');
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();
      expect(
        (await db.select(db.poolMatchRows).getSingle()).gameType,
        'tenBall',
      );
    });

    testWidgets('sửa trận: chuyển sang giải khác rồi bỏ giải', (tester) async {
      await addTournament('t1', 'Giải Một', start: testToday);
      await addTournament('t2', 'Giải Hai', start: testToday);
      await startMatchIn('m1', tournamentId: 't1');
      await pumpPlay(tester);
      expect(
        find.text(Vi.matchTournamentLabel('Giải Một', 'Tứ kết')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('edit-match-m1')));
      await tester.pumpAndSettle();
      await pick(tester, const Key('edit-match-tournament'), 'Giải Hai');
      await tester.tap(find.text(Vi.matchSaveDetails));
      await tester.pumpAndSettle();
      var r = await db.select(db.poolMatchRows).getSingle();
      expect([r.tournamentId, r.roundLabel], ['t2', 'Tứ kết']);

      await tester.tap(find.byKey(const Key('edit-match-m1')));
      await tester.pumpAndSettle();
      await pick(
        tester,
        const Key('edit-match-tournament'),
        Vi.matchNoTournament,
      );
      expect(find.byKey(const Key('edit-match-round')), findsNothing);
      await tester.tap(find.text(Vi.matchSaveDetails));
      await tester.pumpAndSettle();
      r = await db.select(db.poolMatchRows).getSingle();
      expect([r.tournamentId, r.roundLabel], [null, null]);
    });

    testWidgets(
      'trận của giải đã xóa: hiện như trận thường, sửa không lỗi và vẫn giữ '
      'tournament_id',
      (tester) async {
        await addTournament('gone', 'Giải đã xóa', start: testToday);
        await startMatchIn('m1', tournamentId: 'gone');
        await TournamentRepository(
          db,
          userId: 'u1',
          now: () => testToday,
          newId: () => 'x',
        ).remove('gone');
        await pumpPlay(tester);
        expect(find.textContaining('Giải đã xóa'), findsNothing);
        await tester.tap(find.byKey(const Key('edit-match-m1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const Key('edit-match-opponent-name')),
          'Cường',
        );
        await tester.tap(find.text(Vi.matchSaveDetails));
        await tester.pumpAndSettle();
        final r = await db.select(db.poolMatchRows).getSingle();
        expect(
          [r.opponentName, r.tournamentId, r.roundLabel],
          ['Cường', 'gone', 'Tứ kết'],
        );
      },
    );

    testWidgets(
      'bỏ giải ở form bắt đầu xóa luôn vòng đã gõ; chọn giải lại thì ô vòng trống',
      (tester) async {
        await addTournament('t1', 'Giải Q1', start: testToday);
        await openStart(tester);
        await pick(tester, const Key('match-tournament'), 'Giải Q1');
        await tester.enterText(find.byKey(const Key('match-round')), 'Vòng 3');
        await pick(tester, const Key('match-tournament'), Vi.matchNoTournament);
        expect(find.byKey(const Key('match-round')), findsNothing);
        await pick(tester, const Key('match-tournament'), 'Giải Q1');
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('match-round')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.tap(find.text(Vi.matchStartAction));
        await tester.pumpAndSettle();
        final r = await db.select(db.poolMatchRows).getSingle();
        expect([r.tournamentId, r.roundLabel], ['t1', null]);
      },
    );

    testWidgets(
      'sửa trận: bỏ giải rồi chọn lại giải thì ô vòng trống, không sống lại '
      'vòng cũ',
      (tester) async {
        await addTournament('t1', 'Giải Một', start: testToday);
        await startMatchIn('m1', tournamentId: 't1');
        await pumpPlay(tester);
        await tester.tap(find.byKey(const Key('edit-match-m1')));
        await tester.pumpAndSettle();
        await pick(
          tester,
          const Key('edit-match-tournament'),
          Vi.matchNoTournament,
        );
        await pick(tester, const Key('edit-match-tournament'), 'Giải Một');
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('edit-match-round')))
              .controller!
              .text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'sửa trận của giải đã xóa: ô giải hiện "Không thuộc giải nào", không có '
      'ô vòng; chạm rồi chọn lại "không giải" thì xóa cả giải lẫn vòng',
      (tester) async {
        await addTournament('gone', 'Giải đã xóa', start: testToday);
        await addTournament('live', 'Giải còn', start: testToday);
        await startMatchIn('m1', tournamentId: 'gone');
        await TournamentRepository(
          db,
          userId: 'u1',
          now: () => testToday,
          newId: () => 'x',
        ).remove('gone');
        await pumpPlay(tester);
        await tester.tap(find.byKey(const Key('edit-match-m1')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('edit-match-tournament')),
            matching: find.text(Vi.matchNoTournament),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('edit-match-round')), findsNothing);
        await pick(tester, const Key('edit-match-tournament'), 'Giải còn');
        await pick(
          tester,
          const Key('edit-match-tournament'),
          Vi.matchNoTournament,
        );
        await tester.tap(find.text(Vi.matchSaveDetails));
        await tester.pumpAndSettle();
        final r = await db.select(db.poolMatchRows).getSingle();
        expect([r.tournamentId, r.roundLabel], [null, null]);
      },
    );

    testWidgets(
      'tên giải dài: ô đã chọn một dòng có dấu ba chấm, danh sách chọn tới hai dòng',
      (tester) async {
        await addTournament('t1', longName, start: testToday);
        await openStart(tester);
        await pick(tester, const Key('match-tournament'), longName);
        Text shown() => tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('match-tournament')),
            matching: find.text(longName),
          ),
        );
        expect(shown().maxLines, 1);
        expect(shown().overflow, TextOverflow.ellipsis);
        await tester.tap(find.byKey(const Key('match-tournament')));
        await tester.pumpAndSettle();
        final menu = tester.widget<Text>(find.text(longName).last);
        expect(menu.maxLines, 2);
      },
    );

    testWidgets(
      'điện thoại dọc, chữ 1.5: hộp thoại bắt đầu trận có giải không tràn, '
      'cuộn tới mọi ô',
      (tester) async {
        applyScreen(tester, const Size(360, 640), textScale: 1.5);
        await addTournament('t1', longName, start: testToday);
        await openStart(tester);
        await pick(tester, const Key('match-tournament'), longName);
        await expectDialogFitsAboveKeyboard(
          tester,
          screenHeight: 640,
          keyboard: 0,
        );
        expect(find.byKey(const Key('match-round')), findsOneWidget);
      },
    );

    testWidgets(
      'điện thoại dọc, chữ 1.5: hộp thoại sửa trận có giải không tràn, '
      'cuộn tới mọi ô',
      (tester) async {
        applyScreen(tester, const Size(360, 640), textScale: 1.5);
        await addTournament('t1', longName, start: testToday);
        await startMatchIn('m1', tournamentId: 't1');
        await pumpPlay(tester);
        await tester.ensureVisible(find.byKey(const Key('edit-match-m1')));
        await tester.tap(find.byKey(const Key('edit-match-m1')));
        await tester.pumpAndSettle();
        await expectDialogFitsAboveKeyboard(
          tester,
          screenHeight: 640,
          keyboard: 0,
        );
        expect(find.byKey(const Key('edit-match-round')), findsOneWidget);
      },
    );

    testWidgets(
      'điện thoại ngang, bàn phím mở: hộp thoại có ô giải và vòng cuộn được, '
      'nút Bắt đầu trên bàn phím',
      (tester) async {
        await addTournament('t1', longName, start: testToday);
        await openStart(tester);
        await pick(tester, const Key('match-tournament'), longName);
        applyScreen(tester, const Size(740, 360));
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await expectDialogFitsAboveKeyboard(
          tester,
          screenHeight: 360,
          keyboard: 160,
        );
        await scrollThroughAll(tester);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
