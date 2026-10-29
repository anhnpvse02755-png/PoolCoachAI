import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_rebuild_at.dart';

/// Đưa app ra nền rồi quay lại, đi đủ các bước như hệ điều hành báo.
void _backgroundThenResume(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  final start = DateTime(2026, 10, 14, 7, 59);
  late DateTime clock;
  late List<DateTime> due;

  setUp(() {
    clock = start;
    due = [];
  });

  /// Hiện số mục trong [due] đã tới giờ, như chuông và hộp "Đã gửi".
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: PcRebuildAt(
        clock: () => clock,
        nextAt: (now) {
          DateTime? next;
          for (final at in due) {
            if (at.isAfter(now) && (next == null || at.isBefore(next))) {
              next = at;
            }
          }
          return next;
        },
        builder: (_) =>
            Text('${due.where((at) => !at.isAfter(clock)).length}'),
      ),
    ),
  );

  testWidgets('tới giờ thì dựng lại', (tester) async {
    due = [start.add(const Duration(minutes: 1))];
    await pump(tester);
    expect(find.text('0'), findsOneWidget);

    clock = start.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tới giờ thì đặt tiếp giờ kế tiếp', (tester) async {
    due = [
      start.add(const Duration(minutes: 1)),
      start.add(const Duration(minutes: 3)),
    ];
    await pump(tester);
    clock = start.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('1'), findsOneWidget);

    clock = start.add(const Duration(minutes: 4));
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('2'), findsOneWidget);
  });

  // Máy ngủ thì timer đứng: giờ trôi qua mà timer chưa chạy.
  testWidgets('máy ngủ qua giờ: quay lại app thì dựng lại ngay', (
    tester,
  ) async {
    due = [start.add(const Duration(minutes: 1))];
    await pump(tester);
    expect(find.text('0'), findsOneWidget);

    clock = start.add(const Duration(hours: 1));
    _backgroundThenResume(tester);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('quay lại app trước giờ: đặt lại timer theo đồng hồ mới', (
    tester,
  ) async {
    due = [start.add(const Duration(minutes: 30))];
    await pump(tester);

    // Ngủ 20 phút: timer cũ (30 phút) đứng yên. Quay lại thì còn 10 phút.
    clock = start.add(const Duration(minutes: 20));
    _backgroundThenResume(tester);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    clock = start.add(const Duration(minutes: 31));
    await tester.pump(const Duration(minutes: 11));
    expect(find.text('1'), findsOneWidget);
  });
}
