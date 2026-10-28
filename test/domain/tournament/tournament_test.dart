import 'package:flutter_test/flutter_test.dart';
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
  test('giải nổi bật: đang diễn ra (bắt đầu sớm nhất), không thì sắp tới gần nhất, không thì null', () {
    expect(
      featuredTournament([
        ...all,
        tour('on0', start: tDay(-2), end: tDay(0)),
      ], tToday)!.id,
      'on0',
    );
    expect(
      featuredTournament(all.where((t) => t.id != 'on'), tToday)!.id,
      'up1',
    );
    expect(featuredTournament([tour('old', start: tDay(-20))], tToday), isNull);
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
}
