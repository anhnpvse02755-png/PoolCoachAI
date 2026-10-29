import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_fab_inset.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/features/profile/presentation/equipment_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

void main() {
  /// Mở màn Dụng cụ trên một cơ sở dữ liệu trong bộ nhớ.
  Future<AppDatabase> openEquipment(WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('hộp thoại thêm cơ có đủ ba nhóm nâng cao', (tester) async {
    await openEquipment(tester);
    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    for (final c in [
      SkillCategory.dungCo,
      SkillCategory.nhayBi,
      SkillCategory.matXe,
    ]) {
      expect(
        find.widgetWithText(FilterChip, Vi.skill(c), skipOffstage: false),
        findsOneWidget,
        reason: '$c',
      );
    }
  });

  testWidgets('creates, edits and deletes cue equipment', (tester) async {
    final db = await openEquipment(tester);

    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ thi đấu');
    await tester.enterText(find.byKey(const Key('cue-weight')), '540');
    await tester.enterText(find.byKey(const Key('cue-shaft-diameter')), '12.5');
    await tester.enterText(
      find.byKey(const Key('cue-shaft-brand')),
      'Predator',
    );
    await tester.enterText(find.byKey(const Key('cue-tip-brand')), 'Kamui');
    await tester.enterText(find.byKey(const Key('cue-butt-brand')), 'Cuetec');
    await tester.ensureVisible(find.text(Vi.skill(SkillCategory.aiming)));
    await tester.tap(find.text(Vi.skill(SkillCategory.aiming)));
    await tester.tap(find.text(Vi.equipmentSave));
    await tester.pumpAndSettle();

    var cues = await db.select(db.cueEquipmentRows).get();
    expect(cues, hasLength(1));
    expect(cues.single.userId, 'u1');
    expect(cues.single.weightGrams, 540);
    expect(cues.single.shaftDiameterMm, 12.5);
    expect(cues.single.shaftBrand, 'Predator');
    expect(cues.single.tipBrand, 'Kamui');
    expect(cues.single.buttBrand, 'Cuetec');
    expect(cues.single.skillCategories, '["aiming"]');
    expect(find.text('Cơ thi đấu'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ thi đấu mới');
    await tester.tap(find.text(Vi.equipmentSave));
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.cueEquipmentRows).get()).single.name,
      'Cơ thi đấu mới',
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentDelete).last);
    await tester.pumpAndSettle();
    cues = await db.select(db.cueEquipmentRows).get();
    expect(cues, hasLength(1));
    expect(cues.single.isDeleted, isTrue);
    expect(find.text(Vi.equipmentEmpty), findsOneWidget);
  });

  testWidgets('shows maintenance warning based on user-set due date', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftCueEquipmentRepository(db, userId: 'u1').save(
      CueEquipment(
        id: 'due-cue',
        name: 'Cơ cần bảo dưỡng',
        type: CueType.playing,
        skillCategories: const [],
        lastTipMaintenance: DateTime(2026, 8, 1),
        tipMaintenanceDueDate: DateTime(2026, 9, 21),
      ),
    );
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(Vi.equipmentDue), findsOneWidget);
    expect(find.textContaining('21/09/2026'), findsOneWidget);
  });

  testWidgets('prioritizes overdue cues and sorts upcoming maintenance', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = DriftCueEquipmentRepository(db, userId: 'u1');
    final cues = [
      CueEquipment(
        id: 'overdue',
        name: 'Z - quá hạn',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 21),
      ),
      CueEquipment(
        id: 'today',
        name: 'Y - đến hạn hôm nay',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 22, 23),
      ),
      CueEquipment(
        id: 'seven-days',
        name: 'X - đến hạn sau 7 ngày',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 29),
      ),
      CueEquipment(
        id: 'eight-days',
        name: 'A - đến hạn sau 8 ngày',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 30),
      ),
      const CueEquipment(
        id: 'no-date',
        name: 'B - chưa đặt ngày',
        type: CueType.playing,
        skillCategories: [],
      ),
    ];
    for (final cue in cues) {
      await repository.save(cue);
    }
    // Mỗi thẻ cơ giờ cao hơn (có dòng tỉ lệ thắng): cần màn đủ cao để cả năm
    // thẻ cùng được dựng.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = dbContainer(db, now: testToday);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final orderedNames = [
      'Z - quá hạn',
      'Y - đến hạn hôm nay',
      'X - đến hạn sau 7 ngày',
      'A - đến hạn sau 8 ngày',
      'B - chưa đặt ngày',
    ];
    final positions = orderedNames
        .map((name) => tester.getTopLeft(find.text(name)).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('shows accumulated timer practice for each cue', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final equipmentRepository = DriftCueEquipmentRepository(db, userId: 'u1');
    await equipmentRepository.save(
      const CueEquipment(
        id: 'practice-cue',
        name: 'Cơ tập luyện',
        type: CueType.playing,
        skillCategories: [],
      ),
    );
    final timerRepository = DriftTimerSessionRepository(db, userId: 'u1');
    await timerRepository.add(
      TimerSession(
        id: 'practice-one',
        date: DateTime(2026, 9, 20, 10),
        durationSec: 3600,
        cueId: 'practice-cue',
      ),
    );
    await timerRepository.add(
      TimerSession(
        id: 'practice-two',
        date: DateTime(2026, 9, 21, 10),
        durationSec: 1800,
        cueId: 'practice-cue',
      ),
    );
    await timerRepository.add(
      TimerSession(
        id: 'unlinked',
        date: DateTime(2026, 9, 22, 10),
        durationSec: 7200,
      ),
    );
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('${Vi.equipmentPracticeTime}: 1 giờ 30 phút'),
      findsOneWidget,
    );
    expect(find.text('${Vi.equipmentLastUsed}: 21/09/2026'), findsOneWidget);
  });

  testWidgets('rejects non-finite tip diameter values', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ thử nghiệm');
    await tester.enterText(find.byKey(const Key('cue-shaft-diameter')), 'NaN');
    await tester.tap(find.text(Vi.equipmentSave));
    await tester.pumpAndSettle();

    expect(find.text(Vi.equipmentShaftDiameterInvalid), findsOneWidget);
    expect(await db.select(db.cueEquipmentRows).get(), isEmpty);
  });

  testWidgets('shows win rate and the best-cue verdict on each cue', (
    tester,
  ) async {
    var n = 0;
    PoolMatch match(String cueId, {required bool win}) {
      n++;
      return PoolMatch(
        id: 'm$n',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 1,
        rackWinners: [win ? RackWinner.player : RackWinner.opponent],
        startedAt: DateTime(2026, 9, 1).add(Duration(hours: n)),
        cueId: cueId,
      );
    }

    final container = testContainer(
      equipment: const [
        CueEquipment(
          id: 'a',
          name: 'Cơ A',
          type: CueType.playing,
          skillCategories: [],
        ),
        CueEquipment(
          id: 'b',
          name: 'Cơ B',
          type: CueType.breakJump,
          skillCategories: [],
        ),
      ],
      matches: [
        for (var i = 0; i < 8; i++) match('a', win: true),
        for (var i = 0; i < 2; i++) match('a', win: false),
        for (var i = 0; i < 4; i++) match('b', win: true),
        for (var i = 0; i < 6; i++) match('b', win: false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Vi.cueBestBadge), findsOneWidget);
    expect(
      find.text(Vi.cueWinRateLine(wins: 8, completed: 10, percent: 80)),
      findsOneWidget,
    );
    expect(
      find.text(Vi.cueWinRateLine(wins: 4, completed: 10, percent: 40)),
      findsOneWidget,
    );
  });

  testWidgets('điện thoại ngang, bàn phím mở: hộp thoại cơ cuộn được, '
      'nút Lưu trên bàn phím', (tester) async {
    applyScreen(tester, const Size(740, 360));
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await openEquipment(tester);
    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await expectDialogFitsAboveKeyboard(
      tester,
      screenHeight: 360,
      keyboard: 160,
    );
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('điện thoại ngang: lịch chọn ngày bảo dưỡng không tràn', (
    tester,
  ) async {
    applyScreen(tester, const Size(740, 360));
    await openEquipment(tester);
    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    final pick = find.byTooltip(Vi.equipmentSelectDate).first;
    await tester.ensureVisible(pick);
    await tester.pumpAndSettle();
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('thẻ nhắc bảo dưỡng ở 360x640', () {
    const coachInset = 72.0;

    Future<void> openWithReminder(
      WidgetTester tester, {
      required double textScale,
      int cues = 6,
      bool background = false,
    }) async {
      applyScreen(tester, const Size(360, 640), textScale: textScale);
      final fontBytes = File('test/fixtures/fonts/roboto-regular.ttf')
          .readAsBytesSync();
      await tester.runAsync(
        () => (FontLoader(
          _family,
        )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load(),
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftCueEquipmentRepository(db, userId: 'u1');
      for (var i = 0; i < cues; i++) {
        await repo.save(
          CueEquipment(
            id: 'c$i',
            name: 'Cơ số $i',
            type: CueType.playing,
            skillCategories: const [],
          ),
        );
      }
      final container = dbContainer(
        db,
        extraOverrides: [
          notificationServiceProvider.overrideWith(
            (ref) => NotificationService(
              db: ref.watch(appDatabaseProvider),
              auth: ref.watch(authRepositoryProvider),
              now: ref.watch(nowProvider),
              platform: _PromptPlatform(
                scheduler: background ? _IdleScheduler() : null,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: _family),
            home: const PcFabInset(
              extent: coachInset,
              child: EquipmentScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('x1.5: cột chữ của thẻ không bị bóp từng từ', (tester) async {
      await openWithReminder(tester, textScale: 1.5);
      final textWidth = tester
          .getSize(find.text(Vi.equipmentReminderPrompt(inBackground: false)))
          .width;
      expect(textWidth, greaterThanOrEqualTo(12 * 1.5 * 11));
      expect(tester.takeException(), isNull);
    });

    testWidgets('x1.5: thẻ cuộn cùng danh sách, cơ cuối tới được và nằm '
        'trên nút Coach', (tester) async {
      await openWithReminder(tester, textScale: 1.5);
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      // ListView dựng lười nên cực đại cuộn lớn dần: nhảy tới khi ổn định.
      for (var i = 0; i < 6; i++) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      final last = find.text('Cơ số 5');
      expect(last, findsOneWidget);
      final card = find.ancestor(of: last, matching: find.byType(Card)).first;
      expect(
        tester.getBottomLeft(card).dy,
        lessThanOrEqualTo(640 - coachInset),
      );
      final addFab = find.byType(FloatingActionButton);
      expect(
        tester.getBottomLeft(card).dy,
        lessThanOrEqualTo(tester.getTopLeft(addFab).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('điện thoại (có lịch nền): thẻ nhắc nói vẫn đến khi ứng dụng '
        'đóng, x1.5 đủ chữ không tràn', (tester) async {
      await openWithReminder(tester, textScale: 1.5, background: true);
      expect(
        find.text(Vi.equipmentReminderPrompt(inBackground: true)),
        findsOneWidget,
      );
      expect(find.textContaining('Chỉ hoạt động khi'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('x1.0: nút nằm cùng hàng với chữ như cũ', (tester) async {
      await openWithReminder(tester, textScale: 1.0, cues: 1);
      final text = tester.getRect(find.text(Vi.equipmentReminderPrompt(inBackground: false)));
      final button = tester.getRect(find.text(Vi.equipmentReminderEnable));
      expect(
        button.top,
        lessThan(text.bottom),
        reason: 'nút cùng hàng với chữ',
      );
      expect(button.left, greaterThan(text.left + 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('chưa có cơ: trạng thái trống nằm giữa phần còn lại dưới thẻ, '
        'trên chỗ nút nổi', (tester) async {
      await openWithReminder(tester, textScale: 1.0, cues: 0);
      final card = tester.getRect(find.byType(Card).first);
      final empty = tester.getCenter(find.text(Vi.equipmentEmpty));
      // Vùng còn lại: dưới thẻ tới trên chỗ nút Thêm cơ và nút Coach (88+72).
      final middle = (card.bottom + (640 - 88 - coachInset)) / 2;
      final centreOfBlock = tester.getCenter(find.byType(PcEmptyState)).dy;
      expect(centreOfBlock, closeTo(middle, 6));
      expect(empty.dy, greaterThan(card.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}

const _family = 'RobotoEquipment';

/// Trình duyệt giả: hỗ trợ thông báo, chưa được cấp quyền.
class _PromptPlatform extends NotificationPlatform {
  _PromptPlatform({this.scheduler});

  @override
  final NotificationScheduler? scheduler;

  @override
  bool get isSupported => true;

  @override
  String? get permission => 'default';

  @override
  Future<String?> requestPermission() async => 'granted';
}

/// Bộ đặt lịch giả: chỉ cần có mặt để nền tảng đặt lịch được ở nền.
class _IdleScheduler implements NotificationScheduler {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<Set<int>> pendingIds() async => {};

  @override
  Future<void> schedule(PlannedNotification notification) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  set onTap(void Function(String payload)? handler) {}

  @override
  Future<String?> launchPayload() async => null;
}
