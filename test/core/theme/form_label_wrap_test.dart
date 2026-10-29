import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/features/play/presentation/match_dialogs.dart';
import 'package:poolcoachai/features/play/presentation/tournament_form.dart';
import 'package:poolcoachai/features/training/presentation/drill_session_screen.dart';
import 'package:poolcoachai/features/training/presentation/schedule_screen.dart';
import 'package:poolcoachai/features/training/presentation/timer_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

/// Nhãn ô nhập của các form hiện đủ ở 360x640 x1.5: không có đoạn chữ nào bị
/// cắt còn một dòng rồi thêm dấu ba chấm.
void main() {
  const phone = Size(360, 640);

  /// Chủ đề của app vẽ bằng Roboto thật (font dự phòng của test quá rộng).
  Future<ThemeData> robotoTheme(WidgetTester tester) async {
    const family = 'RobotoFormLabels';
    final bytes = File('test/fixtures/fonts/roboto-regular.ttf')
        .readAsBytesSync();
    await tester.runAsync(
      () => (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
    );
    final base = AppTheme.dark();
    return base.copyWith(textTheme: base.textTheme.apply(fontFamily: family));
  }

  /// Các đoạn chữ đang vẽ mà bị cắt dòng, trừ tiêu đề thanh trên cùng (chữ
  /// tiêu đề thanh trên là vấn đề riêng, không phải nhãn ô nhập).
  List<String> ellipsized(WidgetTester tester) {
    final inAppBar = <RenderObject>{
      for (final e
          in find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(RichText),
              )
              .evaluate())
        e.renderObject!,
    };
    final out = <String>[];
    void visit(RenderObject node) {
      if (node is RenderParagraph &&
          node.didExceedMaxLines &&
          !inAppBar.contains(node)) {
        out.add(node.text.toPlainText());
      }
      node.visitChildren(visit);
    }

    visit(tester.binding.renderViews.first);
    return out;
  }

  testWidgets('form giải đấu: nhãn Địa điểm và các nhãn khác không bị cắt', (
    tester,
  ) async {
    applyScreen(tester, phone, textScale: 1.5);
    await tester.pumpWidget(
      MaterialApp(
        theme: await robotoTheme(tester),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTournamentForm(context, today: DateTime(2026, 9, 22)),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    final location = find.byKey(const Key('tournament-location'));
    await tester.ensureVisible(location);
    await tester.pumpAndSettle();
    expect(find.text(Vi.tournamentLocation), findsOneWidget);
    expect(ellipsized(tester), isEmpty);
    for (final key in [
      'tournament-game-type',
      'tournament-result',
      'tournament-notes',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(ellipsized(tester), isEmpty, reason: key);
    }
  });

  /// Mở [home] trong app dựng bằng Roboto, ở 360x640 x1.5, trên db trong bộ nhớ.
  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    applyScreen(tester, phone, textScale: 1.5);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await upsertSeed(db);
    final container = dbContainer(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: await robotoTheme(tester), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hộp thoại bắt đầu trận: nhãn không bị cắt', (tester) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showStartMatchDialog(
            context,
            cues: const [],
            defaultCueId: null,
            tournaments: [
              Tournament(
                id: 't1',
                name: 'Giải mùa thu',
                startDate: DateTime(2026, 9, 22),
              ),
            ],
          ),
          child: const Text('mở'),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(ellipsized(tester), isEmpty);
    await scrollThroughAll(tester);
    expect(ellipsized(tester), isEmpty);
  });

  testWidgets('hộp thoại thêm buổi tập trong lịch: nhãn không bị cắt', (
    tester,
  ) async {
    await pumpScreen(tester, const ScheduleScreen());
    await tester.tap(find.text(Vi.scheduleAdd));
    await tester.pumpAndSettle();
    expect(ellipsized(tester), isEmpty);
  });

  testWidgets('đồng hồ buổi tập: nhãn không bị cắt', (tester) async {
    await pumpScreen(tester, const TimerScreen());
    expect(ellipsized(tester), isEmpty);
    await scrollThroughAll(tester);
    expect(ellipsized(tester), isEmpty);
  });

  testWidgets('ghi buổi tập bài d1: nhãn không bị cắt', (tester) async {
    await pumpScreen(tester, const DrillSessionScreen(drillId: 'd1'));
    expect(ellipsized(tester), isEmpty);
    await scrollThroughAll(tester);
    expect(ellipsized(tester), isEmpty);
  });
}
