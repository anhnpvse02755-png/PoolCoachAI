import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/features/rank/presentation/drill_inputs.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: ListView(children: [child])));

void main() {
  testWidgets('Vào / Trượt: hai nút cao ít nhất 48 px, báo đúng kết quả', (tester) async {
    final got = <bool>[];
    await tester.pumpWidget(_host(ShotInput(drillId: 'F1', onShot: got.add)));
    expect(tester.getSize(find.widgetWithText(FilledButton, 'Vào')).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.widgetWithText(OutlinedButton, 'Trượt')).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Vào'));
    await tester.tap(find.text('Trượt'));
    expect(got, [true, false]);
  });

  testWidgets('S5 gọi đúng tên: bắt đui', (tester) async {
    await tester.pumpWidget(_host(ShotInput(drillId: 'S5', onShot: (_) {})));
    expect(find.text(Vi.buShotYes('S5')), findsOneWidget);
    expect(find.text(Vi.buShotNo('S5')), findsOneWidget);
  });

  testWidgets('bộ đếm số bi không xuống dưới 0, không vượt tối đa', (tester) async {
    int? got;
    await tester.pumpWidget(_host(CountInput(max: 4, onSubmit: (n) => got = n)));
    expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip(Vi.buCountLess), matching: find.byType(IconButton))).onPressed, isNull);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip(Vi.buCountMore));
      await tester.pump();
    }
    expect(find.text(Vi.buCountOf(4, 4)), findsOneWidget);
    expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip(Vi.buCountMore), matching: find.byType(IconButton))).onPressed, isNull);
    await tester.tap(find.text(Vi.buCountSubmit));
    expect(got, 4);
  });

  testWidgets('lần phá: b–e khoá khi chưa chọn a; bỏ a thì xoá b–e', (tester) async {
    BreakCriteria? got;
    await tester.pumpWidget(_host(BreakInput(onSubmit: (b) => got = b)));
    CheckboxListTile tile(int i) =>
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, Vi.buBreakCriterion(i)));
    expect(tile(1).onChanged, isNull);
    await tester.tap(find.text(Vi.buBreakCriterion(0)));
    await tester.pump();
    await tester.tap(find.text(Vi.buBreakCriterion(3)));
    await tester.pump();
    await tester.tap(find.text(Vi.buBreakSubmit));
    expect(got, const BreakCriteria(a: true, d: true));

    await tester.tap(find.text(Vi.buBreakCriterion(0)));
    await tester.pump();
    expect(tile(3).value, isFalse);
  });
}
