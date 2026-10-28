import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/tournament/tournament_lists.dart';
import 'package:poolcoachai/features/play/presentation/tournament_play_card.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/features/play/presentation/tournament_list_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/rich_data.dart';
import '../../support/route_cases.dart';
import '../../support/test_data.dart';
import '../../support/tournament_fixtures.dart';

DateTime day(int n) => DateTime(2026, 9, 22 + n);

Future<GoRouter> openAt(
  WidgetTester tester,
  String path,
  ProviderContainer c,
) async {
  final router = await pumpRoutedApp(tester, container: c);
  router.go(path);
  await tester.pumpAndSettle();
  return router;
}

Future<AppDatabase> openForm(WidgetTester tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await openAt(tester, Routes.tournaments, dbContainer(db));
  await tester.tap(find.byKey(const Key('tournament-add')));
  await tester.pumpAndSettle();
  return db;
}

Future<void> pickDay(WidgetTester tester, Key rowKey, String dayText) async {
  await tester.tap(find.byKey(rowKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(dayText));
  await tester.tap(
    find.text(
      MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)))
          .okButtonLabel,
    ),
  );
  await tester.pumpAndSettle();
}

Finder endRowText() => find.descendant(
  of: find.byKey(const Key('tournament-end')),
  matching: find.text(Vi.tournamentNoEndDate),
);

/// Kho giải mà `create` chờ [release] rồi mới ghi, hoặc ném khi [fail].
class _SlowRepo extends TournamentRepository {
  _SlowRepo(AppDatabase db, {this.fail = false})
    : super(db, userId: 'u1', now: () => testToday, newId: () => 'x');

  final bool fail;
  final release = Completer<void>();

  @override
  Future<String> create(TournamentDraft draft) async {
    if (fail) throw StateError('hỏng');
    await release.future;
    return super.create(draft);
  }
}

void main() {
  testWidgets(
    'Play có thẻ Giải đấu: chưa có giải thì nói thẳng, bấm mở danh sách',
    (tester) async {
      await openAt(tester, Routes.play, testContainer());
      expect(find.text(Vi.tournamentNone), findsOneWidget);
      await tester.tap(find.byKey(const Key('play-tournament-card')));
      await tester.pumpAndSettle();
      expect(find.byType(TournamentListScreen), findsOneWidget);
    },
  );

  testWidgets('thẻ Play: giải đang diễn ra trước giải sắp tới', (tester) async {
    await openAt(
      tester,
      Routes.play,
      testContainer(
        tournaments: [
          Tournament(id: 'u', name: 'Sắp tới', startDate: day(3)),
          Tournament(
            id: 'o',
            name: 'Đang đánh',
            startDate: day(-1),
            endDate: day(1),
          ),
        ],
      ),
    );
    expect(
      [
        find.text('Đang đánh').evaluate().length,
        find.text('Sắp tới').evaluate().length,
      ],
      [1, 0],
    );
  });

  testWidgets('thẻ Play: không có giải đang diễn ra thì giải sắp tới', (
    tester,
  ) async {
    final upcoming = Tournament(id: 'u', name: 'Sắp tới', startDate: day(3));
    await openAt(tester, Routes.play, testContainer(tournaments: [upcoming]));
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(
      find.text(Vi.tournamentStatusDates(TournamentStatus.sapToi, upcoming)),
      findsOneWidget,
    );
  });

  group('thẻ Play dùng giải và trạng thái do provider đưa ra', () {
    final real = DateTime.now();
    final t = Tournament(
      id: 'o',
      name: 'Giải X',
      startDate: DateTime(real.year, real.month, real.day),
    );

    Future<void> pumpCard(
      WidgetTester tester,
      FeaturedTournament featured,
    ) async {
      final c = ProviderContainer(
        overrides: [
          featuredTournamentProvider.overrideWithValue(AsyncData(featured)),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: TournamentPlayCard())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('trạng thái lấy từ provider, không tính lại theo đồng hồ', (
      tester,
    ) async {
      // Ngày thật của giải là "đang diễn ra"; provider nói "sắp tới".
      await pumpCard(tester, (
        tournament: t,
        status: TournamentStatus.sapToi,
        hasAny: true,
      ));
      expect(
        find.text(Vi.tournamentStatusDates(TournamentStatus.sapToi, t)),
        findsOneWidget,
      );
    });

    testWidgets(
      'chỉ có giải đã xong: câu riêng, không phải "Chưa có giải nào"',
      (tester) async {
        await pumpCard(tester, (tournament: null, status: null, hasAny: true));
        expect(find.text(Vi.tournamentNoneActive), findsOneWidget);
        expect(find.text(Vi.tournamentNone), findsNothing);
      },
    );

    testWidgets('không có giải nào: Chưa có giải nào', (tester) async {
      await pumpCard(tester, (tournament: null, status: null, hasAny: false));
      expect(find.text(Vi.tournamentNone), findsOneWidget);
      expect(find.text(Vi.tournamentNoneActive), findsNothing);
    });
  });

  testWidgets('thẻ Play: lỗi dữ liệu giải thì báo lỗi', (tester) async {
    await openAt(
      tester,
      Routes.play,
      testContainer(
        tournamentsAsync: const AsyncError<List<Tournament>>(
          'x',
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text(Vi.tournamentDataError), findsOneWidget);
  });

  testWidgets(
    'ba nhóm theo đúng thứ tự; mỗi giải có ngày, địa điểm, thắng/thua, '
    'thành tích kèm "Kết quả do bạn ghi"',
    (tester) async {
      await openAt(
        tester,
        Routes.tournaments,
        testContainer(
          tournaments: [
            Tournament(
              id: 'x',
              name: 'Xong',
              startDate: day(-30),
              resultNote: 'Vào vòng 16',
            ),
            Tournament(id: 's', name: 'Sắp', startDate: day(4)),
            Tournament(
              id: 'o',
              name: 'Đang',
              startDate: day(0),
              location: 'CLB A',
            ),
          ],
          matches: [
            tMatch('a', tournamentId: 'x', won: 3, lost: 1),
            tMatch('b', tournamentId: 'x', won: 1, lost: 3),
          ],
        ),
      );
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      final dang = Vi.tournamentStatusName(TournamentStatus.dangDienRa);
      final sap = Vi.tournamentStatusName(TournamentStatus.sapToi);
      final xong = Vi.tournamentStatusName(TournamentStatus.daXong);
      expect(y(dang) < y(sap), isTrue);
      expect(y(sap) < y(xong), isTrue);
      expect(find.text('CLB A'), findsOneWidget);
      expect(find.text(Vi.tournamentRecord(1, 1)), findsOneWidget);
      expect(find.text(Vi.tournamentResultLine('Vào vòng 16')), findsOneWidget);
      expect(find.text(Vi.tournamentSelfReported), findsOneWidget);
    },
  );

  testWidgets('giải không có thành tích thì không có dòng "do bạn ghi"', (
    tester,
  ) async {
    await openAt(
      tester,
      Routes.tournaments,
      testContainer(
        tournaments: [Tournament(id: 'o', name: 'Đang', startDate: day(0))],
      ),
    );
    expect(find.text(Vi.tournamentSelfReported), findsNothing);
  });

  testWidgets('không có giải nào: nói thẳng, vẫn có nút thêm', (tester) async {
    await openAt(tester, Routes.tournaments, testContainer());
    expect(find.text(Vi.tournamentListEmpty), findsOneWidget);
    expect(find.byKey(const Key('tournament-add')), findsOneWidget);
  });

  testWidgets('lỗi dữ liệu: màn danh sách báo lỗi', (tester) async {
    await openAt(
      tester,
      Routes.tournaments,
      testContainer(
        tournamentsAsync: const AsyncError<List<Tournament>>(
          'x',
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text(Vi.dataErrorTitle), findsOneWidget);
  });

  testWidgets('so sánh: thiếu trận thì nói cần ít nhất 3 trận mỗi bên', (
    tester,
  ) async {
    await openAt(tester, Routes.tournaments, testContainer());
    expect(find.text(Vi.tournamentCompareNotEnough), findsOneWidget);
  });

  testWidgets('so sánh: đủ mỗi bên thì hiện hai tỷ lệ ván thắng', (
    tester,
  ) async {
    await openAt(
      tester,
      Routes.tournaments,
      testContainer(
        tournaments: [Tournament(id: 'o', name: 'Đang', startDate: testToday)],
        matches: [
          for (var i = 0; i < 3; i++)
            tMatch('in$i', tournamentId: 'o', won: 3, lost: 0),
          for (var i = 0; i < 3; i++) tMatch('re$i', won: 3, lost: 2),
        ],
      ),
    );
    expect(find.text(Vi.tournamentCompare(100, 3, 60, 3)), findsOneWidget);
  });

  testWidgets('bấm giải mở đường dẫn chi tiết', (tester) async {
    final router = await openAt(
      tester,
      Routes.tournaments,
      testContainer(
        tournaments: [Tournament(id: 'o', name: 'Đang', startDate: day(0))],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tournament-o')));
    await tester.pump();
    expect(
      router.routeInformationProvider.value.uri.path,
      Routes.tournament('o'),
    );
  });

  testWidgets(
    'Thêm giải: cắt khoảng trắng, ngày bắt đầu là hôm nay, hiện trong '
    'Đang diễn ra',
    (tester) async {
      final db = await openForm(tester);
      await tester.enterText(
        find.byKey(const Key('tournament-name')),
        '  Giải Quận 1  ',
      );
      await tester.tap(find.text(Vi.tournamentSave));
      await tester.pumpAndSettle();
      final r = await db.select(db.tournamentRows).getSingle();
      expect(
        [r.name, r.startDate, r.endDate],
        ['Giải Quận 1', DateTime(2026, 9, 22), null],
      );
      expect(find.text('Giải Quận 1'), findsOneWidget);
    },
  );

  testWidgets('tên rỗng: báo lỗi, không lưu', (tester) async {
    final db = await openForm(tester);
    await tester.tap(find.text(Vi.tournamentSave));
    await tester.pumpAndSettle();
    expect(
      find.text(Vi.tournamentInputError(TournamentInputError.nameRequired)),
      findsOneWidget,
    );
    expect(await db.select(db.tournamentRows).get(), isEmpty);
  });

  testWidgets('ngày kết thúc trước ngày bắt đầu: báo lỗi, không lưu', (
    tester,
  ) async {
    final db = await openForm(tester);
    await tester.enterText(find.byKey(const Key('tournament-name')), 'Giải');
    await pickDay(tester, const Key('tournament-end'), '21');
    await tester.tap(find.text(Vi.tournamentSave));
    await tester.pumpAndSettle();
    expect(
      find.text(Vi.tournamentInputError(TournamentInputError.endBeforeStart)),
      findsOneWidget,
    );
    expect(await db.select(db.tournamentRows).get(), isEmpty);
  });

  testWidgets('chọn ngày kết thúc rồi bỏ ngày: về "Chưa chọn"', (tester) async {
    await openForm(tester);
    expect(endRowText(), findsOneWidget);
    await pickDay(tester, const Key('tournament-end'), '25');
    expect(find.text(Vi.shortDate(day(3))), findsOneWidget);
    await tester.tap(find.byKey(const Key('tournament-clear-end')));
    await tester.pumpAndSettle();
    expect(endRowText(), findsOneWidget);
  });

  testWidgets('form giải: thứ tự ô theo spec và nhãn "Loại bi"', (
    tester,
  ) async {
    await openForm(tester);
    double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
    final order = [
      'tournament-name',
      'tournament-start',
      'tournament-end',
      'tournament-location',
      'tournament-game-type',
      'tournament-result',
      'tournament-notes',
    ];
    for (var i = 0; i + 1 < order.length; i++) {
      expect(y(order[i]) < y(order[i + 1]), isTrue, reason: order[i]);
    }
    expect(find.text(Vi.tournamentGameType), findsOneWidget);
    expect(Vi.tournamentGameType, startsWith('Loại bi'));
  });

  testWidgets(
    'giới hạn độ dài tính theo ký tự Unicode như bước kiểm tra: tên gõ dấu '
    'tổ hợp vẫn lưu được',
    (tester) async {
      final db = await openForm(tester);
      // 'é' tổ hợp là hai ký tự Unicode nhưng một ký tự hiển thị.
      await tester.enterText(
        find.byKey(const Key('tournament-name')),
        'é' * 80,
      );
      await tester.tap(find.text(Vi.tournamentSave));
      await tester.pumpAndSettle();
      final rows = await db.select(db.tournamentRows).get();
      expect(rows, hasLength(1));
      expect(rows.single.name.runes.length, TournamentConstants.nameMaxLength);
      expect(
        find.text(Vi.tournamentInputError(TournamentInputError.nameTooLong)),
        findsNothing,
      );
    },
  );

  testWidgets('giải chưa có trận hoàn tất: không hiện "Thắng 0 – thua 0"', (
    tester,
  ) async {
    await openAt(
      tester,
      Routes.tournaments,
      testContainer(
        tournaments: [Tournament(id: 'o', name: 'Đang', startDate: day(0))],
        matches: [tMatch('p', tournamentId: 'o', won: 1, lost: 0, target: 3)],
      ),
    );
    expect(find.text('Đang'), findsOneWidget);
    expect(find.text(Vi.tournamentRecord(0, 0)), findsNothing);
  });

  testWidgets('chỉ có một nhóm: các nhóm rỗng không có tiêu đề', (
    tester,
  ) async {
    await openAt(
      tester,
      Routes.tournaments,
      testContainer(
        tournaments: [Tournament(id: 's', name: 'Sắp', startDate: day(4))],
      ),
    );
    expect(
      find.text(Vi.tournamentStatusName(TournamentStatus.sapToi)),
      findsOneWidget,
    );
    expect(
      find.text(Vi.tournamentStatusName(TournamentStatus.dangDienRa)),
      findsNothing,
    );
    expect(
      find.text(Vi.tournamentStatusName(TournamentStatus.daXong)),
      findsNothing,
    );
    expect(find.text(Vi.tournamentListEmpty), findsNothing);
  });

  testWidgets('đang tải giải: vòng quay, chưa có nút thêm', (tester) async {
    final router = await pumpRoutedApp(
      tester,
      container: testContainer(
        tournamentsAsync: const AsyncLoading<List<Tournament>>(),
      ),
    );
    router.go(Routes.tournaments);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('tournament-add')), findsNothing);
  });

  testWidgets(
    'lỗi dữ liệu trận: danh sách vẫn hiện, dòng so sánh báo lỗi dữ liệu giải',
    (tester) async {
      await openAt(
        tester,
        Routes.tournaments,
        testContainer(
          tournaments: [Tournament(id: 'o', name: 'Đang', startDate: day(0))],
          matchesAsync: const AsyncError<List<PoolMatch>>(
            'x',
            StackTrace.empty,
          ),
        ),
      );
      expect(find.text('Đang'), findsOneWidget);
      expect(find.text(Vi.tournamentDataError), findsOneWidget);
      expect(find.byKey(const Key('tournament-compare')), findsNothing);
    },
  );

  testWidgets(
    'lưu đủ các ô: ngày kết thúc, địa điểm, loại bi, thành tích, ghi chú '
    'xuống DB',
    (tester) async {
      final db = await openForm(tester);
      await tester.enterText(
        find.byKey(const Key('tournament-name')),
        'Giải X',
      );
      await pickDay(tester, const Key('tournament-end'), '25');
      await tester.enterText(
        find.byKey(const Key('tournament-location')),
        '  CLB B  ',
      );
      await tester.ensureVisible(find.byKey(const Key('tournament-game-type')));
      await tester.tap(find.byKey(const Key('tournament-game-type')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(Vi.matchGameTypeName(PoolGameType.tenBall)).last,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tournament-result')),
        'Vào vòng 16',
      );
      await tester.enterText(
        find.byKey(const Key('tournament-notes')),
        'Bàn nhanh',
      );
      await tester.tap(find.text(Vi.tournamentSave));
      await tester.pumpAndSettle();
      final r = await db.select(db.tournamentRows).getSingle();
      expect(
        [r.name, r.endDate, r.location, r.gameType, r.resultNote, r.notes],
        [
          'Giải X',
          DateTime(2026, 9, 25),
          'CLB B',
          'tenBall',
          'Vào vòng 16',
          'Bàn nhanh',
        ],
      );
    },
  );

  testWidgets(
    'lưu thất bại: báo lỗi, không có giải mới, nút Thêm giải dùng lại được',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await openAt(
        tester,
        Routes.tournaments,
        dbContainer(db, tournamentRepo: (d) => _SlowRepo(d, fail: true)),
      );
      await tester.tap(find.byKey(const Key('tournament-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tournament-name')),
        'Giải X',
      );
      await tester.tap(find.text(Vi.tournamentSave));
      await tester.pumpAndSettle();
      expect(find.text(Vi.tournamentSaveFailed), findsOneWidget);
      expect(await db.select(db.tournamentRows).get(), isEmpty);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('tournament-add')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('đang lưu: nút Thêm giải tắt, xong thì bật lại', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    late _SlowRepo repo;
    await openAt(
      tester,
      Routes.tournaments,
      dbContainer(db, tournamentRepo: (d) => repo = _SlowRepo(d)),
    );
    await tester.tap(find.byKey(const Key('tournament-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tournament-name')), 'Giải X');
    await tester.tap(find.text(Vi.tournamentSave));
    await tester.pump();
    await tester.pump();
    FilledButton add() =>
        tester.widget<FilledButton>(find.byKey(const Key('tournament-add')));
    expect(add().onPressed, isNull);
    repo.release.complete();
    await tester.pumpAndSettle();
    expect(add().onPressed, isNotNull);
  });

  testWidgets('360×640 chữ lớn 1.5: Play, danh sách và form không tràn', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 1.5);
    final router = await pumpRoutedApp(tester, container: richContainer());
    for (final path in [Routes.play, Routes.tournaments]) {
      router.go(path);
      await tester.pumpAndSettle();
      await scrollThroughAll(tester);
      expect(tester.takeException(), isNull, reason: path);
    }
    await tester.tap(find.byKey(const Key('tournament-add')));
    await tester.pumpAndSettle();
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'điện thoại ngang, bàn phím mở: form giải cuộn được, nút Lưu trên '
    'bàn phím',
    (tester) async {
      applyScreen(tester, const Size(740, 360));
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await openForm(tester);
      await expectDialogFitsAboveKeyboard(
        tester,
        screenHeight: 360,
        keyboard: 160,
      );
      await scrollThroughAll(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
