import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/features/play/presentation/match_analysis_sheet.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/play/presentation/tournament_detail_screen.dart';
import 'package:poolcoachai/features/play/presentation/tournament_list_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/rich_data.dart';
import '../../support/route_cases.dart';
import '../../support/test_data.dart';

final on = Tournament(
  id: 'on',
  name: 'Giải Q1',
  startDate: DateTime(2026, 9, 21),
  endDate: DateTime(2026, 9, 23),
  location: 'CLB A',
  gameType: PoolGameType.tenBall,
  resultNote: 'Vào vòng 16',
  notes: 'Bàn nhanh',
);
final up = Tournament(
  id: 'up',
  name: 'Cúp Mùa Đông',
  startDate: DateTime(2026, 10, 2),
);

PoolMatch m(
  String id, {
  required int won,
  required int lost,
  int? target,
  required DateTime at,
  String? round,
}) => PoolMatch(
  id: id,
  gameType: PoolGameType.tenBall,
  playerName: 'An',
  opponentName: 'Đối thủ $id',
  targetRacks: target ?? (won > lost ? won : lost),
  rackWinners: [
    for (var i = 0; i < won; i++) RackWinner.player,
    for (var i = 0; i < lost; i++) RackWinner.opponent,
  ],
  startedAt: at,
  completedAt: (target == null) ? at.add(const Duration(hours: 1)) : null,
  tournamentId: 'on',
  roundLabel: round,
);

Future<GoRouter> open(
  WidgetTester tester,
  ProviderContainer container,
  String id,
) async {
  final router = await pumpRoutedApp(tester, container: container);
  router.go(Routes.tournament(id));
  await tester.pumpAndSettle();
  return router;
}

TournamentRepository tRepo(AppDatabase db, [String id = 'x']) =>
    TournamentRepository(
      db,
      userId: 'u1',
      now: () => testToday,
      newId: () => id,
    );

RoadmapRepository gRepo(AppDatabase db) =>
    RoadmapRepository(db, userId: 'u1', now: () => testToday, newId: () => 'g');

class _LaggyRepo extends TournamentRepository {
  _LaggyRepo(super.db, {required super.userId, required super.now})
    : super(newId: () => 'x');

  @override
  Future<void> remove(String id) async {
    await super.remove(id);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Kho giải mà ghi/sửa/xóa luôn ném.
class _FailingTournamentRepo extends TournamentRepository {
  _FailingTournamentRepo(super.db)
    : super(userId: 'u1', now: () => testToday, newId: () => 'x');

  @override
  Future<void> update(String id, TournamentDraft draft) =>
      Future.error(StateError('hỏng'));

  @override
  Future<void> remove(String id) => Future.error(StateError('hỏng'));
}

class _FailingGoalRepo extends RoadmapRepository {
  _FailingGoalRepo(super.db)
    : super(userId: 'u1', now: () => testToday, newId: () => 'g');

  @override
  Future<void> setGoal({
    required GoalKind kind,
    SkillCategory? category,
    DateTime? eventDate,
    Rank? targetRank,
    String? tournamentId,
  }) => Future.error(StateError('hỏng'));

  @override
  Future<void> linkTournament(String tournamentId) =>
      Future.error(StateError('hỏng'));
}

class _FailingStartRepo extends DriftMatchRepository {
  _FailingStartRepo(super.db) : super(userId: 'u1');

  @override
  Future<void> start(PoolMatch match) => Future.error(StateError('hỏng'));
}

Future<AppDatabase> newDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<void> createUp(AppDatabase db) => tRepo(db, 'up').create(
  TournamentDraft(name: 'Cúp Mùa Đông', startDate: DateTime(2026, 10, 2)),
);

void main() {
  testWidgets(
    'thông tin: ngày, địa điểm, loại bi, trạng thái, thành tích kèm nhãn '
    'tự ghi, ghi chú',
    (tester) async {
      await open(tester, testContainer(tournaments: [on]), 'on');
      for (final s in [
        'Giải Q1',
        Vi.tournamentStatusDates(TournamentStatus.dangDienRa, on),
        'CLB A',
        Vi.matchGameTypeName(PoolGameType.tenBall),
        Vi.tournamentResultLine('Vào vòng 16'),
        Vi.tournamentSelfReported,
        'Bàn nhanh',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    },
  );

  testWidgets('không ghi thành tích thì không có nhãn tự ghi', (tester) async {
    await open(tester, testContainer(tournaments: [up]), 'up');
    expect(find.text(Vi.tournamentSelfReported), findsNothing);
  });

  testWidgets('tổng kết và các trận tính từ trận đã ghi, theo giờ bắt đầu', (
    tester,
  ) async {
    applyScreen(tester, const Size(800, 2400));
    await open(
      tester,
      testContainer(
        tournaments: [on],
        matches: [
          m(
            'b',
            won: 1,
            lost: 3,
            at: DateTime(2026, 9, 22, 9),
            round: 'Bán kết',
          ),
          m(
            'a',
            won: 3,
            lost: 2,
            at: DateTime(2026, 9, 21, 9),
            round: 'Tứ kết',
          ),
          m('c', won: 1, lost: 0, target: 3, at: DateTime(2026, 9, 22, 10)),
        ],
      ),
      'on',
    );
    expect(find.text(Vi.tournamentRecord(1, 1)), findsOneWidget);
    expect(find.text(Vi.tournamentRacks(4, 5)), findsOneWidget);
    expect(find.text(Vi.tournamentRackRate(44)), findsOneWidget);
    double y(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('tournament-match-$id'))).dy;
    expect(y('a') < y('b') && y('b') < y('c'), isTrue);
    expect(
      find.text(Vi.tournamentMatchTitle('Tứ kết', 'Đối thủ a')),
      findsOneWidget,
    );
    expect(find.text(Vi.tournamentAnalysisTitle), findsOneWidget);
  });

  testWidgets('chưa có trận hoàn tất: nói thẳng', (tester) async {
    await open(tester, testContainer(tournaments: [on]), 'on');
    expect(find.text(Vi.tournamentSummaryEmpty), findsOneWidget);
    expect(find.text(Vi.tournamentMatchesEmpty), findsOneWidget);
  });

  testWidgets('giải sắp tới chưa có trận: có tiêu đề Các trận, chữ rỗng cỡ thân',
      (tester) async {
    await open(tester, testContainer(tournaments: [up]), 'up');
    final title = find.text(Vi.tournamentMatchesTitle);
    final empty = find.text(Vi.tournamentMatchesEmpty);
    expect(title, findsOneWidget);
    expect(empty, findsOneWidget);
    expect(
      tester.getTopLeft(title).dy < tester.getTopLeft(empty).dy,
      isTrue,
      reason: 'tiêu đề nằm trên chữ rỗng',
    );
    // Kiểu hiệu lực (đã gộp với kiểu kế thừa) phải đúng bodyMedium của theme.
    final effective = (tester.renderObject<RenderParagraph>(empty).text
            as TextSpan)
        .style!;
    final body = Theme.of(tester.element(empty)).textTheme.bodyMedium!;
    expect(
      [effective.fontSize, effective.fontWeight, effective.fontFamily],
      [body.fontSize, body.fontWeight, body.fontFamily],
    );
  });

  testWidgets('bấm trận đã xong mở phân tích trận', (tester) async {
    await open(
      tester,
      testContainer(
        tournaments: [on],
        matches: [m('a', won: 3, lost: 2, at: DateTime(2026, 9, 21, 9))],
      ),
      'on',
    );
    await tester.tap(find.byKey(const ValueKey('tournament-match-a')));
    await tester.pumpAndSettle();
    expect(find.byType(MatchAnalysisView), findsOneWidget);
  });

  testWidgets('phân tích trận mở trên navigator gốc: nút Coach nằm sau tấm chắn', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640));
    await open(
      tester,
      testContainer(
        tournaments: [on],
        matches: [m('a', won: 3, lost: 2, at: DateTime(2026, 9, 21, 9))],
      ),
      'on',
    );
    expect(find.byTooltip(Vi.coachTitle).hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('tournament-match-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament-match-a')));
    await tester.pumpAndSettle();
    expect(find.byType(MatchAnalysisView), findsOneWidget);
    expect(find.byTooltip(Vi.coachTitle).hitTestable(), findsNothing);
  });

  testWidgets('bấm trận đang đánh sang Thi đấu', (tester) async {
    await open(
      tester,
      testContainer(
        tournaments: [on],
        matches: [
          m('c', won: 1, lost: 0, target: 3, at: DateTime(2026, 9, 22, 10)),
        ],
      ),
      'on',
    );
    expect(find.text(Vi.matchInProgress), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tournament-match-c')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('giải sắp tới không có nút bắt đầu trận', (tester) async {
    await open(tester, testContainer(tournaments: [up]), 'up');
    expect(find.byKey(const Key('tournament-start-match')), findsNothing);
    expect(find.byKey(const Key('tournament-prepare')), findsOneWidget);
  });

  testWidgets('giải đang diễn ra không có nút Chuẩn bị', (tester) async {
    await open(tester, testContainer(tournaments: [on]), 'on');
    expect(find.byKey(const Key('tournament-prepare')), findsNothing);
    expect(find.byKey(const Key('tournament-start-match')), findsOneWidget);
  });

  testWidgets(
    'trạng thái hiển thị lấy từ provider, không tự tính lại theo đồng hồ',
    (tester) async {
      // Ngày thật của giải "on" là đã xong; provider ép "sắp tới".
      await open(
        tester,
        testContainer(
          tournaments: [on],
          forcedTournamentStatus: {'on': TournamentStatus.sapToi},
        ),
        'on',
      );
      expect(
        find.text(Vi.tournamentStatusDates(TournamentStatus.sapToi, on)),
        findsOneWidget,
      );
      // Cùng một trạng thái quyết định nút: sắp tới thì chưa có Bắt đầu trận.
      expect(find.byKey(const Key('tournament-start-match')), findsNothing);
    },
  );

  testWidgets(
    'cơ chưa tải xong: nút Bắt đầu trận tắt, không mở hộp thoại với danh sách '
    'cơ rỗng; có cơ rồi thì bật',
    (tester) async {
      final cues = StreamController<List<CueEquipment>>();
      addTearDown(cues.close);
      await open(
        tester,
        testContainer(tournaments: [on], equipmentStream: cues.stream),
        'on',
      );
      final button = find.byKey(const Key('tournament-start-match'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(Vi.matchStartAction), findsNothing);
      cues.add(const <CueEquipment>[]);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(Vi.matchStartAction), findsOneWidget);
    },
  );

  testWidgets(
    'bắt đầu trận ở giải đã xong 20 ngày: chọn sẵn giải, loại bi theo giải, '
    'lưu rồi sang Thi đấu',
    (tester) async {
      final db = await newDb();
      await tRepo(db, 'old').create(
        TournamentDraft(
          name: 'Giải cũ',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 2),
          gameType: PoolGameType.tenBall,
        ),
      );
      await open(tester, dbContainer(db), 'old');
      await tester.tap(find.byKey(const Key('tournament-start-match')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
      await tester.enterText(
        find.byKey(const Key('match-opponent-name')),
        'Bình',
      );
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();
      final r = await db.select(db.poolMatchRows).getSingle();
      expect([r.tournamentId, r.gameType], ['old', 'tenBall']);
      expect(find.byType(PlayScreen), findsOneWidget);
    },
  );

  testWidgets(
    'chưa có mục tiêu: Chuẩn bị cho giải này đặt mục tiêu nối giải; Lộ trình '
    'có tên giải',
    (tester) async {
      final db = await newDb();
      await createUp(db);
      await open(tester, dbContainer(db), 'up');
      await tester.tap(find.byKey(const Key('tournament-prepare')));
      await tester.pumpAndSettle();
      final g = await db.select(db.playerGoalRows).getSingle();
      expect(
        [g.kind, g.eventDate, g.tournamentId],
        ['chuanBiGiai', DateTime(2026, 10, 2), 'up'],
      );
      expect(find.text(Vi.tournamentPreparing), findsOneWidget);
      await tester.tap(find.byKey(const Key('tournament-open-roadmap')));
      await tester.pumpAndSettle();
      expect(
        find.text('Chuẩn bị giải Cúp Mùa Đông — ngày 02/10/2026'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'đang có mục tiêu khác: hỏi trước; Giữ mục tiêu cũ thì không đổi, Đổi '
    'mục tiêu thì thay',
    (tester) async {
      final db = await newDb();
      await createUp(db);
      await gRepo(
        db,
      ).setGoal(kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming);
      await open(tester, dbContainer(db), 'up');
      await tester.tap(find.byKey(const Key('tournament-prepare')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          Vi.tournamentReplaceGoalBody(Vi.goalKind(GoalKind.thuanThucKyNang)),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(Vi.goalCancelChange));
      await tester.pumpAndSettle();
      var g = await db.select(db.playerGoalRows).getSingle();
      expect(g.kind, 'thuanThucKyNang');
      await tester.tap(find.byKey(const Key('tournament-prepare')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.goalChange));
      await tester.pumpAndSettle();
      g = await db.select(db.playerGoalRows).getSingle();
      expect([g.kind, g.tournamentId], ['chuanBiGiai', 'up']);
    },
  );

  testWidgets(
    'đổi ngày bắt đầu khi mục tiêu đang nối: mục tiêu đi theo, vẫn đang chuẩn '
    'bị, Lộ trình hiện ngày mới kèm tên giải',
    (tester) async {
      final db = await newDb();
      await createUp(db);
      await gRepo(db).setGoal(
        kind: GoalKind.chuanBiGiai,
        eventDate: DateTime(2026, 10, 2),
        tournamentId: 'up',
      );
      final router = await open(tester, dbContainer(db), 'up');
      expect(find.text(Vi.tournamentPreparing), findsOneWidget);
      await tRepo(db).update(
        'up',
        TournamentDraft(name: 'Cúp Mùa Đông', startDate: DateTime(2026, 10, 3)),
      );
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentPreparing), findsOneWidget);
      expect(find.byKey(const Key('tournament-prepare')), findsNothing);
      router.go(Routes.roadmap);
      await tester.pumpAndSettle();
      expect(
        find.text('Chuẩn bị giải Cúp Mùa Đông — ngày 03/10/2026'),
        findsOneWidget,
      );
    },
  );

  testWidgets('đổi tên giải đang nối: tiêu đề Lộ trình đổi theo tên mới', (
    tester,
  ) async {
    final db = await newDb();
    await createUp(db);
    await gRepo(db).setGoal(
      kind: GoalKind.chuanBiGiai,
      eventDate: DateTime(2026, 10, 2),
      tournamentId: 'up',
    );
    final router = await open(tester, dbContainer(db), 'up');
    await tRepo(db).update(
      'up',
      TournamentDraft(name: 'Cúp Xuân', startDate: DateTime(2026, 10, 2)),
    );
    await tester.pumpAndSettle();
    router.go(Routes.roadmap);
    await tester.pumpAndSettle();
    expect(
      find.text('Chuẩn bị giải Cúp Xuân — ngày 02/10/2026'),
      findsOneWidget,
    );
    expect(find.textContaining('Cúp Mùa Đông'), findsNothing);
  });

  testWidgets(
    'mục tiêu Chuẩn bị giải đúng ngày nhưng chưa nối: bấm Chuẩn bị chỉ gắn '
    'giải, không hỏi, không đặt lại mục tiêu',
    (tester) async {
      final db = await newDb();
      await createUp(db);
      await gRepo(
        db,
      ).setGoal(kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 10, 2));
      final before = await db.select(db.playerGoalRows).getSingle();
      await open(tester, dbContainer(db), 'up');
      await tester.tap(find.byKey(const Key('tournament-prepare')));
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentReplaceGoalTitle), findsNothing);
      final g = await db.select(db.playerGoalRows).getSingle();
      expect(
        [g.goalId, g.createdAt, g.tournamentId, g.eventDate],
        [before.goalId, before.createdAt, 'up', DateTime(2026, 10, 2)],
      );
      expect(find.text(Vi.tournamentPreparing), findsOneWidget);
    },
  );

  testWidgets('xóa giải: hỏi trước, xóa mềm, về danh sách', (tester) async {
    final db = await newDb();
    await createUp(db);
    await open(tester, dbContainer(db), 'up');
    await tester.tap(find.byKey(const Key('tournament-delete')));
    await tester.pumpAndSettle();
    expect(find.text(Vi.tournamentDeleteTitle), findsOneWidget);
    await tester.tap(find.text(Vi.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(TournamentListScreen), findsNothing);
    expect((await db.select(db.tournamentRows).getSingle()).isDeleted, isFalse);
    await tester.tap(find.byKey(const Key('tournament-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.tournamentDeleteConfirm));
    await tester.pumpAndSettle();
    expect((await db.select(db.tournamentRows).getSingle()).isDeleted, isTrue);
    expect(find.byType(TournamentListScreen), findsOneWidget);
  });

  testWidgets(
    'xóa giải: không có khung hình nào hiện "không tìm thấy" trước khi về danh sách',
    (tester) async {
      final db = await newDb();
      await createUp(db);
      // Kho ghi xong rồi mới trả về chậm: luồng dữ liệu báo "giải đã mất"
      // trước khi màn kịp rời đi.
      await open(
        tester,
        dbContainer(
          db,
          tournamentRepo: (d) =>
              _LaggyRepo(d, userId: 'u1', now: () => testToday),
        ),
        'up',
      );
      await tester.tap(find.byKey(const Key('tournament-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.tournamentDeleteConfirm));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 5));
        expect(find.text(Vi.tournamentNotFoundTitle), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentNotFoundTitle), findsNothing);
      expect(find.byType(TournamentListScreen), findsOneWidget);
    },
  );

  testWidgets(
    'sửa giải từ màn chi tiết: form có sẵn giá trị, bỏ ngày kết thúc rồi lưu '
    'thì end_date là null',
    (tester) async {
      final db = await newDb();
      await tRepo(db, 'on').create(
        TournamentDraft(
          name: 'Giải Q1',
          startDate: DateTime(2026, 9, 21),
          endDate: DateTime(2026, 9, 23),
          location: 'CLB A',
        ),
      );
      await open(tester, dbContainer(db), 'on');
      await tester.tap(find.byKey(const Key('tournament-edit')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('tournament-name')))
            .controller!
            .text,
        'Giải Q1',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('tournament-location')))
            .controller!
            .text,
        'CLB A',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tournament-end')),
          matching: find.text('23/09/2026'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('tournament-clear-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.tournamentSave));
      await tester.pumpAndSettle();
      final row = await db.select(db.tournamentRows).getSingle();
      expect(row.endDate, isNull);
      expect(row.name, 'Giải Q1');
      expect(row.location, 'CLB A');
    },
  );

  group('thất bại: báo lỗi, ở lại màn, nút dùng lại được', () {
    FilledButton? filled(WidgetTester tester, String key) =>
        tester.widgetList<FilledButton>(find.byKey(Key(key))).firstOrNull;

    testWidgets('bắt đầu trận lỗi: thông báo, vẫn ở chi tiết giải', (
      tester,
    ) async {
      final db = await newDb();
      await tRepo(
        db,
        'on',
      ).create(TournamentDraft(name: 'Giải Q1', startDate: testToday));
      await open(
        tester,
        dbContainer(db, matchRepo: _FailingStartRepo.new),
        'on',
      );
      await tester.tap(find.byKey(const Key('tournament-start-match')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
      await tester.enterText(
        find.byKey(const Key('match-opponent-name')),
        'Bình',
      );
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();
      expect(find.text(Vi.matchStartFailed), findsOneWidget);
      expect(find.byType(TournamentDetailScreen), findsOneWidget);
      expect(find.byType(PlayScreen), findsNothing);
      expect(filled(tester, 'tournament-start-match')!.onPressed, isNotNull);
      expect(await db.select(db.poolMatchRows).get(), isEmpty);
    });

    testWidgets('đặt mục tiêu lỗi: thông báo, nút Chuẩn bị còn đó', (
      tester,
    ) async {
      final db = await newDb();
      await createUp(db);
      await open(
        tester,
        dbContainer(db, roadmapRepo: _FailingGoalRepo.new),
        'up',
      );
      await tester.tap(find.byKey(const Key('tournament-prepare')));
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentGoalFailed), findsOneWidget);
      expect(find.text(Vi.tournamentPreparing), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('tournament-prepare')))
            .onPressed,
        isNotNull,
      );
      expect(await db.select(db.playerGoalRows).get(), isEmpty);
    });

    testWidgets(
      'xóa lỗi: thông báo, giải còn nguyên, không hiện "không tìm thấy"',
      (tester) async {
        final db = await newDb();
        await createUp(db);
        await open(
          tester,
          dbContainer(db, tournamentRepo: _FailingTournamentRepo.new),
          'up',
        );
        await tester.tap(find.byKey(const Key('tournament-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(Vi.tournamentDeleteConfirm));
        await tester.pumpAndSettle();
        expect(find.text(Vi.tournamentDeleteFailed), findsOneWidget);
        expect(find.text(Vi.tournamentNotFoundTitle), findsNothing);
        expect(find.text('Cúp Mùa Đông'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('tournament-delete')))
              .onPressed,
          isNotNull,
        );
        expect(
          (await db.select(db.tournamentRows).getSingle()).isDeleted,
          isFalse,
        );
      },
    );

    testWidgets('sửa lỗi: thông báo, dữ liệu cũ còn nguyên', (tester) async {
      final db = await newDb();
      await createUp(db);
      await open(
        tester,
        dbContainer(db, tournamentRepo: _FailingTournamentRepo.new),
        'up',
      );
      await tester.tap(find.byKey(const Key('tournament-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tournament-name')),
        'Tên mới',
      );
      await tester.tap(find.text(Vi.tournamentSave));
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentSaveFailed), findsOneWidget);
      expect(find.text('Cúp Mùa Đông'), findsOneWidget);
      expect(
        (await db.select(db.tournamentRows).getSingle()).name,
        'Cúp Mùa Đông',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('tournament-edit')))
            .onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('id không còn: màn không tìm thấy, có nút về danh sách', (
    tester,
  ) async {
    await open(tester, testContainer(), 'zz');
    expect(find.text(Vi.tournamentNotFoundTitle), findsOneWidget);
    await tester.tap(find.text(Vi.tournamentBackToList));
    await tester.pumpAndSettle();
    expect(find.byType(TournamentListScreen), findsOneWidget);
  });

  group('360x640, chữ 1.5 (ứng dụng chặn ở mức này): không tràn', () {
    testWidgets('giải đang diễn ra: trận, phân tích, nút bắt đầu', (
      tester,
    ) async {
      applyScreen(tester, const Size(360, 640), textScale: 1.5);
      final router = await pumpRoutedApp(tester, container: richContainer());
      router.go(Routes.tournament('t1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('tournament-start-match')),
        200,
      );
      await tester.pump();
      await scrollThroughAll(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('giải sắp tới: nút Chuẩn bị, rồi đang chuẩn bị', (
      tester,
    ) async {
      applyScreen(tester, const Size(360, 640), textScale: 1.5);
      final db = await newDb();
      await createUp(db);
      final router = await pumpRoutedApp(tester, container: dbContainer(db));
      router.go(Routes.tournament('up'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tournament-prepare')), findsOneWidget);
      await scrollThroughAll(tester);
      expect(tester.takeException(), isNull);
      await gRepo(db).setGoal(
        kind: GoalKind.chuanBiGiai,
        eventDate: DateTime(2026, 10, 2),
        tournamentId: 'up',
      );
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentPreparing), findsOneWidget);
      await scrollThroughAll(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
