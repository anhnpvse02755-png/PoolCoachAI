import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/features/play/presentation/tournament_form.dart';

import '../../support/layout_sweep.dart';

/// Nhãn ô nhập của các form hiện đủ ở 360x640 x1.5: không có đoạn chữ nào bị
/// cắt còn một dòng rồi thêm dấu ba chấm.
void main() {
  const phone = Size(360, 640);

  /// Chủ đề của app vẽ bằng Roboto thật (font dự phòng của test quá rộng).
  Future<ThemeData> robotoTheme(WidgetTester tester) async {
    const family = 'RobotoFormLabels';
    final bytes = File(
      'test/fixtures/fonts/roboto-regular.ttf',
    ).readAsBytesSync();
    await tester.runAsync(
      () => (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
    );
    final base = AppTheme.dark();
    return base.copyWith(textTheme: base.textTheme.apply(fontFamily: family));
  }

  /// Các đoạn chữ đang vẽ mà bị cắt dòng.
  List<String> ellipsized(WidgetTester tester) {
    final out = <String>[];
    void visit(RenderObject node) {
      if (node is RenderParagraph && node.didExceedMaxLines) {
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
    for (final key in ['tournament-game-type', 'tournament-result', 'tournament-notes']) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(ellipsized(tester), isEmpty, reason: key);
    }
  });
}
