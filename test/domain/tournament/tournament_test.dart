import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/domain/tournament/tournament_lists.dart';

import '../../support/tournament_fixtures.dart';

TournamentDraft draft({
  String name = 'Giải Q1',
  DateTime? start,
  DateTime? end,
  String? location,
  String? result,
  String? notes,
}) => TournamentDraft(
  name: name,
  startDate: start ?? tDay(0),
  endDate: end,
  location: location,
  resultNote: result,
  notes: notes,
);

void main() {
  group('tournamentStatus — tính theo ngày địa phương', () {
    test(
      'trước ngày bắt đầu là sắp tới',
      () => expect(
        tournamentStatus(tour('a', start: tDay(1)), tToday),
        TournamentStatus.sapToi,
      ),
    );
    test('hôm nay là ngày bắt đầu: đang diễn ra từ 00:00 tới 23:59', () {
      final t = tour('a', start: tDay(0));
      expect(
        tournamentStatus(t, DateTime(2026, 10, 28)),
        TournamentStatus.dangDienRa,
      );
      expect(
        tournamentStatus(t, DateTime(2026, 10, 28, 23, 59)),
        TournamentStatus.dangDienRa,
      );
    });
    test(
      'không có ngày kết thúc: ngày hôm sau là đã xong',
      () => expect(
        tournamentStatus(tour('a', start: tDay(-1)), tToday),
        TournamentStatus.daXong,
      ),
    );
    test('hôm nay là ngày kết thúc: vẫn đang diễn ra; hôm sau là đã xong', () {
      final t = tour('a', start: tDay(-2), end: tDay(0));
      expect(tournamentStatus(t, tToday), TournamentStatus.dangDienRa);
      expect(
        tournamentStatus(t, DateTime(2026, 10, 29, 0, 1)),
        TournamentStatus.daXong,
      );
    });
  });

  group('tournamentInputErrors', () {
    test('hợp lệ, kể cả giải ở quá khứ và tên có khoảng trắng hai đầu', () {
      expect(
        tournamentInputErrors(
          draft(name: '  Giải Hà Nội  ', start: tDay(-300)),
        ),
        isEmpty,
      );
      expect(tournamentInputErrors(draft(name: '  ${'x' * 80}  ')), isEmpty);
    });
    test(
      'tên rỗng hoặc chỉ khoảng trắng',
      () => expect(tournamentInputErrors(draft(name: '   ')), {
        TournamentInputError.nameRequired,
      }),
    );
    test(
      'tên 81 ký tự',
      () => expect(tournamentInputErrors(draft(name: 'x' * 81)), {
        TournamentInputError.nameTooLong,
      }),
    );
    test(
      'ngày kết thúc trước ngày bắt đầu; cùng ngày (khác giờ) là hợp lệ',
      () {
        expect(tournamentInputErrors(draft(start: tDay(0), end: tDay(-1))), {
          TournamentInputError.endBeforeStart,
        });
        expect(
          tournamentInputErrors(
            draft(
              start: DateTime(2026, 10, 28, 20),
              end: DateTime(2026, 10, 28, 8),
            ),
          ),
          isEmpty,
        );
      },
    );
    test('địa điểm, thành tích quá 120, ghi chú quá 500; báo đủ mọi lỗi', () {
      expect(
        tournamentInputErrors(
          draft(
            name: '',
            location: 'x' * 121,
            result: 'x' * 121,
            notes: 'x' * 501,
          ),
        ),
        {
          TournamentInputError.nameRequired,
          TournamentInputError.locationTooLong,
          TournamentInputError.resultNoteTooLong,
          TournamentInputError.notesTooLong,
        },
      );
      expect(
        tournamentInputErrors(
          draft(location: 'x' * 120, result: 'x' * 120, notes: 'x' * 500),
        ),
        isEmpty,
      );
    });
  });

  test('trimmedOrNull và roundLabelValid', () {
    expect(
      [trimmedOrNull('  Tứ kết '), trimmedOrNull('   '), trimmedOrNull(null)],
      ['Tứ kết', null, null],
    );
    expect(
      [
        roundLabelValid(null),
        roundLabelValid('x' * 40),
        roundLabelValid(' ${'x' * 40} '),
        roundLabelValid('x' * 41),
      ],
      [true, true, true, false],
    );
  });

  final all = [
    tour('up2', start: tDay(5)),
    tour('up1', start: tDay(2)),
    tour('on', start: tDay(-1), end: tDay(1)),
    tour('old', start: tDay(-20)),
    tour('recent', start: tDay(-5), end: tDay(-3)),
  ];
  test('chia ba nhóm, đúng thứ tự', () {
    final g = groupTournaments(all, tToday);
    expect(g.dangDienRa.map((t) => t.id), ['on']);
    expect(g.sapToi.map((t) => t.id), ['up1', 'up2']);
    expect(g.daXong.map((t) => t.id), ['recent', 'old']);
  });
  test('giải nổi bật: đang diễn ra (bắt đầu sớm nhất), không thì sắp tới gần nhất, không thì null — kèm đúng trạng thái', () {
    final first = featuredTournament([
      ...all,
      tour('on0', start: tDay(-2), end: tDay(0)),
    ], tToday);
    expect(
      [first.tournament!.id, first.status, first.hasAny],
      ['on0', TournamentStatus.dangDienRa, true],
    );
    final second = featuredTournament(all.where((t) => t.id != 'on'), tToday);
    expect(
      [second.tournament!.id, second.status],
      ['up1', TournamentStatus.sapToi],
    );
  });
  test('giải nổi bật: chỉ có giải đã xong thì không có giải nào nổi bật nhưng hasAny là true; không có giải nào thì hasAny là false', () {
    final onlyDone = featuredTournament([
      tour('old', start: tDay(-20)),
    ], tToday);
    expect(
      [onlyDone.tournament, onlyDone.status, onlyDone.hasAny],
      [isNull, isNull, true],
    );
    final none = featuredTournament(const <Tournament>[], tToday);
    expect(
      [none.tournament, none.status, none.hasAny],
      [isNull, isNull, false],
    );
  });
  group('pickableForNewMatch — biên 7 ngày', () {
    test('đã bắt đầu và kết thúc trong 7 ngày gần đây, mới nhất trước', () {
      final ts = [
        tour('end7', start: tDay(-9), end: tDay(-7)),
        tour('end8', start: tDay(-9), end: tDay(-8)),
        tour('noEnd7', start: tDay(-7)),
        tour('noEnd8', start: tDay(-8)),
        tour('today', start: tDay(0)),
        tour('tomorrow', start: tDay(1)),
      ];
      expect(pickableForNewMatch(ts, tToday).map((t) => t.id), [
        'today',
        'noEnd7',
        'end7',
      ]);
    });
    test(
      'include thêm giải cũ được chọn sẵn, không trùng, id lạ bị bỏ qua',
      () {
        expect(
          pickableForNewMatch(all, tToday, include: 'old').map((t) => t.id),
          ['on', 'recent', 'old'],
        );
        expect(
          pickableForNewMatch(all, tToday, include: 'on').map((t) => t.id),
          ['on', 'recent'],
        );
        expect(
          pickableForNewMatch(all, tToday, include: 'zz').map((t) => t.id),
          ['on', 'recent'],
        );
      },
    );
  });
  test(
    'pickableForEdit: mọi giải, mới nhất trước',
    () => expect(pickableForEdit(all).map((t) => t.id), [
      'up2',
      'up1',
      'on',
      'recent',
      'old',
    ]),
  );

  group('độ dài tính theo ký tự Unicode và khoảng trắng', () {
    test('80 ký tự ngoài BMP hợp lệ, 81 là nameTooLong', () {
      expect(tournamentInputErrors(draft(name: '😀' * 80)), isEmpty);
      expect(tournamentInputErrors(draft(name: '😀' * 81)), {
        TournamentInputError.nameTooLong,
      });
    });
    test('chữ tuỳ chọn đúng giới hạn, có khoảng trắng quanh, vẫn hợp lệ', () {
      expect(
        tournamentInputErrors(
          draft(
            location: '  ${'a' * 120}  ',
            result: ' ${'b' * 120} ',
            notes: '\n${'c' * 500}\n',
          ),
        ),
        isEmpty,
      );
      expect(
        tournamentInputErrors(
          draft(location: 'a' * 121, result: 'b' * 121, notes: 'c' * 501),
        ),
        {
          TournamentInputError.locationTooLong,
          TournamentInputError.resultNoteTooLong,
          TournamentInputError.notesTooLong,
        },
      );
    });
    test('chữ tuỳ chọn chỉ có khoảng trắng được chấp nhận', () {
      expect(
        tournamentInputErrors(
          draft(location: '   ', result: ' ', notes: '\n\t'),
        ),
        isEmpty,
      );
    });
  });
  group('Tournament ==/hashCode', () {
    Tournament base({
      String id = 'a',
      String name = 'n',
      DateTime? start,
      DateTime? end,
      String? location,
      PoolGameType? gameType,
      String? resultNote,
      String? notes,
    }) => Tournament(
      id: id,
      name: name,
      startDate: start ?? tDay(0),
      endDate: end,
      location: location,
      gameType: gameType,
      resultNote: resultNote,
      notes: notes,
    );
    test('trường giống hệt thì bằng nhau và cùng hashCode', () {
      expect(base(), base());
      expect(base().hashCode, base().hashCode);
    });
    test('khác đúng một trường thì khác', () {
      final others = [
        base(id: 'b'),
        base(name: 'm'),
        base(start: tDay(1)),
        base(end: tDay(2)),
        base(location: 'x'),
        base(gameType: PoolGameType.nineBall),
        base(resultNote: 'x'),
        base(notes: 'x'),
      ];
      for (final o in others) {
        expect(o == base(), isFalse);
        expect(o.hashCode == base().hashCode, isFalse);
      }
    });
  });
}
