# Responsive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every screen fits a 360 dp phone in portrait and in landscape, survives large system text, and uses the extra room on tablets and desktop browsers, on web, Android and iOS alike.

**Architecture:** One Flutter widget tree serves all three platforms, so every change is Dart layout code with no platform branch. A route-by-route widget-test sweep over phone, landscape-phone, tablet and desktop sizes is the failing test that drives the work; each task adds the size or text scale it fixes. Shared layout values live in one new file, `lib/core/theme/app_layout.dart`. The shell moves navigation from the bottom bar to a side rail at 600 dp, and `TablePanelLayout` puts the panel beside the table on wide landscape bodies.

**Tech Stack:** Flutter 3.47.0 / Dart 3.13, Riverpod 3, go_router 18.0.1, Drift; `flutter_test`; Node + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** No separate design doc. The decisions are in **Design Decisions** below. They come from the responsive audit of 2026-10-21 and these spec lines:
- `docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md:676`: layout must be checked at phone-narrow width, not only in a wide browser window.
- `docs/superpowers/specs/2026-10-21-poolcoachai-coach-design.md:148` and `:736`: the Coach table sits beside its panel on wide web; 360 × 640 must not overflow.
- `docs/superpowers/specs/2026-10-01-poolcoachai-cut-angle-simulator-design.md:22,194` and `docs/superpowers/specs/2026-10-02-poolcoachai-table-physics-design.md:25`: the table stays landscape and shrinks; turning it to portrait on phones is out of scope.

## Design Decisions

| # | Decision | Why |
|---|---|---|
| D1 | Width classes follow Material 3: compact below 600 dp, medium from 600 dp. | Every landscape phone is at least 640 dp wide, so it lands in medium. |
| D2 | Below 600 dp the shell keeps the bottom `NavigationBar` and the floating Coach button. From 600 dp it shows a `NavigationRail` with labels, scrollable, with the Coach button as its `leading`. | A bottom bar takes 80 dp of a landscape phone's 360 dp height. The rail spends width instead, which landscape has spare. |
| D3 | System text scale is clamped to at most 1.5 app-wide. Smaller text is left alone. Bottom-bar labels are clamped to 1.0. | 1.5 covers every standard size on both platforms; iOS reaches about 1.35 before its accessibility sizes. At 360 dp each of the five bar destinations is 72 dp wide, which leaves the labels no room to grow. The rail has no such limit. |
| D4 | Left and right safe-area insets are applied once, at the app root. | A vertical `ListView` pads only top and bottom (Flutter `scroll_view.dart:898-927`). In landscape the notch side covers content today. |
| D5 | `TablePanelLayout` goes side by side when its body is at least 600 dp wide and at least 1.3 times wider than tall. The panel is then 40 % of the width, clamped to 320–440 dp. Otherwise the layout stays stacked exactly as today. | A desktop window of 900 px or more is landscape, which meets Coach spec §4.3. Landscape phones also get a full-height panel. A portrait tablet stays stacked, where its table is biggest. |
| D6 | Stats metric tiles flow in equal-height rows, 2 to 4 per row by available width, at least 220 dp each. | Today's fixed `childAspectRatio: 2` makes each tile 80 dp tall on a phone, which overflows with larger text. |
| D7 | On wide windows, reading screens cap their content at 840 dp, centered. Table screens are not capped. | Lists stretched across 1200 dp are hard to read. The table needs every pixel. |
| D8 | The installed web app (PWA) stops locking portrait. | `web/manifest.json:9` says `portrait-primary`, while Android and iOS allow landscape. |
| D9 | The viewport tag stays as it is. | Flutter web injects `width=device-width, initial-scale=1.0, maximum-scale=5.0` at runtime; it is in `build/web/main.dart.js`. Task 8 proves it in headless Chrome. |

**Out of scope:** turning the table to portrait; widths under 360 dp, such as iPad Slide Over at 320 pt; an extended rail or navigation drawer for very wide screens; foldable hinges; the PWA name, colours and description; golden-image tests.

## Global Constraints

- **Toolchain.** Flutter 3.47.0, the version CI pins, is not on PATH. Find it and check that `"$FLUTTER" --version` prints 3.47.0; on the owner's main machine it is `/c/Users/anhnpv/flutter/bin/flutter.bat`, with `dart.bat` beside it. Never use the old 3.44.6 at `D:\flutter`. There is no `gh`.
- **Codegen.** `database.g.dart` is not committed. In a fresh worktree run `"$DART" run build_runner build --delete-conflicting-outputs` before anything else.
- **Branch.** Worktree `.claude/worktrees/responsive`, branch `feat/responsive`, from current `main`. Do not push, merge or deploy. That is the owner's call at the handoff.
- **Coach branch.** `feat/coach` is being built in another session. Steps marked **(Coach)** apply only if Coach is already on `main` when Task 0 runs. Otherwise skip them and list them in the handoff.
- **Strings.** No Vietnamese string literal in `lib/features/**` or `lib/core/widgets/**` (`test/architecture_test.dart`, rule 5). This plan adds no user-visible text: the rail reuses the five `Vi.tab*` labels and `Vi.coachTitle`.
- **Platforms.** No web-only API. Everything here is `MediaQuery` and `LayoutBuilder`, which behave the same on web, Android and iOS.
- **Lints.** `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `require_trailing_commas`, `sort_child_properties_last`. Doc comments are in Vietnamese, like the rest of the codebase.
- **Widget tests.** Boot the app with `UncontrolledProviderScope` and a container from `testContainer(...)`. Never write `ProviderScope(overrides: ...)` with an explicit `List<Override>`, which crashes the compiler. Never `container.read(x.future)`, which hangs.
- **Screen size and text scale in tests**, always this way (Task 1 wraps it as `applyScreen`):
  ```dart
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  ```
  Keyboard: `tester.view.viewInsets = const FakeViewPadding(bottom: 160);`. Notch: set both `tester.view.padding` and `tester.view.viewPadding` to `const FakeViewPadding(left: 44, right: 44)`. With `devicePixelRatio = 1` these values are logical pixels.
- **Overflow check.** `expect(tester.takeException(), isNull, reason: ...)` after every settle, naming the size and the route.
- **Helper names in test snippets.** `openStats`, `pumpShell`, `pumpRoot` and `openPlayWithCues` stand for the pump helper that test file already has, or for its existing setup. Use the real name; do not add a second helper that does the same thing.
- **Test sizes.** Phone 360 × 640, landscape phone 740 × 360, portrait tablet 800 × 1280, desktop 1280 × 800. "Large text" means system scale 2.0, which the app clamps to 1.5 from Task 4 on.
- **How to fix an overflow**, in this order. Never shrink text further or hide content.
  1. A `Text` in a `Row` gets `Flexible`, or `Expanded` when it should take the remaining space. Names get `maxLines: 1, overflow: TextOverflow.ellipsis`; sentences wrap.
  2. A fixed-height box around text loses the fixed height, or its row gets `IntrinsicHeight`.
  3. A `Column` that can outgrow its space goes inside a `SingleChildScrollView`.
- **Long runs.** The full suite takes about 15 minutes, and Gradle builds take minutes too. Run them in the background writing to a log, and print a progress line at least every 60 s: the step, in Vietnamese ("BƯỚC 2/3 …"), and the last `+N ~S -F` counter.
- **Layout values.** Copy them exactly.

  | Constant | Value | Added in |
  |---|---|---|
  | `_minTileWidth` (Stats) | `220` | Task 2 |
  | `AppLayout.maxTextScale` | `1.5` | Task 4 |
  | `AppLayout.navBarLabelMaxTextScale` | `1.0` | Task 4 |
  | `AppLayout.mediumWidth` | `600` | Task 5 |
  | `TablePanelLayout.sideBySideMinAspect` | `1.3` | Task 6 |
  | `TablePanelLayout.sidePanelShare` / `sidePanelMinWidth` / `sidePanelMaxWidth` | `0.4` / `320` / `440` | Task 6 |
  | `AppLayout.readableMaxWidth` | `840` | Task 7 |

## Review Focus

1. **Rotating a phone in the middle of something.** Every phone crosses 600 dp when rotated, so the bar and the rail swap. The open tab, its stack and the screen's own state must survive. go_router gives the shell a `GlobalKey` (`route.dart:918,1226` in go_router 18.0.1), so moving it within one build keeps state. Test: Task 5, `xoay máy giữ nguyên trạng thái nhánh`.
2. **System text above and below the clamp.** Android 14 offers 200 %, iOS accessibility sizes go past 300 %, and some users pick 85 %. The app must use at most 1.5 and leave small sizes alone. Tests: Task 4.
3. **The keyboard open on a landscape phone inside a form dialog.** About 200 dp of height remain. The fields must scroll, and the confirm button must stay above the keyboard. Tests: Task 3.
4. **A notch on the side in landscape.** No content may sit under it. Test: Task 4, `tai thỏ ngang`.
5. **Long names the user typed** (cue names, player names, schedule labels) in rows at 360 dp with large text. Tests: the rich fixture from Task 1, swept with large text in Task 4.

---

### Task 0: Worktree and baseline

**Files:** none.

- [ ] **Step 1: Check whether Coach is on `main`**

Run: `git cat-file -e main:lib/features/coach/presentation/situation_screen.dart && echo COACH_MERGED || echo COACH_NOT_MERGED`
Record the answer. It decides every **(Coach)** step.

- [ ] **Step 2: Create the worktree** with superpowers:using-git-worktrees

Run: `git worktree add .claude/worktrees/responsive -b feat/responsive main`

- [ ] **Step 3: Fetch packages and generate code**

Run inside the worktree: `"$FLUTTER" pub get && "$DART" run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` is written and the command exits 0.

- [ ] **Step 4: Baseline**

Run: `"$FLUTTER" analyze`. Expected: `No issues found!`
Run the full `"$FLUTTER" test` with progress lines. Expected: all pass. Record the test count.
If anything fails here, stop and report it: the failure is older than this plan.

---

### Task 1: Route sweep at default text size

**Files:**
- Create: `test/support/route_cases.dart`, `test/support/rich_data.dart`, `test/support/layout_sweep.dart`, `test/smoke/responsive_routes_test.dart`
- Modify: `test/smoke/all_routes_test.dart` (route tables at lines 49–94 and `pumpApp` at 96–114 move out)
- Modify only if the sweep fails: the screens it names

**Interfaces:**
- Produces in `route_cases.dart`:
  - `typedef RouteCase = ({String path, Type screen});`
  - `signedInRouteCases` and `signedOutRouteCases`, type `Map<String, RouteCase>`: `_routeCases` and `_signedOutRouteCases` moved verbatim.
  - `const tableScreens = <Type>{SimulatorScreen, PlannerScreen};`: screens whose body is a `TablePanelLayout`.
  - `Future<GoRouter> pumpRoutedApp(WidgetTester tester, {required ProviderContainer container, bool signedIn = true})`: the old `pumpApp` body, taking the container instead of building it. It registers `router.dispose` and `container.dispose` teardowns.
- Produces in `rich_data.dart`: `ProviderContainer richContainer()`.
- Produces in `layout_sweep.dart`:
  - `typedef SweepConfig = ({String name, Size size, double textScale});`
  - `void applyScreen(WidgetTester tester, Size size, {double textScale = 1.0})`: the block from Global Constraints.
  - `Future<void> scrollThroughAll(WidgetTester tester)`
  - `Future<void> sweepRoutes(WidgetTester tester, SweepConfig config, {required bool signedIn})`

- [ ] **Step 1: Move the route tables and `pumpApp`** into `route_cases.dart` under the names above. `all_routes_test.dart` imports them and keeps its tests and assertions unchanged.

Run: `"$FLUTTER" test test/smoke/all_routes_test.dart`
Expected: PASS, with the same number of tests as before.

- [ ] **Step 2: Write `richContainer()`**

Long strings are deliberate: they are what overflows. Build the matches from the fixture at `test/features/stats/stats_screen_test.dart:32-58`, and the rank and BU test from `test/features/rank/rank_card_test.dart:18-29` without the warning fields. `sessions` comes from `test/support/roadmap_fixtures.dart:32-41`.

```dart
/// Dữ liệu đầy, tên dài: quét tràn phải gặp hàng thật, không chỉ màn trống.
ProviderContainer richContainer() => testContainer(
      logs: sessions('d1', 8, [
        for (var i = 1; i <= 7; i++) testToday.subtract(Duration(days: i)),
      ]),
      timerSessions: [
        TimerSession(id: 'timer-1', date: testToday, durationSec: 3600, cueId: 'cue-long'),
        TimerSession(id: 'timer-2', date: testToday.subtract(const Duration(days: 1)), durationSec: 1800),
      ],
      schedule: const [
        ScheduleSlot(id: 's1', day: 1, time: '19:00', label: 'Tập điều bi và dọn bàn 9 bi theo bộ đề BU', cat: SkillCategory.position),
        ScheduleSlot(id: 's2', day: 3, time: '06:30', label: 'Ngắm bi cắt mỏng', cat: SkillCategory.aiming),
      ],
      equipment: [
        CueEquipment(
          id: 'cue-long',
          name: 'Cơ chơi Predator Revo 12.4 Carbon ngọn dài bản giới hạn',
          type: CueType.values.first,
          shaftBrand: 'Predator',
          shaftDiameterMm: 12.4,
          tipBrand: 'Kamui Black Super Soft',
          buttBrand: 'Cuetec Cynergy',
          skillCategories: const [SkillCategory.aiming, SkillCategory.position],
          lastTipMaintenance: DateTime(2026, 8, 15),
          tipMaintenanceDueDate: DateTime(2026, 9, 15), // quá hạn so với testToday
        ),
        const CueEquipment(id: 'cue-break', name: 'Cơ phá nhảy', type: CueType.breakJump, skillCategories: [SkillCategory.aiming]),
      ],
      matches: [
        // stats_screen_test.dart:32-58, đổi tên người chơi và thêm cueId:
        //   playerName: 'Nguyễn Văn Trường Giang', opponentName: 'Trần Thị Bích Ngọc Hạnh', cueId: 'cue-long'
        // và một trận đang đánh: id 'match-2', rackWinners [RackWinner.opponent], không shots, không completedAt.
      ],
      rank: PlayerRank(rank: Rank.d, source: RankSource.verified, buScore: 137, testId: 't1', onboardingState: OnboardingState.done, updatedAt: testToday),
      tests: [/* BuTest 't1' đã xong, như rank_card_test.dart:23-29 */],
      goal: GoalRecord(
        updatedAt: testToday,
        goal: PlayerGoal(goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: testToday),
      ),
      achievements: [Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: testToday)],
      buResult: BuResult(
        testId: 't1',
        completedAt: testToday.subtract(const Duration(days: 3)),
        total: 137,
        lost: const {'F1': 5, 'F3': 4, 'S5': 6},
      ),
    );
```

- [ ] **Step 3: Write `layout_sweep.dart`**

`scrollThroughAll` pages through every vertical list a screen paints. A `ListView` builds only the rows on screen, so rows further down are never laid out unless something scrolls to them.

```dart
Future<void> scrollThroughAll(WidgetTester tester) async {
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) => axisDirectionToAxis(s.axisDirection) == Axis.vertical)
      .toList();
  for (final state in states) {
    if (!state.mounted) continue;
    final position = state.position;
    for (var step = 0; step < 50; step++) {
      final target = math.min(position.viewportDimension * 0.9 * step, position.maxScrollExtent);
      position.jumpTo(target);
      await tester.pump();
      if (target >= position.maxScrollExtent) break;
    }
    position.jumpTo(0);
    await tester.pump();
  }
}

Future<void> sweepRoutes(WidgetTester tester, SweepConfig config, {required bool signedIn}) async {
  applyScreen(tester, config.size, textScale: config.textScale);
  final router = await pumpRoutedApp(
    tester,
    container: signedIn ? richContainer() : testContainer(),
    signedIn: signedIn,
  );
  for (final route in (signedIn ? signedInRouteCases : signedOutRouteCases).values) {
    router.go(route.path);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '${config.name}: ${route.path} tràn khi mở');
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull, reason: '${config.name}: ${route.path} tràn khi cuộn');
  }
}
```

- [ ] **Step 4: Write the sweep test**

```dart
const sweepConfigs = <SweepConfig>[
  (name: 'điện thoại dọc 360×640', size: Size(360, 640), textScale: 1.0),
  (name: 'máy tính bảng dọc 800×1280', size: Size(800, 1280), textScale: 1.0),
  (name: 'máy tính 1280×800', size: Size(1280, 800), textScale: 1.0),
];

void main() {
  for (final config in sweepConfigs) {
    testWidgets('${config.name}: mọi màn đã đăng nhập không tràn', (tester) async {
      await sweepRoutes(tester, config, signedIn: true);
    });
    testWidgets('${config.name}: mọi màn chưa đăng nhập không tràn', (tester) async {
      await sweepRoutes(tester, config, signedIn: false);
    });
  }
}
```

If the runner reports a timeout for a config, split that config into one `testWidgets` per route with the same assertions.

- [ ] **Step 5: Run the sweep**

Run: `"$FLUTTER" test test/smoke/responsive_routes_test.dart`
Expected: PASS, or failures whose reason names the size and the route. A full pass is a valid outcome at default text size.

- [ ] **Step 6: Fix each reported overflow** with the rules in Global Constraints. Change only what the sweep reports.

- [ ] **Step 7: Re-run the sweep and `all_routes_test.dart`**

Expected: both PASS.

- [ ] **Step 8: Commit**

```bash
git add test/support/route_cases.dart test/support/rich_data.dart test/support/layout_sweep.dart test/smoke/ <fixed screens>
git commit -m "Sweep every route at phone, tablet and desktop sizes with rich data"
```
If Step 6 changed screens, name the fixed routes in the commit message.

---

### Task 2: Stats tiles that grow with their text

**Files:**
- Modify: `lib/features/stats/presentation/stats_screen.dart:63-111` (the `GridView.count`)
- Test: `test/features/stats/stats_screen_test.dart`

**Interfaces:**
- Consumes: `applyScreen` (Task 1).
- Produces: nothing other tasks use. The new widget is the private `_MetricGrid({required List<Widget> children})`.

- [ ] **Step 1: Write the failing tests.** Open the screen with this file's existing pump helper and fixtures (lines 17–60).

```dart
testWidgets('lưới chỉ số ở 360: hai ô một hàng', (tester) async {
  applyScreen(tester, const Size(360, 640));
  await openStats(tester); // helper sẵn có của file này
  final top = tester.getTopLeft(find.text(Vi.statsTotalSessions)).dy;
  expect(tester.getTopLeft(find.text(Vi.statsDrillSessions)).dy, top);
  expect(tester.getTopLeft(find.text(Vi.statsTimerSessions)).dy, greaterThan(top));
});

testWidgets('lưới chỉ số ở 800: ba ô một hàng', (tester) async {
  applyScreen(tester, const Size(800, 1280));
  await openStats(tester);
  final top = tester.getTopLeft(find.text(Vi.statsTotalSessions)).dy;
  expect(tester.getTopLeft(find.text(Vi.statsTimerSessions)).dy, top);
  expect(tester.getTopLeft(find.text(Vi.statsTimerTotal)).dy, greaterThan(top));
});

testWidgets('chữ ×1.5 ở 360: ô không tràn, hai ô cùng hàng cao bằng nhau', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 1.5);
  await openStats(tester);
  expect(tester.takeException(), isNull);
  // .first là PcCard gần nhất: ô chỉ số, không phải thẻ bọc ngoài nếu có.
  Size card(String label) => tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(PcCard)).first);
  expect(card(Vi.statsTotalSessions).height, card(Vi.statsDrillSessions).height);
});
```

800 dp gives three per row both before and after the rail arrives in Task 5. Four per row needs more than 880 dp of content, which Task 7's 840 dp cap rules out, so it is not tested.

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/features/stats/stats_screen_test.dart`
Expected: the 800 dp test fails because the grid has two columns. The ×1.5 test fails with a RenderFlex overflow.

- [ ] **Step 3: Replace the `GridView.count` with `_MetricGrid`**, keeping the nine `_MetricCard`s in today's order.

`_MetricGrid` is a `LayoutBuilder`. It uses `columns = (constraints.maxWidth / _minTileWidth).floor().clamp(2, 4)`, with `static const _minTileWidth = 220.0`. It lays the cards out in rows of `columns`. Each row is `IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, ...))`, with each card in `Expanded` and an 8 dp gap between them. A short last row is padded with empty `Expanded` slots so its columns line up. Rows are 8 dp apart.

If the screen still overflows elsewhere at ×1.5, fix it here with rule 1. The skill row at `stats_screen.dart:176-186` is the likely spot: its trailing `Text` holds a full sentence when a skill has no scored sessions.

- [ ] **Step 4: Run the tests**

Run: `"$FLUTTER" test test/features/stats/stats_screen_test.dart test/smoke/responsive_routes_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/stats/presentation/stats_screen.dart test/features/stats/stats_screen_test.dart
git commit -m "Lay Stats tiles out in equal-height rows that follow the screen width and text size"
```

---

### Task 3: Form dialogs on a landscape phone with the keyboard open

**Files:**
- Modify: `lib/features/play/presentation/play_screen.dart:43-137` (the `_startMatch` form)
- Modify: `test/support/layout_sweep.dart` (add one helper)
- Test: `test/features/play/play_screen_test.dart`, `test/features/training/schedule_screen_test.dart`, `test/features/profile/equipment_screen_test.dart`
- Create: `test/features/rank/rank_info_sheet_test.dart`

**Interfaces:**
- Consumes: `applyScreen`, `scrollThroughAll` (Task 1).
- Produces in `layout_sweep.dart`: `void expectDialogFitsAboveKeyboard(WidgetTester tester, {required double screenHeight, required double keyboard})`.

- [ ] **Step 1: Add the helper**

```dart
/// Hộp thoại không tràn, và nút cuối cùng (nút xác nhận) nằm trên bàn phím.
void expectDialogFitsAboveKeyboard(WidgetTester tester, {required double screenHeight, required double keyboard}) {
  expect(tester.takeException(), isNull);
  final buttons = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(tester.getBottomLeft(buttons.last).dy, lessThanOrEqualTo(screenHeight - keyboard));
}
```

- [ ] **Step 2: Write the failing test for the start-match dialog**, in `play_screen_test.dart`. Use the cue-picker setup from lines 109–243 so the dialog shows all five fields.

```dart
testWidgets('điện thoại ngang, bàn phím mở: hộp thoại bắt đầu trận cuộn được, nút Bắt đầu trên bàn phím', (tester) async {
  applyScreen(tester, const Size(740, 360));
  tester.view.viewInsets = const FakeViewPadding(bottom: 160);
  await openPlayWithCues(tester); // dựng như nhóm cue picker của file này
  await tester.tap(find.text(Vi.matchStart));
  await tester.pumpAndSettle();
  expectDialogFitsAboveKeyboard(tester, screenHeight: 360, keyboard: 160);
  await scrollThroughAll(tester);
  expect(tester.takeException(), isNull);
});
```

Add the same test for the record-shot dialog. Create the match the way lines 30–39 do, open the dialog the way lines 47–65 do, then run the same assertions. This one is expected to pass already and guards against regressions.

- [ ] **Step 3: Run to see the start-match test fail**

Run: `"$FLUTTER" test test/features/play/play_screen_test.dart`
Expected: FAIL with a RenderFlex overflow inside `AlertDialog`.

- [ ] **Step 4: Fix it.** Wrap the `Column` at `play_screen.dart:45` in a `SingleChildScrollView` inside the `Form`, the same way `_recordShot` does at lines 223–226.

- [ ] **Step 5: Add the same landscape-and-keyboard test** for the schedule slot dialog (`schedule_screen_test.dart`, opened with `Vi.scheduleAdd`) and the cue dialog (`equipment_screen_test.dart`, opened with `Vi.equipmentAdd`). Both already scroll, so they should pass.

- [ ] **Step 6: Test the pickers and the rank sheet at 740 × 360**, keyboard closed. For each, expect `tester.takeException()` to be null after `pumpAndSettle`.
  - The time picker, from the time field in the schedule dialog (`schedule_screen.dart:91`).
  - The maintenance date picker, from the cue dialog (`equipment_screen.dart:611`).
  - The rank info sheet, in the new `rank_info_sheet_test.dart`. Pump `MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: RankBadgeLine(rank: <verified D as in Task 1>)))`, tap `find.byTooltip(Vi.rankInfo)`, settle, then `scrollThroughAll`.

  If a Flutter picker throws by itself, do not patch around it. Mark that test `skip: true`, quote the exception in a comment, and list it in the handoff for the owner to decide.

- [ ] **Step 7: Run all four files**

Expected: PASS, apart from any picker skipped under Step 6.

- [ ] **Step 8: Commit**

```bash
git add lib/features/play/presentation/play_screen.dart test/support/layout_sweep.dart test/features/play/play_screen_test.dart test/features/training/schedule_screen_test.dart test/features/profile/equipment_screen_test.dart test/features/rank/rank_info_sheet_test.dart
git commit -m "Let the start-match dialog scroll and test every form dialog on a landscape phone with the keyboard open"
```

---

### Task 4: Clamp text scale and respect side insets at the app root

**Files:**
- Create: `lib/core/theme/app_layout.dart`
- Modify: `lib/app.dart:57-65` (add `builder:`), `lib/core/widgets/pc_shell_scaffold.dart:59-66` (wrap the `NavigationBar`)
- Create: `test/core/app_layout_test.dart`
- Modify: `test/smoke/responsive_routes_test.dart` (one config)
- Modify only if the sweep fails: the screens it names

**Interfaces:**
- Consumes: `applyScreen`, `pumpRoutedApp`, `richContainer`, `sweepConfigs` (Task 1).
- Produces: `abstract final class AppLayout` with `static const double maxTextScale = 1.5;` and `static const double navBarLabelMaxTextScale = 1.0;`. Tasks 5 and 7 add to the same class.

- [ ] **Step 1: Write the failing tests** in `test/core/app_layout_test.dart`

```dart
Future<void> openHome(WidgetTester tester) async {
  final router = await pumpRoutedApp(tester, container: richContainer());
  router.go(Routes.home);
  await tester.pumpAndSettle();
}

double scaleOf(WidgetTester tester, Finder finder) =>
    MediaQuery.textScalerOf(tester.element(finder)).scale(10);

testWidgets('chữ hệ thống ×3 bị kẹp còn ×1.5 trong thân màn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 3.0);
  await openHome(tester);
  expect(scaleOf(tester, find.text(Vi.homeStreakUnit)), 15);
});

testWidgets('chữ hệ thống ×0.85 giữ nguyên', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 0.85);
  await openHome(tester);
  expect(scaleOf(tester, find.text(Vi.homeStreakUnit)), closeTo(8.5, 1e-9));
});

testWidgets('nhãn thanh tab dưới không phóng theo chữ hệ thống', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0);
  await openHome(tester);
  final label = find.descendant(of: find.byType(NavigationBar), matching: find.text(Vi.tabTraining));
  expect(scaleOf(tester, label), 10);
});

testWidgets('tai thỏ ngang: thân màn không nằm dưới tai thỏ', (tester) async {
  applyScreen(tester, const Size(740, 360));
  tester.view.padding = const FakeViewPadding(left: 44, right: 44);
  tester.view.viewPadding = const FakeViewPadding(left: 44, right: 44);
  await openHome(tester);
  final appBar = find.byType(AppBar).first;
  expect(tester.getTopLeft(appBar).dx, greaterThanOrEqualTo(44));
  expect(tester.getTopRight(appBar).dx, lessThanOrEqualTo(740 - 44));
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/core/app_layout_test.dart`
Expected: the ×3 test reads 30, the tab-label test reads more than 10 because Flutter's own label cap is higher, and the notch test finds the `AppBar` at x = 0. The ×0.85 test may already pass; it guards the minimum.

- [ ] **Step 3: Create `AppLayout`** with the two constants. Each gets a Vietnamese doc comment carrying the reason from D3.

- [ ] **Step 4: Add the builder** to `MaterialApp.router` in `lib/app.dart`

```dart
builder: (context, child) => MediaQuery.withClampedTextScaling(
  maxScaleFactor: AppLayout.maxTextScale,
  child: ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(top: false, bottom: false, child: child ?? const SizedBox.shrink()),
  ),
),
```

The `ColoredBox` paints the strip beside a notch in the app's background colour instead of black.

- [ ] **Step 5: Wrap the bottom bar** in `PcShellScaffold`: `bottomNavigationBar: MediaQuery.withClampedTextScaling(maxScaleFactor: AppLayout.navBarLabelMaxTextScale, child: NavigationBar(...))`. Flutter's own cap for bar labels is 1.3, and the lower of the two wins.

- [ ] **Step 6: Run the tests**

Run: `"$FLUTTER" test test/core/app_layout_test.dart`
Expected: PASS.

- [ ] **Step 7: Add the large-text phone config** to `sweepConfigs`

```dart
(name: 'điện thoại dọc 360×640, chữ lớn', size: Size(360, 640), textScale: 2.0),
```

- [ ] **Step 8: Run the sweep and fix what it reports**, with the rules in Global Constraints.

Run: `"$FLUTTER" test test/smoke/responsive_routes_test.dart`
These rows are the likely failures. Each `Text` has no `Flexible` around it:

| Where | Fix |
|---|---|
| `lib/features/rank/presentation/rank_badge_line.dart:21` | rule 1, the sentence wraps |
| `lib/features/home/presentation/home_screen.dart:110` | rule 1, `Expanded` |
| `lib/features/training/presentation/drill_detail_screen.dart:78` | rule 1 |
| `lib/features/stats/presentation/stats_screen.dart:179` (if Task 2 left it) | rule 1, `textAlign: TextAlign.end` |
| `stats_screen.dart:337`, `play_screen.dart:413`, `roadmap/presentation/step_tile.dart:65` | rule 1, only if reported |

Expected after the fixes: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/core/theme/app_layout.dart lib/app.dart lib/core/widgets/pc_shell_scaffold.dart test/core/app_layout_test.dart test/smoke/responsive_routes_test.dart <fixed screens>
git commit -m "Clamp system text to 1.5, keep tab labels at 1.0 and keep content clear of side notches"
```

---

### Task 5: Side rail from 600 dp, and landscape on every platform

**Files:**
- Modify: `lib/core/theme/app_layout.dart` (add `mediumWidth`), `lib/core/widgets/pc_shell_scaffold.dart`, `lib/core/theme/app_theme.dart` (add `navigationRailTheme` after `navigationBarTheme`), `web/manifest.json:9`
- Test: `test/core/widgets/pc_shell_scaffold_test.dart`
- Create: `test/platform_config_test.dart`
- Modify: `test/smoke/responsive_routes_test.dart` (two configs)

**Interfaces:**
- Consumes: `AppLayout` (Task 4), `applyScreen` (Task 1).
- Produces: `AppLayout.mediumWidth = 600.0`, used by Task 6.

- [ ] **Step 1: Write the failing shell tests** in `pc_shell_scaffold_test.dart`. Reuse the file's own router for the first three. For the rotation test, add a second test router with five branches, where branch 0's root is this probe:

```dart
class _CounterProbe extends StatefulWidget {
  const _CounterProbe();
  @override
  State<_CounterProbe> createState() => _CounterProbeState();
}

class _CounterProbeState extends State<_CounterProbe> {
  var _n = 0;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('đếm $_n'),
          TextButton(onPressed: () => setState(() => _n++), child: const Text('tăng')),
        ],
      );
}
```

```dart
testWidgets('dưới 600: thanh tab dưới và nút Coach nổi', (tester) async {
  applyScreen(tester, const Size(599, 800));
  await pumpShell(tester); // helper sẵn có của file này
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
  expect(find.byTooltip(Vi.coachTitle), findsOneWidget);
});

testWidgets('từ 600: thanh bên cuộn được, nút Coach ở đầu thanh', (tester) async {
  applyScreen(tester, const Size(600, 800));
  await pumpShell(tester);
  expect(find.byType(NavigationBar), findsNothing);
  expect(find.descendant(of: find.byType(NavigationRail), matching: find.byTooltip(Vi.coachTitle)), findsOneWidget);
  expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).scrollable, isTrue);
});

// Lặp lại đúng các bước của test chuyển nhánh sẵn có, ở 1024×768, bấm nhãn trên thanh bên.
testWidgets('thanh bên chuyển nhánh và giữ ngăn xếp như thanh dưới', (tester) async { ... });

testWidgets('xoay máy giữ nguyên trạng thái nhánh', (tester) async {
  applyScreen(tester, const Size(360, 640));
  await tester.pumpWidget(MaterialApp.router(routerConfig: probeRouter()));
  await tester.tap(find.text('tăng'));
  await tester.tap(find.text('tăng'));
  await tester.pump();
  tester.view.physicalSize = const Size(640, 360);
  await tester.pumpAndSettle();
  expect(find.byType(NavigationRail), findsOneWidget);
  expect(find.text('đếm 2'), findsOneWidget);
  tester.view.physicalSize = const Size(360, 640);
  await tester.pumpAndSettle();
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.text('đếm 2'), findsOneWidget);
});

testWidgets('điện thoại ngang, chữ lớn: thanh bên không tràn', (tester) async {
  applyScreen(tester, const Size(740, 360), textScale: 2.0);
  await pumpShell(tester);
  expect(tester.takeException(), isNull);
});

test('thanh bên dùng đúng màu của thanh tab dưới', () {
  final theme = AppTheme.dark();
  final rail = theme.navigationRailTheme;
  expect(rail.backgroundColor, theme.navigationBarTheme.backgroundColor);
  expect(rail.indicatorColor, theme.navigationBarTheme.indicatorColor);
  expect(rail.selectedLabelTextStyle?.color, AppColors.accent);
  expect(rail.unselectedLabelTextStyle?.color, AppColors.textMuted);
  expect(rail.selectedIconTheme?.color, AppColors.accent);
  expect(rail.unselectedIconTheme?.color, AppColors.textMuted);
});
```

- [ ] **Step 2: Write the platform test**, `test/platform_config_test.dart`

```dart
test('PWA không khoá chiều xoay', () {
  final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, Object?>;
  expect(manifest['orientation'], 'any');
});

test('Android không khoá chiều xoay', () {
  expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), isNot(contains('android:screenOrientation')));
});

test('iPhone cho xoay dọc và cả hai chiều ngang', () {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final iphone = RegExp(r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>', dotAll: true)
      .firstMatch(plist)!
      .group(1)!;
  for (final o in ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight']) {
    expect(iphone, contains(o));
  }
});
```

- [ ] **Step 3: Run them to see them fail**

Run: `"$FLUTTER" test test/core/widgets/pc_shell_scaffold_test.dart test/platform_config_test.dart`
Expected: the rail tests find no `NavigationRail`, the theme test fails on the rail colours, and the PWA test reads `portrait-primary`. The Android and iPhone tests pass and only guard.

- [ ] **Step 4: Add `AppLayout.mediumWidth = 600.0`**, with a doc comment for D1.

- [ ] **Step 5: Branch `PcShellScaffold.build` on `MediaQuery.sizeOf(context).width < AppLayout.mediumWidth`.**
  - Below 600 dp: return today's `Scaffold`, unchanged, with Task 4's clamp around the bar.
  - From 600 dp: return `Scaffold(body: Row(children: [NavigationRail(...), const VerticalDivider(width: 1), Expanded(child: navigationShell)]))`. The rail takes `selectedIndex: navigationShell.currentIndex`, `onDestinationSelected: _onTap`, `labelType: NavigationRailLabelType.all`, `scrollable: true`, and `leading:` a `FloatingActionButton` with `elevation: 0` and the same tooltip, icon and `onPressed` as today's Coach button. Destinations are `NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_labels[i]))`.
  - Pass the same `navigationShell` object in both layouts and give it no new key; go_router's `GlobalKey` carries its state across the switch. The rail wraps itself in a leading-side `SafeArea`, and the app root has already consumed the side insets.
  - Update the class doc comment to describe both layouts. `fabClearance` stays as it is: below 600 dp it still clears the floating button, and from 600 dp the extra space is harmless.

- [ ] **Step 6: Add `navigationRailTheme`** to `app_theme.dart`, mirroring `navigationBarTheme` (lines 59–75): `backgroundColor: AppColors.bgDeep`, `indicatorColor: AppColors.accent.withValues(alpha: 0.18)`, `elevation: 0`. Selected label and icon use `AppColors.accent`, unselected use `AppColors.textMuted`. Labels use `AppTypography.label.copyWith(color: ...)`. Keep the contrast note from the bar theme's comment.

- [ ] **Step 7: Set `"orientation": "any"`** at `web/manifest.json:9`.

- [ ] **Step 8: Run the shell and platform tests**

Expected: PASS.

- [ ] **Step 9: Add the landscape configs** to `sweepConfigs`, run the sweep, and fix what it reports with the Global Constraints rules.

```dart
(name: 'điện thoại ngang 740×360', size: Size(740, 360), textScale: 1.0),
(name: 'điện thoại ngang 740×360, chữ lớn', size: Size(740, 360), textScale: 2.0),
```

- [ ] **Step 10: Run the full suite** with progress lines

Tests that pump the whole app at 600 dp or wider now get the rail; `flutter_test`'s default view is 800 × 600. If a test fails only because it looked for `NavigationBar` by type, or for the Coach button outside the rail, change its finder to the label text or `find.byTooltip(Vi.coachTitle)`. Make a test's screen smaller only when the test is about phone layout.
Expected: all pass.

- [ ] **Step 11: Commit**

```bash
git add lib/core/theme/app_layout.dart lib/core/widgets/pc_shell_scaffold.dart lib/core/theme/app_theme.dart web/manifest.json test/ <any finder updates>
git commit -m "Move navigation to a side rail from 600 dp and let the installed web app rotate"
```

---

### Task 6: Table beside the panel on wide landscape bodies

**Files:**
- Modify: `lib/features/training/presentation/simulator/table_panel_layout.dart`
- Create: `test/features/training/table_panel_layout_test.dart`

**Interfaces:**
- Consumes: `AppLayout.mediumWidth` (Task 5).
- Produces in `TablePanelLayout`, keeping its constructor unchanged:
  - `typedef TablePanelArrangement = ({bool sideBySide, Size table, double panelWidth});` at file level.
  - `static TablePanelArrangement arrange(Size body, double aspectRatio)`
  - `static const sideBySideMinAspect = 1.3;`, `sidePanelShare = 0.4;`, `sidePanelMinWidth = 320.0;`, `sidePanelMaxWidth = 440.0;`, `sideTablePadding = EdgeInsets.all(16);`
  - In stacked mode `panelWidth` is `body.width`.

- [ ] **Step 1: Write the failing tests.** Let `ar = TableLayout.aspectRatio(TableSpec.nineFoot)`. The bodies are the space under the app bar: a 740 × 360 phone with the rail leaves about 660 × 304, and a 1280 × 800 window leaves about 1200 × 744.

```dart
test('điện thoại dọc: bàn trên, bàn rộng hết thân màn', () {
  final a = TablePanelLayout.arrange(const Size(360, 560), ar);
  expect(a.sideBySide, isFalse);
  expect(a.table.width, closeTo(360 - 32, 0.01));
  expect(a.table.width / a.table.height, closeTo(ar, 1e-9));
});

test('xếp chồng vẫn giữ trần 55% chiều cao như cũ', () {
  final a = TablePanelLayout.arrange(const Size(590, 400), ar);
  expect(a.sideBySide, isFalse); // hẹp hơn 600
  expect(a.table.height, closeTo(400 * 0.55 - 24, 0.01));
});

test('điện thoại ngang: bàn trái, bảng phải rộng 320', () {
  final a = TablePanelLayout.arrange(const Size(660, 304), ar);
  expect(a.sideBySide, isTrue);
  expect(a.panelWidth, 320);
  expect(a.table.width, closeTo(math.min(660 - 320 - 32, (304 - 32) * ar), 0.01));
});

test('máy tính: bảng phải rộng 440', () {
  final a = TablePanelLayout.arrange(const Size(1200, 744), ar);
  expect(a.sideBySide, isTrue);
  expect(a.panelWidth, 440);
  expect(a.table.width, closeTo(math.min(1200 - 440 - 32, (744 - 32) * ar), 0.01));
});

test('máy tính bảng dọc và cửa sổ gần vuông vẫn xếp chồng', () {
  expect(TablePanelLayout.arrange(const Size(720, 1224), ar).sideBySide, isFalse);
  expect(TablePanelLayout.arrange(const Size(900, 800), ar).sideBySide, isFalse);
});

testWidgets('thân ngang: bảng bên phải bàn, cuộn bảng không kéo bàn theo', (tester) async {
  applyScreen(tester, const Size(740, 360));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TablePanelLayout(
        table: TableSpec.nineFoot,
        tableBuilder: (_) => const SizedBox.expand(key: Key('bàn')),
        panel: const SizedBox(key: Key('bảng'), height: 2000),
      ),
    ),
  ));
  expect(tester.takeException(), isNull);
  final table = find.byKey(const Key('bàn'));
  expect(tester.getTopLeft(find.byKey(const Key('bảng'))).dx, greaterThanOrEqualTo(tester.getTopRight(table).dx));
  final size = tester.getSize(table);
  expect(size.width / size.height, closeTo(ar, 0.01));
  final top = tester.getTopLeft(table).dy;
  await tester.drag(find.byKey(const Key('bảng')), const Offset(0, -500));
  await tester.pump();
  expect(tester.getTopLeft(table).dy, top);
});

testWidgets('thân dọc: bảng nằm dưới bàn', (tester) async {
  // như trên, ở 360×640: đỉnh bảng >= đáy bàn
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/features/training/table_panel_layout_test.dart`
Expected: compile error, because `arrange` does not exist yet.

- [ ] **Step 3: Implement `arrange`**

```dart
static TablePanelArrangement arrange(Size body, double aspectRatio) {
  final sideBySide = body.width >= AppLayout.mediumWidth &&
      body.width / body.height >= sideBySideMinAspect;
  if (sideBySide) {
    final panelWidth = (body.width * sidePanelShare).clamp(sidePanelMinWidth, sidePanelMaxWidth);
    final height = math.max(0.0, math.min(
      (body.width - panelWidth - sideTablePadding.horizontal) / aspectRatio,
      body.height - sideTablePadding.vertical,
    ));
    return (sideBySide: true, table: Size(height * aspectRatio, height), panelWidth: panelWidth);
  }
  // Đúng công thức đang có ở dòng 41-49: không đổi gì cho điện thoại và màn dọc.
  final width = math.max(0.0, body.width - tablePadding.horizontal);
  final maxHeight = math.max(0.0, body.height * maxTableShare - tablePadding.vertical);
  final height = math.min(width / aspectRatio, maxHeight);
  return (sideBySide: false, table: Size(height * aspectRatio, height), panelWidth: body.width);
}
```

An unbounded body height gives a ratio of 0, which stays stacked exactly as today.

- [ ] **Step 4: Use it in `build`.** The stacked branch keeps today's `Column` and takes its size from `arrange`.

The side-by-side branch is a `Row(crossAxisAlignment: CrossAxisAlignment.start)` with two children:
- The table: `Expanded` → `Padding(sideTablePadding)` → `Align(alignment: Alignment.topCenter)` → `SizedBox` of the arranged size → the existing inner `LayoutBuilder` → `tableBuilder`.
- The panel: `SizedBox(width: panelWidth)` → `SingleChildScrollView(padding: const EdgeInsets.fromLTRB(0, 16, 16, 16))` → `panel`.

The table stays outside the scroll area in both modes. Rewrite the class doc comment to describe both modes and cite D5.

- [ ] **Step 5: Run the tests**

Run: `"$FLUTTER" test test/features/training/ test/smoke/responsive_routes_test.dart`. **(Coach)** Add `test/features/coach/`.
Expected: PASS. The landscape and desktop sweep configs now exercise side-by-side panels. Fix any panel row that overflows at 320 dp with rule 1.

- [ ] **Step 6: Commit**

```bash
git add lib/features/training/presentation/simulator/table_panel_layout.dart test/features/training/table_panel_layout_test.dart <fixed panels>
git commit -m "Put the panel beside the table when the body is wide and landscape"
```

---

### Task 7: Readable width on wide screens

**Files:**
- Modify: `lib/core/theme/app_layout.dart` (add `readableMaxWidth`)
- Create: `lib/core/widgets/pc_readable_width.dart`
- Modify: `lib/core/widgets/pc_root_scaffold.dart`; `lib/features/training/presentation/simulator/simulator_screen.dart` and `lib/features/training/presentation/planner/planner_screen.dart` (opt out)
- Modify (wrap the body): `lib/features/notifications/presentation/notifications_screen.dart`, `lib/features/rank/presentation/rank_screen.dart`, `lib/features/rank/presentation/layout_gallery_screen.dart`, `lib/features/rank/presentation/onboarding_screen.dart`, `lib/features/rank/presentation/test_screen.dart`
- **(Coach)** Also wrap `lib/features/coach/presentation/coach_screen.dart` and `coach_library_screen.dart`, and add `SituationScreen` to `tableScreens`.
- Test: `test/core/widgets/pc_root_scaffold_test.dart`, `test/smoke/responsive_routes_test.dart`

**Interfaces:**
- Consumes: `AppLayout` (Task 4), `tableScreens`, `pumpRoutedApp`, `richContainer` (Task 1).
- Produces:
  - `AppLayout.readableMaxWidth = 840.0`
  - `PcReadableWidth({required Widget child, double maxWidth = AppLayout.readableMaxWidth, Key? key})`, which builds `Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child))`.
  - `PcRootScaffold({required String title, required Widget body, double maxBodyWidth = AppLayout.readableMaxWidth, Key? key})`. An infinite `maxBodyWidth` means no cap.

- [ ] **Step 1: Write the failing tests**

In `pc_root_scaffold_test.dart`, using the file's existing pump:

```dart
testWidgets('màn rộng 1280: thân màn tối đa 840 và nằm giữa, thanh tiêu đề vẫn rộng hết', (tester) async {
  applyScreen(tester, const Size(1280, 800));
  await pumpRoot(tester, body: const SizedBox.expand(key: Key('thân')));
  expect(tester.getSize(find.byKey(const Key('thân'))).width, 840);
  expect(tester.getTopLeft(find.byKey(const Key('thân'))).dx, (1280 - 840) / 2);
  expect(tester.getSize(find.byType(AppBar)).width, 1280);
});

testWidgets('điện thoại 360: thân màn rộng hết', ...);          // width == 360
testWidgets('màn có bàn bỏ trần: rộng hết 1280', ...);          // maxBodyWidth: double.infinity → width == 1280
```

In `responsive_routes_test.dart`:

```dart
testWidgets('máy tính 1280×800: màn đọc không rộng quá 840, màn có bàn không bị chặn', (tester) async {
  applyScreen(tester, const Size(1280, 800));
  final router = await pumpRoutedApp(tester, container: richContainer());
  for (final route in signedInRouteCases.values) {
    router.go(route.path);
    await tester.pumpAndSettle();
    if (tableScreens.contains(route.screen)) {
      expect(tester.getSize(find.byType(TablePanelLayout)).width,
          greaterThan(AppLayout.readableMaxWidth), reason: route.path);
    } else {
      final widest = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((s) => axisDirectionToAxis(s.axisDirection) == Axis.vertical)
          .map((s) => s.context.size!.width)
          .fold<double>(0, math.max);
      expect(widest, lessThanOrEqualTo(AppLayout.readableMaxWidth), reason: route.path);
    }
  }
});
```

- [ ] **Step 2: Run them to see them fail**

Expected: the body measures 1280 instead of 840, and the sweep test names the first uncapped route.

- [ ] **Step 3: Implement.**
  - Add the constant.
  - Create `PcReadableWidth`.
  - `PcRootScaffold` wraps `body` in `PcReadableWidth(maxWidth: maxBodyWidth)` when `maxBodyWidth` is finite. Its `AppBar` stays full width.
  - The simulator and planner screens pass `maxBodyWidth: double.infinity`.
  - The five plain-`Scaffold` screens wrap their `body` in `PcReadableWidth`.
  - Auth screens keep their own 420 dp cap and are not touched.

- [ ] **Step 4: Run the tests and the full suite** with progress lines

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_layout.dart lib/core/widgets/ lib/features/ test/core/widgets/pc_root_scaffold_test.dart test/smoke/responsive_routes_test.dart
git commit -m "Cap reading screens at 840 dp on wide windows; table screens keep the full width"
```

---

### Task 8: Prove it in Chrome and on a phone, then hand off

**Files:**
- Create: `tool/e2e/responsive.mjs`

**Interfaces:**
- Consumes: `launch`, `sleep` from `tool/e2e/cdp.mjs`; `registerThrowaway`, `deleteUserByEmail` from `tool/e2e/throwaway_user.mjs`. Use them the way `tool/e2e/simulator.mjs` does.
- Produces: `node tool/e2e/responsive.mjs <appUrl>`, which exits 1 if any check fails.

- [ ] **Step 1: Analyze**

Run: `"$FLUTTER" analyze`. Expected: `No issues found!`

- [ ] **Step 2: Full suite** with progress lines

Expected: all pass. The count is the baseline from Task 0 plus this plan's new tests.

- [ ] **Step 3: Write `responsive.mjs`**
  - The header comment gives the invocation, as `simulator.mjs` does.
  - It requires `DIRECTUS_URL` and `DIRECTUS_ADMIN_PASSWORD`, and the app URL as the first argument with no default, so it can never create users on production by accident.
  - It registers one throwaway user and deletes it in a `finally` block.
  - Viewports, set with `Emulation.setDeviceMetricsOverride`:

    | Name | Width × height | `deviceScaleFactor` | `mobile` |
    |---|---|---|---|
    | `phone` | 360 × 640 | 3 | true |
    | `phone-landscape` | 740 × 360 | 3 | true |
    | `tablet` | 800 × 1280 | 2 | true |
    | `desktop` | 1280 × 800 | 1 | false |

  - Routes, with paths taken from `lib/core/router/routes.dart`: home, training, simulator, planner, play, stats, profile, equipment, knowledge, notifications, rank. **(Coach)** Add coach and coach library.
  - For each viewport and route, it opens the route and waits for the screen's app-bar title, the `Vi` constant that screen passes. Then it checks three things with `eval`:
    - the `meta[name=viewport]` content contains `width=device-width`;
    - `window.innerWidth` equals the viewport width;
    - `document.documentElement.scrollWidth <= window.innerWidth`.

    It then saves a screenshot as `<viewport>-<route>.png` under `os.tmpdir()/pcai-responsive`.
  - It prints one line per check.

  Release builds do not report overflow; Flutter checks it only in debug. The widget sweep is the overflow guard. This script proves real phone-browser sizing and gives the owner pictures.

- [ ] **Step 4: Run it locally**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555      # in the background; Directus allows CORS from this port
DIRECTUS_URL=... DIRECTUS_ADMIN_PASSWORD=... node tool/e2e/responsive.mjs http://localhost:5555
```
Expected: every check passes, and the screenshot folder holds 44 images, or 52 with **(Coach)**.

- [ ] **Step 5: Debug APK for the owner's phone** with progress lines

Run: `JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" "$FLUTTER" build apk --debug`
Expected: `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 6: Commit**

```bash
git add tool/e2e/responsive.mjs
git commit -m "Check phone, landscape, tablet and desktop viewports in headless Chrome"
```

- [ ] **Step 7: Hand off.** Do not push, merge or deploy. Report:
  - the branch, its commits, and the test count against the baseline;
  - the screenshot folder and the APK path;
  - any picker skipped in Task 3, with its exception;
  - if Coach was not on `main` at Task 0, the steps to apply after merging it:
    - move its two route entries from `all_routes_test.dart` into `test/support/route_cases.dart`;
    - add `SituationScreen` to `tableScreens`;
    - wrap `CoachScreen` and `CoachLibraryScreen` bodies in `PcReadableWidth`;
    - add the coach routes to `responsive.mjs`;
    - re-run the sweep;
  - the owner's eye check:
    1. Look at the screenshots: tab labels, Stats tiles, and the planner side by side in landscape.
    2. On a real Android phone, rotate on Trang chủ and halfway through a Kế hoạch dọn bàn.
    3. Set the system font to its largest and look through the tabs.
    4. Start a match in landscape with the keyboard open.
  - iOS is checked only by the CI no-codesign build; there is no Mac to run it on.
