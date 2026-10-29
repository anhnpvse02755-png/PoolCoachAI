import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';
import 'package:poolcoachai/features/profile/presentation/equipment_screen.dart';

import '../../support/fake_auth.dart';
import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

/// Chữ lỗi và nhãn ô nhập hiện đủ khi chữ hệ thống phóng 1.5 lần: không bị
/// cắt còn một dòng rồi thêm dấu ba chấm.
void main() {
  const phone = Size(360, 640);

  bool truncated(WidgetTester tester, Finder finder) {
    final paragraph = tester.renderObject<RenderParagraph>(finder.first);
    return paragraph.didExceedMaxLines;
  }

  /// Chủ đề của app nhưng vẽ bằng Roboto thật, để đo độ rộng chữ gần với máy
  /// thật (font dự phòng của test rộng 1 em mỗi chữ, quá rộng để đo cắt dòng).
  Future<ThemeData> robotoTheme(WidgetTester tester) async {
    const family = 'RobotoInputWrap';
    final bytes = File('test/fixtures/fonts/roboto-regular.ttf').readAsBytesSync();
    await tester.runAsync(
      () => (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
    );
    final base = AppTheme.dark();
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: family),
    );
  }

  testWidgets('theme: lỗi ô nhập dài hiện đủ ở x1.5, không cắt', (tester) async {
    applyScreen(tester, phone, textScale: 1.5);
    final theme = await robotoTheme(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                errorText: Vi.shotScoreError(ShotScoreError.aboveShots),
                helperText: Vi.sessionScoreHintRange(40),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final error = find.text(Vi.shotScoreError(ShotScoreError.aboveShots));
    expect(truncated(tester, error), isFalse);
  });

  testWidgets('lỗi ô nhập số cú của bài BU hiện đủ ở x1.5', (tester) async {
    applyScreen(tester, phone, textScale: 1.5);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await upsertSeed(db);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => DateTime(2026, 9, 22, 10)),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      ],
    );
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.drillSession('d11'));
    await tester.pumpAndSettle();

    final shots = drillProvenanceOf('d11')!.shots;
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionScoreLabelTarget),
      '${shots + 1}',
    );
    await tester.ensureVisible(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    final error = find.text(Vi.shotScoreError(ShotScoreError.aboveShots));
    expect(error, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(error);
    expect(paragraph.maxLines, greaterThanOrEqualTo(3));
  });

  testWidgets('nhãn Size ngọn của form cơ hiện đủ ở x1.5', (tester) async {
    applyScreen(tester, phone, textScale: 1.5);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: await robotoTheme(tester),
          home: const EquipmentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cue-shaft-diameter')));
    await tester.pumpAndSettle();

    final label = find.text(Vi.equipmentShaftDiameter);
    expect(label, findsOneWidget);
    expect(truncated(tester, label), isFalse);
    // Nhãn hai dòng nằm trọn trong khung ô nhập, không tràn ra ngoài.
    final field = tester.getRect(find.byKey(const Key('cue-shaft-diameter')));
    final labelRect = tester.getRect(label);
    expect(field.top <= labelRect.top && labelRect.bottom <= field.bottom, isTrue,
        reason: 'nhãn $labelRect lệch khỏi ô $field');
  });

  testWidgets('nhãn Size ngọn đã nổi lên (có giá trị) vẫn hiện đủ, không đè giá trị',
      (tester) async {
    applyScreen(tester, phone, textScale: 1.5);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: await robotoTheme(tester),
          home: const EquipmentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cue-shaft-diameter')));
    await tester.enterText(find.byKey(const Key('cue-shaft-diameter')), '12.5');
    await tester.pumpAndSettle();

    final label = find.text(Vi.equipmentShaftDiameter);
    expect(truncated(tester, label), isFalse);
    final field = tester.getRect(find.byKey(const Key('cue-shaft-diameter')));
    final labelRect = tester.getRect(label);
    final value = tester.getRect(find.descendant(
      of: find.byKey(const Key('cue-shaft-diameter')),
      matching: find.byType(EditableText),
    ));
    expect(field.top <= labelRect.top && labelRect.bottom <= field.bottom, isTrue,
        reason: 'nhãn nổi $labelRect lệch khỏi ô $field');
    expect(labelRect.bottom <= value.top + 1, isTrue,
        reason: 'nhãn nổi $labelRect đè giá trị $value');
  });
}
