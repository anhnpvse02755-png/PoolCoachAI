# SDD ledger — plan: docs/superpowers/plans/2026-09-17-poolcoachai-foundation.md

Spec: docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md (read, reachable)
Branch: feat/foundation (branched from main @ 155296f)
Cleanup commitment: user asked that no junk branches remain — after merge to main,
delete feat/foundation both locally and on origin.
Note: no todo tool available in this harness; this ledger is the sole progress record.

---

## Pre-flight conflict scan

### Cross-task pairs (shared file or interface)

| Pair | Produces → consumes | Finding |
|---|---|---|
| T1 → T9 | `lib/main.dart` defines placeholder `PoolCoachApp`; T9 defines `PoolCoachApp` in `lib/app.dart` | **Duplicate class name across two files.** T9 Step 6 replaces `main.dart` wholesale, removing the placeholder. Consistent — but T9 must replace, not append. Flagged into T9 dispatch. |
| T3 → T4 | `vi.dart` created; T4 adds `Vi.skill` + imports `skill_category.dart` | No import cycle: `skill_category.dart` imports only `material.dart`. Clean. |
| T3 → T6 | `vi.dart`; T6 adds `Vi.rankWord` | Clean. |
| T3 → T8 | `vi.dart`; T8 adds 12 screen strings | Three tasks append to one file in sequence, never concurrently. Clean. |
| T2 → T5 | `AppColors`, `AppSpacing` → PcCard/PcSectionHeader/PcEmptyState | Names used in T5 all exist in T2's Produces. Clean. |
| T2 → T6 | `AppColors`, `AppSpacing` → PcSkillChip/PcRankBadge | Clean. |
| T4 → T6 | `SkillCategory.fg/.bg/.borderColor` → PcSkillChip | T4 Produces names match T6 usage exactly. Clean. |
| T4 → T6 | `Rank.group`, `Rank.label`, `RankGroup` → PcRankBadge | Clean. |
| T2 → T7 | `AppColors` → AppTypography/AppTheme | Clean. |
| T7 → T9 | `AppTheme.dark()` → app.dart | Clean. |
| T8 → T9 | `Routes.*` + 7 screen widgets → app_router.dart | All 7 widget names match. Clean. |
| T8 → T10 | `Routes.tabs` → smoke test | Clean. |
| T9 → T10 | `appRouter`, `PoolCoachApp` → smoke test | Clean. |
| T5 → T8 | `PcEmptyState` → 7 screens, called as `const` | `PcEmptyState` ctor is const and all args are const Strings. Clean. |

### Per-task self-consistency

| Task | Tests vs code vs files | Finding |
|---|---|---|
| T1 | scaffold, lint, placeholder app | Step 6 runs `flutter test` expecting possible failure, Step 7 deletes the sample test, Step 8 re-verifies before the commit. Constraint "every commit green" holds at commit time. Clean. |
| T2 | 4 colour tests vs `AppColors` | Clean. |
| T3 | 3 string tests vs `Vi` | Clean. |
| T4 | 3 + 6 tests vs two enums | Clean. |
| T5 | PcCard 3 tests, PcEmptyState 1 test; PcSectionHeader has **no test** | Presentational, no branching logic. Acceptable. Noted so review does not re-litigate. |
| T6 | 3 + 4 tests vs two widgets | Clean. |
| T7 | 3 theme tests | Clean. |
| T8 | 3 route tests vs `Routes` + 7 screens | Clean. |
| T9 | 6 navigation tests | **Plan defect:** the test code block omits `import 'package:flutter/material.dart'` yet uses `Icons` and `FloatingActionButton`; the step's prose says to add it. Prose and code disagree. See Ruling 1. |
| T10 | 2 smoke tests | **Plan defect:** test 2 asserts `find.byType(Text)` is non-empty, but the shell AppBar title and 5 tab labels guarantee that regardless of whether the body rendered. The assertion cannot fail. See Ruling 2. |

### Rulings made before execution

**Ruling 1 (Task 9):** the test file's import block must include
`package:flutter/material.dart`. The code block is authoritative once corrected;
the prose note stands. Cost if wrong: none — without it the file does not compile,
so the error surfaces immediately.

**Ruling 2 (Task 10):** replace smoke test 2. `find.byType(Text)` cannot fail while
the shell chrome is mounted, so it asserts nothing — exactly what the review rubric
treats as a defect. Replace with a route→widget-type map asserting each route mounts
its own screen widget. This keeps the test meaningful and extends naturally as later
plans register routes. Cost if wrong: a slightly stricter smoke test that later plans
must add a map entry to — cheap, and it fails loudly rather than silently.

---

## Progress

Task 1: complete (commits 155296f..57ae696, review clean — spec ✅, quality Approved)
Task 1: resolved ⚠️ — reviewer thought .gitignore was absent from the commit; it is present
  in 57ae696 and all six project entries verified on disk. No gap.
Task 1: minor (deferred): analysis_options.yaml adds 5 platform-dir analyzer excludes beyond
  the brief's 3 — benign, keeps lint off generated boilerplate.
Task 1: minor (deferred): pubspec.yaml carries template cupertino_icons — standard
  flutter create output, not an added dependency.
Task 2: complete (commits 57ae696..eb32153, review clean — spec ✅, quality Approved)
Task 2: minor (deferred): 3 of 4 colour tests restate the constant they assert, so they
  can only fail if someone edits the source. Plan-mandated. The 4th (success != danger)
  carries real signal. Final review should triage whether the trio earns its keep.
Infra note: Agent tool model:"haiku" expands to claude-haiku-4-5-20251001, which the API
  rejects. Task 2's first dispatch died at launch, no side effects. All implementers and
  reviewers from here use sonnet.
Task 3: complete (commits eb32153..cf18a27, review clean — spec ✅, quality Approved, zero issues)
Task 3: controller verified diacritics directly from the committed blob (0 U+FFFD). Suite 7/7.

Ruling 3 (user instruction, outranks the spec — 2026-09-17): no fabricated or hardcoded
  generated content. The spec previously called Coach Chat a "scripted scenario" and the
  AI Home recommendation prose "written to match the mock data" — both were fabrication.
  Spec now carries section 2.1 drawing the line: fixed UI chrome in vi.dart is fine;
  generated content (recommendations, goals, chat answers, notification bodies,
  statistical conclusions) must come from a named tested function over real data, or real
  AI, with display strings as parameterised templates. Falsifiable test added to section 9:
  flip the sample player's weak skill and every conclusion must follow by itself.
  Build step 9 now leads with the inference layer (weakestSkill, streakDays, overdueCues,
  todayGoals) before any screen consumes it.
  Impact on THIS plan: none — plan 1 builds only chrome and honest "under construction"
  placeholders, which section 2.1 explicitly permits. Impact lands on plans 5, 8 and 9.
  Cost if wrong: more work in the later plans than a scripted coach would have taken,
  and that is the point.
Task 4: complete (commits 7534486..c74d28e, review clean — spec ✅, quality Approved, zero issues)
Ruling 4 (user direction, 2026-09-17): the AI question is not logic-OR-LLM but four layers.
  Spec now carries section 2.2. Layer 1 Player Intelligence = pure Dart, deterministic,
  explainable, offline. Layer 2 progression gate = rule-based, LLM categorically forbidden
  (an inconsistent ladder is not a ladder). Layer 3 recommendations = rules now, ML once
  multi-user data exists. Layer 4 Coach Chat = genuinely needs an LLM, but as interpreter
  only: every number in its answer must come from the structured summary layer 1 produced.
  Camera/vision is a separate CV problem that must not block anything else.
  This CORRECTS my own section 2.1, which had banned an LLM from Coach Chat — an overreaction
  to the no-fabrication rule that would have removed AI from the one place it belongs.
  Security: API key must never ship in the Flutter binary. App -> Supabase Edge Function ->
  Claude API (claude-opus-5). Anthropic ships no Dart SDK, which reinforces the same shape.
  Cost if wrong: the Edge Function is extra infrastructure before Coach Chat can talk freely;
  the alternative leaks a key in every APK.
Task 5: complete (commits 78f4505..38c5f0a, review clean — spec ✅, quality Approved)
Task 5: minor (deferred): reviewer suggests "const on PcSectionHeader.build". Reads doubtful —
  the returned tree interpolates `title` and `actionLabel`, which are runtime fields, so the
  subtree cannot be const. Final review should confirm before anyone acts on it.
Task 6: complete (commits 38c5f0a..17324f9, review clean — spec ✅, quality Approved)
Task 6: reviewer's single minor is a misread — it flagged `AppSpacing.xs + 1` as deviating
  from the brief, but the brief itself specifies `AppSpacing.xs + 1`. Implementation matches.
  Not carried forward as a finding.
Task 6: controller verified 'Hạng' byte-correct in the committed blob; reviewer confirmed the
  report file does contain both RED/GREEN cycles despite the terse hand-back.
Task 7: implemented (commits 17324f9..ac65e21, 30/30 tests, analyze clean) — review pending
Task 7: report has a transcription error — its files-changed table lists app_theme.dart twice
  and omits app_typography.dart. Controller confirmed the real three files from the commit.
Task 7: controller is second-guessing its own decision 2 and asked the reviewer to rule on it
  independently. I told the implementer that google_fonts' font-load errors in `flutter test`
  are expected and forbade a GoogleFonts.config override. But this project's own standard is
  pristine test output, and `GoogleFonts.config.allowRuntimeFetching = false` in test setup is
  the normal clean fix. The review prompt invites the reviewer to overrule me rather than defer.
Infra note: the safety classifier went intermittently unavailable here, blocking writes and
  agent dispatches for several minutes. Reads kept working. No work lost — everything through
  task 7 was already committed.
Ruling 5 (user decision, after the classifier stayed down through four retries): switch tasks
  8, 9 and 10 from subagent-driven to inline execution. The controller writes the code and runs
  the tests itself. Task 7's review and the per-task reviews for 8-10 are DEFERRED, not skipped:
  when dispatch works again they fold into the final whole-branch review, which must therefore
  cover commits ac65e21..HEAD with full task-level scrutiny rather than the lighter pass a
  whole-branch review normally gives.
  Cost if wrong: four tasks reach merge having been read only by their author, so a defect that
  a fresh reviewer would have caught survives until the final review. Mitigated by TDD — each
  task's tests must go RED before GREEN — and by the smoke test in task 10.
Task 8: complete (commits ac65e21..7fb71dc, inline, 33/33 tests, analyze clean)
Task 8: deviation from plan — the notifications screen's empty-state icon is
  Icons.notifications_active_outlined, not the app bar's Icons.notifications_none. Identical
  icons made the navigation finder ambiguous and read as a repeat on screen.
Task 9: complete (commits 7fb71dc..6ace1bb, inline, 40/40 tests, analyze clean)
Task 9: REAL DEFECT found by the tests, fixed at the source. The plan declared `appRouter` as a
  top-level `final GoRouter`. GoRouter carries navigation state, so the singleton leaked position
  between tests — two tests failed because the previous one had left the app on /coach. Beyond
  tests it meant two app instances could never coexist. Fix: `createAppRouter()` factory, and
  PoolCoachApp became a StatefulWidget holding one router built in initState, with an optional
  injected router as the test seam. This is the kind of defect the plan's own code contained and
  only running it exposed.
Task 9: added a seventh navigation test beyond the plan's six — open Coach from the Training tab,
  go back, and land on Training rather than Home. It proves the per-tab stacks actually work,
  which is the whole reason for StatefulShellRoute.
Task 10: complete (commits 6ace1bb..0b8143d, inline, 43/43 tests, analyze clean, `flutter build
  web --release` succeeds)
Task 10: Ruling 2 applied — the plan's second smoke test asserted `find.byType(Text)` is
  non-empty, which cannot fail while the shell chrome is mounted. Replaced with a route-to-widget
  map plus a third test asserting the map covers Routes exactly, so a later plan that registers a
  path without a table entry fails loudly.

PLAN 1 COMPLETE — all 10 tasks, 43 tests, analyze clean, web build verified.
Outstanding: task 7's independent review and per-task reviews for 8-10 are deferred to the final
whole-branch review (Ruling 5). The final review must therefore cover ac65e21..HEAD at task-level
depth, and should also triage the deferred minors recorded above.
