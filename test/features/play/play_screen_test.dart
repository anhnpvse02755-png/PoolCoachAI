import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/match_repository.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
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
    expect(find.text(Vi.matchScore('An mới', 1, 0, 'Bình mới')), findsOneWidget);
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
}
