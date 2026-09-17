# PoolCoachAI — Kế hoạch 2: Lớp suy luận (Player Intelligence + Recommendation)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng lớp suy luận thuần Dart — các hàm tính trình độ người chơi và chọn bài tập hôm nay — cùng kiểu dữ liệu và dữ liệu khởi tạo mà chúng cần. Không có màn hình nào trong kế hoạch này.

**Architecture:** Toàn bộ là pure function trong `lib/domain/`, không import Flutter, không phụ thuộc UI, không gọi mạng. Mỗi hàm nhận dữ liệu vào và trả kết quả ra, cùng đầu vào luôn cho cùng đầu ra. Đây là tầng 1 và tầng 3 của mục 2.2 tài liệu thiết kế; kế hoạch 3 dựng màn hình đọc kết quả từ đây.

**Tech Stack:** Dart thuần (không `package:flutter` trong `lib/domain/`), `flutter_test` để kiểm thử

**Spec:**
- `docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md` — mục 2.1 (cấm bịa), 2.2 (phân tầng AI), 5 (thuật ngữ)
- `Claude_desktop/PoolCoachAI_SPEC.md` — mục 3 (data model), 5 (công thức Player Intelligence), 6 (recommendation engine)
- `Claude_desktop/poolcoachai-reference.html` dòng 302–395 — seed data

## Global Constraints

- **Tìm Flutter trước khi chạy lệnh đầu tiên.** Trên máy đã dựng kế hoạch 1, Flutter **không** nằm trong PATH và ở `C:/Users/anhnpv/flutter/bin/flutter.bat` (bản 3.47.0); máy đó còn một bản cũ 3.44.6 ở `D:\flutter` **không được dùng**. Trên máy khác, đường dẫn sẽ khác — chạy `flutter --version` trước, nếu không có thì tìm `flutter.bat`, rồi đặt `FLUTTER=<đường dẫn tìm được>` và dùng biến đó cho mọi lệnh trong kế hoạch này. Yêu cầu tối thiểu: **Flutter 3.47.0 / Dart 3.13.0**.
- **`lib/domain/` không được import `package:flutter/...`.** Ngoại lệ duy nhất đang tồn tại là `skill_category.dart` (giữ màu nên phải import `material.dart`) — không thêm ngoại lệ mới. Lý do: các hàm này phải chạy được trong test thuần và sau này được lớp Coach gọi thẳng.
- **Mọi chuỗi tiếng Việt nằm trong `lib/core/strings/vi.dart`.** Dữ liệu seed là ngoại lệ có chủ đích: tên bài tập và nội dung kiến thức là *dữ liệu*, không phải nhãn giao diện, nên nằm trong file seed.
- **Thuật ngữ đã chốt, tuyệt đối không dùng lại bản cũ trong prototype:** Ngắm bi · **Điều bi / Vị trí** (không phải "Đi bi") · **Phá** (không phải "Giao bóng") · Phòng thủ · **A băng** = kick (không phải "Bi băng") · **Đánh đứng bi** (không phải "Stop shot"/"dừng bi") · **Đánh trô bi** (không phải "Draw"/"kéo bi") · **Đánh cu lê** (không phải "Follow"/"đẩy bi theo") · Chết cái · Bi ảo · Bi cái · **Cân bi** = bank.
- **Cấm bịa.** Mọi con số hiển thị về sau phải truy được về một hàm trong kế hoạch này. Thiếu dữ liệu thì trả `null`, không đoán.
- **Hằng số lấy nguyên từ spec**, không tự chỉnh: `MIN_SESSIONS = 3`, `RECENCY_DECAY = 0.85`, `WEAK_CUTOFF = 55`, `STRONG_CUTOFF = 75`, `READY_STREAK = 3`, trần ratio `1.2`, ngưỡng trend `±0.1`.
- **Mỗi commit phải để `flutter analyze` sạch và `flutter test` xanh.** Hiện có 43 test.
- Lint đang bật: `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `avoid_print`, `require_trailing_commas`, `sort_child_properties_last`.

---

## Quyết định phải chốt trước Task 2

**Drill `d8` trong prototype bị gắn sai nhóm.** Nó tên "Bi băng 1 băng vào lỗ", `cat:'kick'`, nhưng mục tiêu ghi *"đánh **bi mục tiêu** phản qua một băng rồi vào lỗ"* — đó là **bank shot (Cân bi)**, không phải kick. Chỉ `d9` mới đúng kick (bi cái phản băng để thoát chắn).

Ba lối, Task 2 phải chọn một và ghi lý do vào commit:

| Lối | Hệ quả |
|---|---|
| **A. Xếp d8 vào `aiming`** | Cân bi là bài toán ngắm (góc tới = góc phản xạ). Giữ đúng 5 nhóm. Hơi gượng vì nó không phải ngắm trực tiếp |
| **B. Mở nhóm thứ 6 `bank` = "Cân bi"** | Đúng về chuyên môn nhất. Nhưng phá vỡ bộ 5 mà cả PRD lẫn spec đều dùng, và phải thêm màu thứ 6 |
| **C. Giữ d8 ở `kick`, chỉ sửa tên và mô tả** | Ít việc nhất, nhưng để lại một bài sai nhóm — đúng loại nợ mà lớp suy luận sẽ khuếch đại: `weakestSkill()` sẽ quy lỗi Cân bi thành yếu A băng |

**Đề xuất: A.** Nó giữ bộ 5, và Cân bi thật sự là bài toán hình học phản xạ giống ngắm bi hơn là giống kick. Nhưng đây là câu hỏi chuyên môn — hỏi chủ sản phẩm trước khi code, và ghi câu trả lời vào `vi.dart` dưới dạng chú thích.

---

## Cấu trúc file

| File | Trách nhiệm |
|---|---|
| `lib/domain/drill.dart` | `Drill` — bài tập, có `passThreshold` hoặc `target`, không có cả hai |
| `lib/domain/drill_log.dart` | `DrillLog` — một lần ghi kết quả |
| `lib/domain/practice_constants.dart` | Năm hằng số của spec + trần ratio + ngưỡng trend |
| `lib/domain/drill_ratio.dart` | `drillRatio()` — quy đổi một log thành tỉ lệ đạt mục tiêu |
| `lib/domain/player_intelligence.dart` | `categoryMastery`, `categoryTrend`, `computePlayerIntelligence`, `isReadyForLevelUp`, và các kiểu kết quả |
| `lib/domain/recommendation.dart` | `pickDrillInCategory`, `pickCategoryForToday`, `computeRecommendation`, `TodayRecommendation` |
| `lib/domain/schedule_slot.dart` | `ScheduleSlot` — khung giờ tập hằng tuần |
| `lib/domain/timer_session.dart` | `TimerSession` — buổi tập tự do |
| `lib/domain/knowledge_article.dart` | `KnowledgeArticle` |
| `lib/data/seed/seed_drills.dart` | 10 bài tập, thuật ngữ đã sửa |
| `lib/data/seed/seed_knowledge.dart` | 6 bài kiến thức, thuật ngữ đã sửa |

Kế hoạch này **không** tạo `Cue`, repository, hay bất kỳ widget nào — chúng thuộc kế hoạch 3.

---

## Task 1: Kiểu dữ liệu bài tập và bản ghi

**Files:**
- Create: `lib/domain/drill.dart`, `lib/domain/drill_log.dart`
- Test: `test/domain/drill_test.dart`

**Interfaces:**
- Consumes: `SkillCategory` (đã có)
- Produces:
  - `Drill({required String id, required SkillCategory cat, required String name, required int level, required String unit, required String goal, required List<String> steps, double? passThreshold, num? target})` với getter `bool get usesAttempts => passThreshold != null`
  - `DrillLog({required String id, required String drillId, required DateTime date, required num score, int? attempts, String? notes})`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/drill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('Drill', () {
    test('bài chấm theo tỉ lệ thì usesAttempts là true', () {
      const drill = Drill(
        id: 'd1',
        cat: SkillCategory.aiming,
        name: 'Đường thẳng cơ bản',
        level: 1,
        unit: 'lần trúng / 10',
        goal: 'Đánh thẳng bi cái vào bi mục tiêu.',
        steps: ['Đặt bi.'],
        passThreshold: 0.8,
      );

      expect(drill.usesAttempts, isTrue);
    });

    test('bài chấm theo mục tiêu tuyệt đối thì usesAttempts là false', () {
      const drill = Drill(
        id: 'd4',
        cat: SkillCategory.position,
        name: 'Đánh trô bi',
        level: 3,
        unit: 'khoảng cách kéo (cm)',
        goal: 'Kéo bi cái lùi lại.',
        steps: ['Đánh 1/3 dưới bi cái.'],
        target: 25,
      );

      expect(drill.usesAttempts, isFalse);
    });

    test('không được đặt đồng thời passThreshold và target', () {
      expect(
        () => Drill(
          id: 'x',
          cat: SkillCategory.aiming,
          name: 'Sai',
          level: 1,
          unit: 'u',
          goal: 'g',
          steps: const [],
          passThreshold: 0.8,
          target: 10,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('phải đặt một trong hai', () {
      expect(
        () => Drill(
          id: 'x',
          cat: SkillCategory.aiming,
          name: 'Sai',
          level: 1,
          unit: 'u',
          goal: 'g',
          steps: const [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/drill_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/domain/drill.dart`.

- [ ] **Step 3: Viết drill.dart**

```dart
import 'package:poolcoachai/domain/skill_category.dart';

/// Một bài tập.
///
/// Cách chấm điểm quyết định bởi đúng **một** trong hai trường:
/// - [passThreshold] (0–1) cho bài đếm cú — log phải có `attempts`,
///   tỉ lệ đạt tính bằng `score / attempts` so với ngưỡng này.
/// - [target] cho bài đo bằng đơn vị khác — cm, giây, số lần trong
///   60 giây — log không có `attempts`, tỉ lệ tính bằng `score / target`.
///
/// Đặt cả hai hoặc không đặt gì đều là lỗi lập trình, nên dùng assert
/// chứ không im lặng chọn một cái.
class Drill {
  const Drill({
    required this.id,
    required this.cat,
    required this.name,
    required this.level,
    required this.unit,
    required this.goal,
    required this.steps,
    this.passThreshold,
    this.target,
  })  : assert(
          passThreshold == null || target == null,
          'Drill chỉ được có passThreshold hoặc target, không được cả hai',
        ),
        assert(
          passThreshold != null || target != null,
          'Drill phải có passThreshold hoặc target để chấm được điểm',
        );

  final String id;
  final SkillCategory cat;
  final String name;

  /// Cấp độ 1–5.
  final int level;

  /// Nhãn đơn vị hiển thị, ví dụ "lần trúng / 10" hay "khoảng cách kéo (cm)".
  final String unit;

  final String goal;
  final List<String> steps;

  /// Tỉ lệ thành công cần đạt, 0–1. Chỉ dùng cho bài có `attempts`.
  final double? passThreshold;

  /// Mục tiêu tuyệt đối. Chỉ dùng cho bài không có `attempts`.
  final num? target;

  /// Bài này chấm theo tỉ lệ thành công trên số lượt thử.
  bool get usesAttempts => passThreshold != null;
}
```

- [ ] **Step 4: Viết drill_log.dart**

```dart
/// Kết quả một lần thực hiện bài tập.
///
/// [attempts] có mặt khi bài chấm theo tỉ lệ (`Drill.passThreshold`),
/// vắng mặt khi bài chấm theo mục tiêu tuyệt đối (`Drill.target`).
class DrillLog {
  const DrillLog({
    required this.id,
    required this.drillId,
    required this.date,
    required this.score,
    this.attempts,
    this.notes,
  });

  final String id;
  final String drillId;
  final DateTime date;
  final num score;
  final int? attempts;
  final String? notes;
}
```

- [ ] **Step 5: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/domain/drill_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 4 test đạt, analyze sạch.

- [ ] **Step 6: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add drill and drill log domain types

A drill is scored by exactly one of passThreshold or target, and
asserting that keeps a malformed drill from silently picking one."
```

---

## Task 2: Dữ liệu khởi tạo — 10 bài tập, 6 bài kiến thức

**Files:**
- Create: `lib/domain/knowledge_article.dart`, `lib/data/seed/seed_drills.dart`, `lib/data/seed/seed_knowledge.dart`
- Test: `test/data/seed_test.dart`

**Interfaces:**
- Consumes: `Drill`, `SkillCategory`
- Produces: `KnowledgeArticle({required String id, required SkillCategory cat, required String title, required String body, List<String> relatedDrillIds = const []})`; `const seedDrills` (`List<Drill>`, 10 phần tử); `const seedKnowledge` (`List<KnowledgeArticle>`, 6 phần tử)

**Nguồn:** `Claude_desktop/poolcoachai-reference.html` dòng 310–395. Nội dung lấy nguyên, **thuật ngữ dịch lại** theo Global Constraints. Cụ thể phải đổi:

| Prototype | Dùng |
|---|---|
| `d3` "Stop shot — dừng bi cái" | **Đánh đứng bi** |
| `d4` "Draw — kéo bi cái" | **Đánh trô bi** |
| `d5` "Follow — đẩy bi cái theo" | **Đánh cu lê** |
| `d8` "Bi băng 1 băng vào lỗ" | **Cân bi một băng vào lỗ** |
| `d9` "Kick shot — thoát bi an toàn" | **A băng thoát chắn** |
| `d10` "Stop shot liên hoàn — tốc độ" | **Đánh đứng bi liên hoàn — tốc độ** |
| `k5` "...đánh bi băng" | **...A băng** |
| Mọi chỗ "giao bóng" trong `goal`/`steps`/`body` | **phá** |

- [ ] **Step 1: Chốt nhóm cho d8**

Hỏi chủ sản phẩm theo bảng "Quyết định phải chốt" ở đầu kế hoạch. Không tự chọn. Ghi câu trả lời thành chú thích ngay trên `d8` trong `seed_drills.dart`, kèm lý do.

- [ ] **Step 2: Viết test thất bại**

Tạo `test/data/seed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('dữ liệu khởi tạo', () {
    test('có đúng 10 bài tập và 6 bài kiến thức', () {
      expect(seedDrills.length, 10);
      expect(seedKnowledge.length, 6);
    });

    test('mã bài tập không trùng nhau', () {
      final ids = seedDrills.map((d) => d.id).toSet();
      expect(ids.length, seedDrills.length);
    });

    test('mỗi bài tập chấm được điểm', () {
      for (final drill in seedDrills) {
        expect(
          drill.passThreshold != null || drill.target != null,
          isTrue,
          reason: 'bài ${drill.id} không có cách chấm điểm',
        );
      }
    });

    test('cấp độ nằm trong 1..5', () {
      for (final drill in seedDrills) {
        expect(drill.level, inInclusiveRange(1, 5), reason: drill.id);
      }
    });

    test('mỗi bài tập có mục tiêu và ít nhất một bước', () {
      for (final drill in seedDrills) {
        expect(drill.goal.trim(), isNotEmpty, reason: drill.id);
        expect(drill.steps, isNotEmpty, reason: drill.id);
      }
    });

    test('không còn thuật ngữ cũ trong bất kỳ bài tập nào', () {
      const banned = [
        'Stop shot',
        'dừng bi',
        'Draw',
        'kéo bi',
        'Follow',
        'đẩy bi cái theo',
        'Bi băng',
        'Giao bóng',
        'giao bóng',
        'Đi bi',
      ];
      for (final drill in seedDrills) {
        final haystack =
            '${drill.name} ${drill.goal} ${drill.steps.join(' ')}';
        for (final term in banned) {
          expect(
            haystack.contains(term),
            isFalse,
            reason: 'bài ${drill.id} còn dùng "$term"',
          );
        }
      }
    });

    test('không còn thuật ngữ cũ trong bài kiến thức', () {
      const banned = ['Bi băng', 'Giao bóng', 'giao bóng', 'Đi bi'];
      for (final article in seedKnowledge) {
        final haystack = '${article.title} ${article.body}';
        for (final term in banned) {
          expect(
            haystack.contains(term),
            isFalse,
            reason: 'bài ${article.id} còn dùng "$term"',
          );
        }
      }
    });

    test('mỗi nhóm kỹ năng có ít nhất một bài tập', () {
      for (final cat in SkillCategory.values) {
        expect(
          seedDrills.any((d) => d.cat == cat),
          isTrue,
          reason: 'nhóm $cat chưa có bài nào',
        );
      }
    });
  });
}
```

- [ ] **Step 3: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/data/seed_test.dart
```

Kỳ vọng: FAIL — chưa có file seed.

- [ ] **Step 4: Viết knowledge_article.dart**

```dart
import 'package:poolcoachai/domain/skill_category.dart';

/// Một bài kiến thức.
///
/// Quan hệ với bài tập là hai chiều và **hỗ trợ, không phải phụ thuộc
/// cứng** — người chơi được đọc kiến thức độc lập, không cần mở khoá
/// qua bài tập nào.
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.cat,
    required this.title,
    required this.body,
    this.relatedDrillIds = const [],
  });

  final String id;
  final SkillCategory cat;
  final String title;
  final String body;
  final List<String> relatedDrillIds;
}
```

- [ ] **Step 5: Viết seed_drills.dart và seed_knowledge.dart**

Chép 10 bài tập và 6 bài kiến thức từ `poolcoachai-reference.html` dòng 310–395 sang Dart, giữ nguyên `id`, `level`, `unit`, `passThreshold`/`target`, `goal`, `steps`, `body`. Ánh xạ nhóm: `aim`→`SkillCategory.aiming`, `position`→`.position`, `brk`→`.breakShot`, `safety`→`.safety`, `kick`→`.kick`. Đổi thuật ngữ theo bảng ở đầu Task 2.

Đặt `const` cho cả hai danh sách.

- [ ] **Step 6: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/data/seed_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 8 test đạt, analyze sạch. Nếu test "không còn thuật ngữ cũ" hỏng, đó là nó làm đúng việc — sửa dữ liệu, đừng nới test.

- [ ] **Step 7: Commit**

```bash
git add lib/domain lib/data test/data
git commit -m "Add seed drills and knowledge articles

Content comes from the prototype; the terminology does not. The
prototype predates the corrections, so copying it verbatim would
reintroduce every wrong term. A test fails the build if any of them
comes back."
```

---

## Task 3: Hằng số và quy đổi log thành tỉ lệ

**Files:**
- Create: `lib/domain/practice_constants.dart`, `lib/domain/drill_ratio.dart`
- Test: `test/domain/drill_ratio_test.dart`

**Interfaces:**
- Consumes: `Drill`, `DrillLog`
- Produces: `PracticeConstants` với `minSessions`(3), `recencyDecay`(0.85), `weakCutoff`(55), `strongCutoff`(75), `readyStreak`(3), `ratioCap`(1.2), `trendThreshold`(0.1); `double? drillRatio(Drill drill, DrillLog log)`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/drill_ratio_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/skill_category.dart';

const _ratioDrill = Drill(
  id: 'd1',
  cat: SkillCategory.aiming,
  name: 'Đường thẳng cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.8,
);

const _targetDrill = Drill(
  id: 'd4',
  cat: SkillCategory.position,
  name: 'Đánh trô bi',
  level: 3,
  unit: 'cm',
  goal: 'g',
  steps: ['s'],
  target: 25,
);

DrillLog _log({required num score, int? attempts}) => DrillLog(
      id: 'l',
      drillId: 'd',
      date: DateTime(2026, 9, 17),
      score: score,
      attempts: attempts,
    );

void main() {
  group('drillRatio', () {
    test('đạt đúng ngưỡng cho ratio 1.0', () {
      // 8/10 = 0.8, ngưỡng 0.8 -> vừa đủ đạt
      expect(drillRatio(_ratioDrill, _log(score: 8, attempts: 10)), 1.0);
    });

    test('vượt ngưỡng cho ratio lớn hơn 1', () {
      // 10/10 = 1.0 chia 0.8 = 1.25
      expect(drillRatio(_ratioDrill, _log(score: 10, attempts: 10)), 1.25);
    });

    test('dưới ngưỡng cho ratio nhỏ hơn 1', () {
      // 4/10 = 0.4 chia 0.8 = 0.5
      expect(drillRatio(_ratioDrill, _log(score: 4, attempts: 10)), 0.5);
    });

    test('bài đo theo mục tiêu tuyệt đối chia cho target', () {
      expect(drillRatio(_targetDrill, _log(score: 25)), 1.0);
      expect(drillRatio(_targetDrill, _log(score: 50)), 2.0);
    });

    test('trả null khi bài cần attempts mà log không có', () {
      expect(drillRatio(_ratioDrill, _log(score: 8)), isNull);
    });

    test('trả null khi attempts bằng 0 — không chia cho 0', () {
      expect(drillRatio(_ratioDrill, _log(score: 0, attempts: 0)), isNull);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/drill_ratio_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `drill_ratio.dart`.

- [ ] **Step 3: Viết practice_constants.dart**

```dart
/// Hằng số của lớp suy luận.
///
/// Lấy nguyên từ Claude_desktop/PoolCoachAI_SPEC.md mục 5.1 — đã được
/// kiểm chứng ở prototype, không tự chỉnh.
abstract final class PracticeConstants {
  /// Số buổi tối thiểu trong một nhóm kỹ năng để dám kết luận về nó.
  static const minSessions = 3;

  /// Buổi càng cũ trọng số càng giảm, nhân dồn theo cấp số nhân.
  static const recencyDecay = 0.85;

  /// Dưới ngưỡng này coi là điểm yếu.
  static const weakCutoff = 55;

  /// Từ ngưỡng này trở lên coi là điểm mạnh.
  static const strongCutoff = 75;

  /// Số buổi đạt liên tiếp để coi là sẵn sàng lên cấp.
  static const readyStreak = 3;

  /// Trần khi đưa ratio vào tính mastery, tránh một buổi ăn may kéo
  /// điểm lên quá cao.
  static const ratioCap = 1.2;

  /// Chênh lệch tối thiểu giữa hai nửa để gọi là có xu hướng.
  static const trendThreshold = 0.1;
}
```

- [ ] **Step 4: Viết drill_ratio.dart**

```dart
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';

/// Quy đổi một lần ghi kết quả thành tỉ lệ đạt mục tiêu của bài đó.
///
/// `1.0` nghĩa là đạt đúng mục tiêu, lớn hơn là vượt, nhỏ hơn là chưa đạt.
/// Trả `null` khi không đủ thông tin để chấm — gọi là "chưa chấm được",
/// **không** quy về 0, vì thiếu dữ liệu khác hẳn với làm kém.
double? drillRatio(Drill drill, DrillLog log) {
  final threshold = drill.passThreshold;
  if (threshold != null) {
    final attempts = log.attempts;
    if (attempts == null || attempts == 0) return null;
    return (log.score / attempts) / threshold;
  }

  final target = drill.target;
  if (target == null || target == 0) return null;
  return log.score / target;
}
```

- [ ] **Step 5: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/domain/drill_ratio_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 6 test đạt, analyze sạch.

- [ ] **Step 6: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add practice constants and drill ratio

Insufficient data returns null rather than zero — not knowing how
someone did is not the same as them doing badly, and collapsing the
two would let the intelligence layer call a beginner weak."
```

---

## Task 4: Mastery và xu hướng theo nhóm kỹ năng

**Files:**
- Create: `lib/domain/player_intelligence.dart`
- Test: `test/domain/player_intelligence_test.dart`

**Interfaces:**
- Consumes: `PracticeConstants`, `drillRatio`, `Drill`, `DrillLog`, `SkillCategory`
- Produces:
  - `enum SkillTrend { up, down, flat, notEnoughData }`
  - `int? categoryMastery(List<double> ratiosOldestFirst)` — `null` khi ít hơn `minSessions`
  - `SkillTrend categoryTrend(List<double> ratiosOldestFirst)` — `notEnoughData` khi ít hơn 4

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/player_intelligence_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';

void main() {
  group('categoryMastery', () {
    test('trả null khi chưa đủ số buổi tối thiểu', () {
      expect(categoryMastery([1.0, 1.0]), isNull);
    });

    test('toàn buổi đạt đúng mục tiêu cho 100', () {
      expect(categoryMastery([1.0, 1.0, 1.0]), 100);
    });

    test('bị chặn trên ở 100 dù có buổi vượt mục tiêu', () {
      expect(categoryMastery([1.2, 1.2, 1.2]), 100);
    });

    test('buổi mới có trọng số cao hơn buổi cũ', () {
      // Cùng bộ số, đảo thứ tự: bản có buổi tốt ở cuối phải cao hơn.
      final improving = categoryMastery([0.4, 0.6, 1.0])!;
      final declining = categoryMastery([1.0, 0.6, 0.4])!;
      expect(improving, greaterThan(declining));
    });

    test('một buổi ăn may bị chặn ở trần 1.2', () {
      final capped = categoryMastery([0.5, 0.5, 5.0])!;
      final atCap = categoryMastery([0.5, 0.5, 1.2])!;
      expect(capped, atCap);
    });
  });

  group('categoryTrend', () {
    test('cần ít nhất 4 buổi mới dám kết luận xu hướng', () {
      expect(categoryTrend([0.2, 0.5, 0.9]), SkillTrend.notEnoughData);
    });

    test('nửa sau tốt hơn hẳn nửa trước là đi lên', () {
      expect(categoryTrend([0.3, 0.3, 0.9, 0.9]), SkillTrend.up);
    });

    test('nửa sau kém hơn hẳn nửa trước là đi xuống', () {
      expect(categoryTrend([0.9, 0.9, 0.3, 0.3]), SkillTrend.down);
    });

    test('chênh lệch nhỏ hơn ngưỡng là đi ngang', () {
      expect(categoryTrend([0.5, 0.5, 0.55, 0.55]), SkillTrend.flat);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/player_intelligence_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `player_intelligence.dart`.

- [ ] **Step 3: Viết phần đầu player_intelligence.dart**

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/practice_constants.dart';

/// Xu hướng của một nhóm kỹ năng theo thời gian.
enum SkillTrend {
  up,
  down,
  flat,

  /// Chưa đủ buổi để dám kết luận. Không phải "đi ngang" — khác hẳn.
  notEnoughData,
}

/// Điểm thành thạo 0–100 của một nhóm kỹ năng.
///
/// Nhận danh sách tỉ lệ đạt mục tiêu, **cũ nhất trước**. Buổi càng mới
/// trọng số càng cao theo cấp số nhân [PracticeConstants.recencyDecay],
/// nên tiến bộ gần đây được phản ánh nhanh hơn thành tích cũ.
///
/// Trả `null` khi số buổi ít hơn [PracticeConstants.minSessions] — chưa
/// đủ dữ liệu thì không kết luận, tuyệt đối không suy diễn.
int? categoryMastery(List<double> ratiosOldestFirst) {
  if (ratiosOldestFirst.length < PracticeConstants.minSessions) return null;

  final newestFirst = ratiosOldestFirst.reversed.toList();
  var weightSum = 0.0;
  var valueSum = 0.0;

  for (var i = 0; i < newestFirst.length; i++) {
    final weight = math.pow(PracticeConstants.recencyDecay, i).toDouble();
    weightSum += weight;
    valueSum += weight * math.min(PracticeConstants.ratioCap, newestFirst[i]);
  }

  return (math.min(1.0, valueSum / weightSum) * 100).round();
}

/// Xu hướng: so trung bình nửa buổi gần đây với nửa buổi trước đó.
///
/// Cần ít nhất 4 buổi — với 3 buổi trở xuống, chia đôi không còn ý nghĩa
/// thống kê và một buổi lệch sẽ quyết định cả kết luận.
SkillTrend categoryTrend(List<double> ratiosOldestFirst) {
  final n = ratiosOldestFirst.length;
  if (n < 4) return SkillTrend.notEnoughData;

  final half = n ~/ 2;

  double average(Iterable<double> values) {
    var sum = 0.0;
    for (final v in values) {
      sum += math.min(PracticeConstants.ratioCap, v);
    }
    return sum / values.length;
  }

  final recent = average(ratiosOldestFirst.skip(n - half));
  final earlier = average(ratiosOldestFirst.take(half));
  final diff = recent - earlier;

  if (diff > PracticeConstants.trendThreshold) return SkillTrend.up;
  if (diff < -PracticeConstants.trendThreshold) return SkillTrend.down;
  return SkillTrend.flat;
}
```

- [ ] **Step 4: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/domain/player_intelligence_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 9 test đạt, analyze sạch.

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add mastery scoring and trend detection

Recency weighting means recent progress moves the score faster than
old results hold it back, and the 1.2 cap stops one lucky session
from carrying a category.

Both return an explicit not-enough-data answer rather than a
confident-looking number, so the UI can say so instead of guessing."
```

---

## Task 5: Sẵn sàng lên cấp và kết quả tổng hợp

**Files:**
- Modify: `lib/domain/player_intelligence.dart`
- Test: `test/domain/player_intelligence_summary_test.dart`

**Interfaces:**
- Consumes: mọi thứ từ Task 4
- Produces:
  - `CategoryInsight({int? mastery, required SkillTrend trend, required int sessionCount})`
  - `PlayerIntelligence({required Map<SkillCategory, CategoryInsight> categories, required List<SkillCategory> weak, required List<SkillCategory> strong, required List<String> readyDrillIds, required bool hasAnyData})`
  - `bool isReadyForLevelUp(Drill drill, List<DrillLog> logsOldestFirst)`
  - `PlayerIntelligence computePlayerIntelligence({required List<Drill> drills, required List<DrillLog> logs})`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/player_intelligence_summary_test.dart` với các case bắt buộc của spec mục 5.8:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/skill_category.dart';

const _d1 = Drill(
  id: 'd1',
  cat: SkillCategory.aiming,
  name: 'Đường thẳng cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.8,
);

const _d7 = Drill(
  id: 'd7',
  cat: SkillCategory.safety,
  name: 'Đẩy sát băng',
  level: 2,
  unit: 'lần thành công / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.7,
);

DrillLog _log(String drillId, int day, num score, int attempts) => DrillLog(
      id: '$drillId-$day',
      drillId: drillId,
      date: DateTime(2026, 9, day),
      score: score,
      attempts: attempts,
    );

void main() {
  group('computePlayerIntelligence — case bắt buộc của spec', () {
    test('d1 với 8,9,9,10 trên 10 cho điểm cao, xu hướng lên, là điểm mạnh', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1],
        logs: [
          _log('d1', 1, 8, 10),
          _log('d1', 2, 9, 10),
          _log('d1', 3, 9, 10),
          _log('d1', 4, 10, 10),
        ],
      );

      final insight = pi.categories[SkillCategory.aiming]!;
      expect(insight.mastery, isNotNull);
      expect(insight.mastery!, greaterThanOrEqualTo(75));
      expect(insight.trend, SkillTrend.up);
      expect(pi.strong, contains(SkillCategory.aiming));
      expect(pi.weak, isNot(contains(SkillCategory.aiming)));
    });

    test('d7 với 3,4,4 trên 10 cho điểm quanh 53, là điểm yếu', () {
      final pi = computePlayerIntelligence(
        drills: const [_d7],
        logs: [
          _log('d7', 1, 3, 10),
          _log('d7', 2, 4, 10),
          _log('d7', 3, 4, 10),
        ],
      );

      final insight = pi.categories[SkillCategory.safety]!;
      expect(insight.mastery, inInclusiveRange(48, 58));
      expect(pi.weak, contains(SkillCategory.safety));
    });

    test('d1 đạt 3 buổi cuối liên tiếp nên nằm trong readyDrillIds', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1],
        logs: [
          _log('d1', 1, 5, 10),
          _log('d1', 2, 8, 10),
          _log('d1', 3, 9, 10),
          _log('d1', 4, 10, 10),
        ],
      );

      expect(pi.readyDrillIds, contains('d1'));
    });

    test('nhóm chưa đủ dữ liệu thì mastery null và trend notEnoughData', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1],
        logs: [_log('d1', 1, 8, 10)],
      );

      final insight = pi.categories[SkillCategory.aiming]!;
      expect(insight.mastery, isNull);
      expect(insight.trend, SkillTrend.notEnoughData);
      expect(insight.sessionCount, 1);
      expect(pi.weak, isEmpty);
      expect(pi.strong, isEmpty);
    });

    test('không có log nào thì hasAnyData là false', () {
      final pi = computePlayerIntelligence(drills: const [_d1], logs: const []);
      expect(pi.hasAnyData, isFalse);
    });

    test('mọi nhóm kỹ năng đều có mặt trong kết quả, kể cả khi chưa tập', () {
      final pi = computePlayerIntelligence(drills: const [_d1], logs: const []);
      expect(pi.categories.keys.toSet(), SkillCategory.values.toSet());
    });

    test('weak sắp xếp tăng dần theo mastery', () {
      final pi = computePlayerIntelligence(
        drills: const [_d1, _d7],
        logs: [
          _log('d1', 1, 4, 10),
          _log('d1', 2, 4, 10),
          _log('d1', 3, 4, 10),
          _log('d7', 1, 2, 10),
          _log('d7', 2, 2, 10),
          _log('d7', 3, 2, 10),
        ],
      );

      expect(pi.weak.length, 2);
      final first = pi.categories[pi.weak.first]!.mastery!;
      final second = pi.categories[pi.weak.last]!.mastery!;
      expect(first, lessThanOrEqualTo(second));
    });
  });

  group('isReadyForLevelUp', () {
    test('chưa đủ số buổi liên tiếp thì chưa sẵn sàng', () {
      expect(
        isReadyForLevelUp(_d1, [_log('d1', 1, 10, 10), _log('d1', 2, 10, 10)]),
        isFalse,
      );
    });

    test('ba buổi cuối đều đạt thì sẵn sàng', () {
      expect(
        isReadyForLevelUp(_d1, [
          _log('d1', 1, 2, 10),
          _log('d1', 2, 8, 10),
          _log('d1', 3, 9, 10),
          _log('d1', 4, 10, 10),
        ]),
        isTrue,
      );
    });

    test('một buổi trong ba buổi cuối chưa đạt thì chưa sẵn sàng', () {
      expect(
        isReadyForLevelUp(_d1, [
          _log('d1', 1, 10, 10),
          _log('d1', 2, 5, 10),
          _log('d1', 3, 10, 10),
        ]),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/player_intelligence_summary_test.dart
```

Kỳ vọng: FAIL — `computePlayerIntelligence` chưa tồn tại.

- [ ] **Step 3: Bổ sung vào player_intelligence.dart**

Thêm import `drill.dart`, `drill_log.dart`, `drill_ratio.dart`, `skill_category.dart`, rồi thêm:

```dart
/// Kết luận về một nhóm kỹ năng.
class CategoryInsight {
  const CategoryInsight({
    required this.mastery,
    required this.trend,
    required this.sessionCount,
  });

  /// 0–100, hoặc `null` khi chưa đủ dữ liệu để kết luận.
  final int? mastery;

  final SkillTrend trend;

  /// Số buổi đã chấm được điểm trong nhóm này.
  final int sessionCount;
}

/// Bức tranh trình độ người chơi, tính hoàn toàn bằng công thức xác định.
///
/// Đây là object mà lớp Coach (LLM) sẽ nhận làm ngữ cảnh ở giai đoạn sau.
/// LLM **chỉ được đọc** các con số ở đây, không bao giờ tự tính lại —
/// xem mục 2.2 tài liệu thiết kế.
class PlayerIntelligence {
  const PlayerIntelligence({
    required this.categories,
    required this.weak,
    required this.strong,
    required this.readyDrillIds,
    required this.hasAnyData,
  });

  /// Mọi nhóm kỹ năng đều có mặt, kể cả nhóm chưa tập buổi nào.
  final Map<SkillCategory, CategoryInsight> categories;

  /// Nhóm dưới ngưỡng yếu, sắp xếp tăng dần — yếu nhất đứng đầu.
  final List<SkillCategory> weak;

  /// Nhóm từ ngưỡng mạnh trở lên, sắp xếp giảm dần.
  final List<SkillCategory> strong;

  /// Bài tập đã đủ điều kiện mở cấp tiếp theo.
  final List<String> readyDrillIds;

  /// Đã có bất kỳ buổi tập nào chưa.
  final bool hasAnyData;
}

/// Đã đủ điều kiện mở cấp tiếp theo của bài này chưa.
///
/// Yêu cầu [PracticeConstants.readyStreak] buổi gần nhất đều đạt mục
/// tiêu. Đây là cổng cho Skill Test ở giai đoạn sau: người chơi **không**
/// được tự bấm "hoàn thành cấp" để mở cấp kế tiếp.
bool isReadyForLevelUp(Drill drill, List<DrillLog> logsOldestFirst) {
  if (logsOldestFirst.length < PracticeConstants.readyStreak) return false;

  final lastN = logsOldestFirst
      .sublist(logsOldestFirst.length - PracticeConstants.readyStreak)
      .map((log) => drillRatio(drill, log));

  return lastN.every((ratio) => ratio != null && ratio >= 1);
}

/// Tính toàn bộ bức tranh trình độ từ danh sách bài tập và bản ghi.
PlayerIntelligence computePlayerIntelligence({
  required List<Drill> drills,
  required List<DrillLog> logs,
}) {
  final drillById = {for (final d in drills) d.id: d};

  final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));

  final ratiosByCategory = <SkillCategory, List<double>>{
    for (final cat in SkillCategory.values) cat: <double>[],
  };
  final logsByDrill = <String, List<DrillLog>>{};

  for (final log in sorted) {
    final drill = drillById[log.drillId];
    if (drill == null) continue;

    logsByDrill.putIfAbsent(log.drillId, () => <DrillLog>[]).add(log);

    final ratio = drillRatio(drill, log);
    if (ratio != null) ratiosByCategory[drill.cat]!.add(ratio);
  }

  final categories = <SkillCategory, CategoryInsight>{};
  for (final cat in SkillCategory.values) {
    final ratios = ratiosByCategory[cat]!;
    categories[cat] = CategoryInsight(
      mastery: categoryMastery(ratios),
      trend: categoryTrend(ratios),
      sessionCount: ratios.length,
    );
  }

  final scored = categories.entries
      .where((e) => e.value.mastery != null)
      .toList();

  final weak = scored
      .where((e) => e.value.mastery! < PracticeConstants.weakCutoff)
      .toList()
    ..sort((a, b) => a.value.mastery!.compareTo(b.value.mastery!));

  final strong = scored
      .where((e) => e.value.mastery! >= PracticeConstants.strongCutoff)
      .toList()
    ..sort((a, b) => b.value.mastery!.compareTo(a.value.mastery!));

  final readyDrillIds = <String>[];
  for (final entry in logsByDrill.entries) {
    final drill = drillById[entry.key];
    if (drill == null) continue;
    if (isReadyForLevelUp(drill, entry.value)) readyDrillIds.add(entry.key);
  }
  readyDrillIds.sort();

  return PlayerIntelligence(
    categories: categories,
    weak: weak.map((e) => e.key).toList(),
    strong: strong.map((e) => e.key).toList(),
    readyDrillIds: readyDrillIds,
    hasAnyData: logsByDrill.isNotEmpty,
  );
}
```

- [ ] **Step 4: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả đạt, analyze sạch.

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add level-up readiness and the intelligence summary

Level-up is a computed gate, not a button: three consecutive
sessions at target. A player cannot self-declare a level complete.

Every category appears in the result even with no sessions, so a
screen reads one shape whether or not the player has trained."
```

---

## Task 6: Chọn bài tập trong một nhóm

**Files:**
- Create: `lib/domain/recommendation.dart`
- Test: `test/domain/pick_drill_test.dart`

**Interfaces:**
- Consumes: `Drill`, `DrillLog`, `drillRatio`, `SkillCategory`
- Produces: `Drill? pickDrillInCategory({required SkillCategory cat, required List<Drill> drills, required Map<String, List<DrillLog>> logsByDrillOldestFirst, required Set<String> excludeDrillIds})`

Luật, theo spec mục 6.2 — duyệt bài trong nhóm theo cấp tăng dần, bỏ qua bài đã tập hôm nay:
1. Bài chưa từng tập → chọn ngay
2. Bài mà lần gần nhất chưa đạt (ratio `null` hoặc `< 1`) → chọn
3. Đã đạt hết → chọn bài cấp cao nhất để giữ phong độ
4. Không còn bài nào → `null`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/pick_drill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

Drill _drill(String id, int level) => Drill(
      id: id,
      cat: SkillCategory.aiming,
      name: 'Bài $id',
      level: level,
      unit: 'lần trúng / 10',
      goal: 'g',
      steps: const ['s'],
      passThreshold: 0.8,
    );

DrillLog _log(String drillId, num score) => DrillLog(
      id: '$drillId-log',
      drillId: drillId,
      date: DateTime(2026, 9, 1),
      score: score,
      attempts: 10,
    );

void main() {
  group('pickDrillInCategory', () {
    final low = _drill('a', 1);
    final high = _drill('b', 3);

    test('ưu tiên bài chưa từng tập, cấp thấp trước', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [high, low],
        logsByDrillOldestFirst: const {},
        excludeDrillIds: const {},
      );

      expect(picked?.id, 'a');
    });

    test('bài lần gần nhất chưa đạt thì vẫn cần tập lại', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [low, high],
        logsByDrillOldestFirst: {
          'a': [_log('a', 4)],
        },
        excludeDrillIds: const {},
      );

      expect(picked?.id, 'a');
    });

    test('đã đạt hết thì ôn bài cấp cao nhất', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [low, high],
        logsByDrillOldestFirst: {
          'a': [_log('a', 10)],
          'b': [_log('b', 10)],
        },
        excludeDrillIds: const {},
      );

      expect(picked?.id, 'b');
    });

    test('không gợi ý lại bài đã tập hôm nay', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [low, high],
        logsByDrillOldestFirst: const {},
        excludeDrillIds: const {'a'},
      );

      expect(picked?.id, 'b');
    });

    test('nhóm không còn bài nào thì trả null', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.safety,
        drills: [low, high],
        logsByDrillOldestFirst: const {},
        excludeDrillIds: const {},
      );

      expect(picked, isNull);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/pick_drill_test.dart
```

Kỳ vọng: FAIL — `recommendation.dart` chưa tồn tại.

- [ ] **Step 3: Viết recommendation.dart**

```dart
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Chọn bài tập nên tập trong một nhóm kỹ năng.
///
/// Duyệt theo cấp tăng dần và chọn bài đầu tiên còn cần tập: chưa từng
/// tập, hoặc lần gần nhất chưa đạt mục tiêu. Nếu đã đạt hết thì trả bài
/// cấp cao nhất để giữ phong độ.
///
/// [excludeDrillIds] là các bài đã tập trong hôm nay — không gợi ý lại
/// đúng bài người chơi vừa làm xong.
Drill? pickDrillInCategory({
  required SkillCategory cat,
  required List<Drill> drills,
  required Map<String, List<DrillLog>> logsByDrillOldestFirst,
  required Set<String> excludeDrillIds,
}) {
  final candidates = drills
      .where((d) => d.cat == cat && !excludeDrillIds.contains(d.id))
      .toList()
    ..sort((a, b) => a.level.compareTo(b.level));

  if (candidates.isEmpty) return null;

  for (final drill in candidates) {
    final logs = logsByDrillOldestFirst[drill.id];
    if (logs == null || logs.isEmpty) return drill;

    final lastRatio = drillRatio(drill, logs.last);
    if (lastRatio == null || lastRatio < 1) return drill;
  }

  return candidates.last;
}
```

- [ ] **Step 4: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/domain/pick_drill_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 5 test đạt, analyze sạch.

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add drill selection within a category"
```

---

## Task 7: Chọn nhóm kỹ năng cho hôm nay — 6 luật ưu tiên

**Files:**
- Create: `lib/domain/schedule_slot.dart`, `lib/domain/timer_session.dart`
- Modify: `lib/domain/recommendation.dart`
- Test: `test/domain/pick_category_test.dart`

**Interfaces:**
- Produces:
  - `ScheduleSlot({required String id, required int day, required String time, required String label, SkillCategory? cat})` — `day` 0 = Thứ 2 … 6 = Chủ nhật
  - `TimerSession({required String id, required DateTime date, required int durationSec, SkillCategory? cat, String? cueId})`
  - `enum PickReason { scheduled, streakAtRisk, weakest, newcomer, declining, rotation }`
  - `({SkillCategory cat, PickReason reason}) pickCategoryForToday({required PlayerIntelligence pi, required List<Drill> drills, required List<DrillLog> logs, required List<TimerSession> timerSessions, required List<ScheduleSlot> schedule, required DateTime today})`

Sáu luật theo spec mục 6.1, **luật khớp đầu tiên thắng**:

| # | Luật | Vì sao đứng ở vị trí đó |
|---|---|---|
| 1 | Lịch hôm nay có gắn nhóm cụ thể | Ý định tường minh của người chơi luôn thắng luật tự động |
| 2 | Sắp mất streak — hôm nay và hôm qua đều trống, nhưng trước đó đã có dữ liệu | Chọn nhóm có **ít lượt log nhất** (dễ nhất). Mục tiêu là kéo người quay lại tập, chưa phải sửa điểm yếu |
| 3 | Có nhóm đang yếu | Lấy `pi.weak.first` |
| 4 | Người mới, chưa có dữ liệu ở nhóm nào | Thứ tự làm quen cố định: `aiming → position → breakShot → safety → kick`, chọn nhóm đầu tiên chưa từng log |
| 5 | Có nhóm đang đi xuống dù chưa tới ngưỡng yếu | Ôn lại trước khi thành điểm yếu |
| 6 | Mặc định | Nhóm có ngày log gần nhất xa nhất trong quá khứ — tránh dồn vào một hai nhóm |

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/pick_category_test.dart`. Ba case bắt buộc của spec mục 6.6 cộng ba case cho các luật còn lại:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

final _today = DateTime(2026, 9, 17); // Thứ Năm -> day index 3

Drill _drill(String id, SkillCategory cat) => Drill(
      id: id,
      cat: cat,
      name: 'Bài $id',
      level: 1,
      unit: 'lần trúng / 10',
      goal: 'g',
      steps: const ['s'],
      passThreshold: 0.8,
    );

DrillLog _log(String drillId, DateTime date, num score) => DrillLog(
      id: '$drillId-${date.day}',
      drillId: drillId,
      date: date,
      score: score,
      attempts: 10,
    );

final _drills = [
  _drill('aim1', SkillCategory.aiming),
  _drill('pos1', SkillCategory.position),
  _drill('brk1', SkillCategory.breakShot),
  _drill('saf1', SkillCategory.safety),
  _drill('kic1', SkillCategory.kick),
];

({SkillCategory cat, PickReason reason}) _pick({
  List<DrillLog> logs = const [],
  List<ScheduleSlot> schedule = const [],
  List<TimerSession> timers = const [],
}) {
  final pi = computePlayerIntelligence(drills: _drills, logs: logs);
  return pickCategoryForToday(
    pi: pi,
    drills: _drills,
    logs: logs,
    timerSessions: timers,
    schedule: schedule,
    today: _today,
  );
}

void main() {
  group('pickCategoryForToday', () {
    test('case A — chưa có log nào thì theo thứ tự làm quen, bắt đầu Ngắm bi',
        () {
      final result = _pick();
      expect(result.cat, SkillCategory.aiming);
      expect(result.reason, PickReason.newcomer);
    });

    test('case B — sắp mất streak thắng luật điểm yếu', () {
      // Có log cũ (5 ngày trước) cho thấy Phòng thủ rất yếu, nhưng hôm
      // nay và hôm qua đều trống -> phải ưu tiên kéo người quay lại.
      final old = _today.subtract(const Duration(days: 5));
      final result = _pick(
        logs: [
          _log('saf1', old, 2),
          _log('saf1', old.add(const Duration(days: 1)), 2),
          _log('saf1', old.add(const Duration(days: 2)), 2),
        ],
      );

      expect(result.reason, PickReason.streakAtRisk);
    });

    test('case C — lịch hôm nay thắng mọi luật khác', () {
      final old = _today.subtract(const Duration(days: 5));
      final result = _pick(
        logs: [
          _log('saf1', old, 2),
          _log('saf1', old.add(const Duration(days: 1)), 2),
          _log('saf1', old.add(const Duration(days: 2)), 2),
        ],
        schedule: [
          const ScheduleSlot(
            id: 's1',
            day: 3, // Thứ Năm
            time: '19:00',
            label: 'Tập tối',
            cat: SkillCategory.breakShot,
          ),
        ],
      );

      expect(result.cat, SkillCategory.breakShot);
      expect(result.reason, PickReason.scheduled);
    });

    test('có tập hôm qua nên không tính là sắp mất streak, chọn nhóm yếu nhất',
        () {
      final yesterday = _today.subtract(const Duration(days: 1));
      final result = _pick(
        logs: [
          _log('saf1', yesterday.subtract(const Duration(days: 2)), 2),
          _log('saf1', yesterday.subtract(const Duration(days: 1)), 2),
          _log('saf1', yesterday, 2),
        ],
      );

      expect(result.cat, SkillCategory.safety);
      expect(result.reason, PickReason.weakest);
    });

    test('lịch hôm nay không gắn nhóm thì không kích hoạt luật 1', () {
      final result = _pick(
        schedule: [
          const ScheduleSlot(
            id: 's1',
            day: 3,
            time: '19:00',
            label: 'Tập tự do',
          ),
        ],
      );

      expect(result.reason, isNot(PickReason.scheduled));
    });

    test('lịch của thứ khác không ảnh hưởng hôm nay', () {
      final result = _pick(
        schedule: [
          const ScheduleSlot(
            id: 's1',
            day: 0, // Thứ Hai, hôm nay là Thứ Năm
            time: '19:00',
            label: 'Tập tối',
            cat: SkillCategory.kick,
          ),
        ],
      );

      expect(result.reason, isNot(PickReason.scheduled));
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/pick_category_test.dart
```

Kỳ vọng: FAIL — `schedule_slot.dart` và `pickCategoryForToday` chưa tồn tại.

- [ ] **Step 3: Viết schedule_slot.dart**

```dart
import 'package:poolcoachai/domain/skill_category.dart';

/// Một khung giờ trong lịch tập hằng tuần.
class ScheduleSlot {
  const ScheduleSlot({
    required this.id,
    required this.day,
    required this.time,
    required this.label,
    this.cat,
  }) : assert(day >= 0 && day <= 6, 'day phải trong 0..6');

  final String id;

  /// 0 = Thứ Hai … 6 = Chủ nhật.
  final int day;

  /// Giờ bắt đầu dạng "HH:MM".
  final String time;

  final String label;

  /// Nhóm kỹ năng dự định tập. Có thì đây là ý định tường minh của
  /// người chơi và thắng mọi luật gợi ý tự động.
  final SkillCategory? cat;
}
```

- [ ] **Step 4: Viết timer_session.dart**

```dart
import 'package:poolcoachai/domain/skill_category.dart';

/// Một buổi tập tự do đo bằng đồng hồ, không gắn bài tập nào.
///
/// Khác hẳn một buổi tập theo bài: không có mục tiêu, không có đạt hay
/// trượt. Nó chỉ tính vào tổng giờ tập và chuỗi ngày liên tiếp.
class TimerSession {
  const TimerSession({
    required this.id,
    required this.date,
    required this.durationSec,
    this.cat,
    this.cueId,
  });

  final String id;
  final DateTime date;
  final int durationSec;
  final SkillCategory? cat;
  final String? cueId;
}
```

- [ ] **Step 5: Bổ sung pickCategoryForToday vào recommendation.dart**

```dart
/// Vì sao nhóm kỹ năng này được chọn cho hôm nay.
///
/// Lý do đi kèm lựa chọn để màn hình giải thích được cho người chơi
/// thay vì chỉ đưa ra một mệnh lệnh không rõ nguồn gốc.
enum PickReason {
  /// Lịch tập hôm nay đã gắn sẵn nhóm này.
  scheduled,

  /// Hôm nay và hôm qua đều chưa tập — ưu tiên kéo người chơi quay lại.
  streakAtRisk,

  /// Nhóm yếu nhất hiện tại.
  weakest,

  /// Người mới, đi theo thứ tự làm quen.
  newcomer,

  /// Nhóm đang đi xuống dù chưa tới ngưỡng yếu.
  declining,

  /// Không luật nào khớp — luân phiên nhóm lâu chưa đụng tới.
  rotation,
}

/// Thứ tự làm quen cho người mới.
const _newcomerOrder = <SkillCategory>[
  SkillCategory.aiming,
  SkillCategory.position,
  SkillCategory.breakShot,
  SkillCategory.safety,
  SkillCategory.kick,
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Chọn nhóm kỹ năng nên tập hôm nay, kèm lý do.
///
/// Sáu luật xét theo thứ tự, luật khớp đầu tiên thắng — xem
/// Claude_desktop/PoolCoachAI_SPEC.md mục 6.1.
({SkillCategory cat, PickReason reason}) pickCategoryForToday({
  required PlayerIntelligence pi,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<TimerSession> timerSessions,
  required List<ScheduleSlot> schedule,
  required DateTime today,
}) {
  final drillById = {for (final d in drills) d.id: d};

  // Luật 1 — lịch hôm nay có gắn nhóm cụ thể.
  final todayIndex = today.weekday - 1; // DateTime.monday == 1
  for (final slot in schedule) {
    final cat = slot.cat;
    if (slot.day == todayIndex && cat != null) {
      return (cat: cat, reason: PickReason.scheduled);
    }
  }

  final yesterday = today.subtract(const Duration(days: 1));
  final activeDates = <DateTime>[
    ...logs.map((l) => l.date),
    ...timerSessions.map((t) => t.date),
  ];
  final activeTodayOrYesterday = activeDates
      .any((d) => _sameDay(d, today) || _sameDay(d, yesterday));

  // Luật 2 — sắp mất streak.
  if (!activeTodayOrYesterday && activeDates.isNotEmpty) {
    final counts = <SkillCategory, int>{
      for (final cat in SkillCategory.values) cat: 0,
    };
    for (final log in logs) {
      final drill = drillById[log.drillId];
      if (drill != null) counts[drill.cat] = counts[drill.cat]! + 1;
    }
    final easiest = counts.entries.reduce(
      (a, b) => b.value < a.value ? b : a,
    );
    return (cat: easiest.key, reason: PickReason.streakAtRisk);
  }

  // Luật 3 — có nhóm đang yếu.
  if (pi.weak.isNotEmpty) {
    return (cat: pi.weak.first, reason: PickReason.weakest);
  }

  // Luật 4 — người mới.
  if (!pi.hasAnyData) {
    for (final cat in _newcomerOrder) {
      if (pi.categories[cat]!.sessionCount == 0) {
        return (cat: cat, reason: PickReason.newcomer);
      }
    }
  }

  // Luật 5 — có nhóm đang đi xuống.
  for (final cat in SkillCategory.values) {
    if (pi.categories[cat]!.trend == SkillTrend.down) {
      return (cat: cat, reason: PickReason.declining);
    }
  }

  // Luật 6 — luân phiên nhóm lâu chưa đụng tới.
  final lastTouched = <SkillCategory, DateTime?>{
    for (final cat in SkillCategory.values) cat: null,
  };
  for (final log in logs) {
    final drill = drillById[log.drillId];
    if (drill == null) continue;
    final current = lastTouched[drill.cat];
    if (current == null || log.date.isAfter(current)) {
      lastTouched[drill.cat] = log.date;
    }
  }

  SkillCategory oldest = SkillCategory.values.first;
  DateTime? oldestDate;
  for (final cat in SkillCategory.values) {
    final date = lastTouched[cat];
    if (date == null) return (cat: cat, reason: PickReason.rotation);
    if (oldestDate == null || date.isBefore(oldestDate)) {
      oldest = cat;
      oldestDate = date;
    }
  }

  return (cat: oldest, reason: PickReason.rotation);
}
```

Thêm các import cần thiết vào đầu `recommendation.dart`: `player_intelligence.dart`, `schedule_slot.dart`, `timer_session.dart`.

- [ ] **Step 6: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả đạt, analyze sạch.

- [ ] **Step 7: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add today's category selection with six priority rules

Order matters and is not arbitrary. An explicit schedule entry
beats every automatic rule, because the player already said what
they want. A broken streak beats a weak skill, because getting
someone back to the table matters more than what they practise when
they arrive.

Each pick carries its reason so a screen can explain itself rather
than issue an unexplained instruction."
```

---

## Task 8: Gợi ý tổng hợp cho AI Home

**Files:**
- Modify: `lib/domain/recommendation.dart`
- Test: `test/domain/compute_recommendation_test.dart`

**Interfaces:**
- Produces:
  - `TodayRecommendation({required Drill? drill, required PickReason reason, required SkillCategory cat, required KnowledgeArticle? article, required List<String> readyDrillIds, required int streakDays})`
  - `TodayRecommendation computeRecommendation({required List<Drill> drills, required List<DrillLog> logs, required List<KnowledgeArticle> knowledge, required List<TimerSession> timerSessions, required List<ScheduleSlot> schedule, required DateTime today})`
  - `int streakDays({required List<DrillLog> logs, required List<TimerSession> timerSessions, required DateTime today})`

**Quan trọng:** hàm này trả **dữ liệu**, không trả câu chữ. Không có chuỗi tiếng Việt nào trong `recommendation.dart`. Màn hình ở kế hoạch 3 dựng câu từ `reason`, `cat`, `drill` — đúng mục 2.1: khuôn có tham số, tham số do hàm tính.

- [ ] **Step 1: Viết test thất bại**

Tạo `test/domain/compute_recommendation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

final _today = DateTime(2026, 9, 17);

const _aimDrill = Drill(
  id: 'aim1',
  cat: SkillCategory.aiming,
  name: 'Đường thẳng cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.8,
);

const _aimArticle = KnowledgeArticle(
  id: 'k1',
  cat: SkillCategory.aiming,
  title: 'Nguyên lý bi ảo',
  body: 'b',
);

void main() {
  group('computeRecommendation', () {
    test('người mới nhận bài Ngắm bi cấp 1 và bài đọc cùng nhóm', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [_aimArticle],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.cat, SkillCategory.aiming);
      expect(rec.drill?.id, 'aim1');
      expect(rec.article?.id, 'k1');
      expect(rec.reason, PickReason.newcomer);
    });

    test('không có bài kiến thức cùng nhóm thì article là null, không bịa', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.article, isNull);
    });

    test('bài đã tập hôm nay không được gợi ý lại', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: [
          DrillLog(
            id: 'l1',
            drillId: 'aim1',
            date: _today,
            score: 9,
            attempts: 10,
          ),
        ],
        knowledge: const [_aimArticle],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.drill, isNull);
    });
  });

  group('streakDays', () {
    test('không có buổi nào thì streak bằng 0', () {
      expect(
        streakDays(logs: const [], timerSessions: const [], today: _today),
        0,
      );
    });

    test('tập hôm nay và hai hôm trước liên tiếp cho streak 3', () {
      final logs = [
        for (var i = 0; i < 3; i++)
          DrillLog(
            id: 'l$i',
            drillId: 'aim1',
            date: _today.subtract(Duration(days: i)),
            score: 9,
            attempts: 10,
          ),
      ];

      expect(
        streakDays(logs: logs, timerSessions: const [], today: _today),
        3,
      );
    });

    test('buổi tập tự do cũng tính vào streak', () {
      expect(
        streakDays(
          logs: const [],
          timerSessions: [
            TimerSession(id: 't1', date: _today, durationSec: 600),
          ],
          today: _today,
        ),
        1,
      );
    });

    test('đứt một ngày thì streak dừng lại ở đó', () {
      final logs = [
        DrillLog(
          id: 'l1',
          drillId: 'aim1',
          date: _today,
          score: 9,
          attempts: 10,
        ),
        DrillLog(
          id: 'l2',
          drillId: 'aim1',
          date: _today.subtract(const Duration(days: 2)),
          score: 9,
          attempts: 10,
        ),
      ];

      expect(
        streakDays(logs: logs, timerSessions: const [], today: _today),
        1,
      );
    });

    test('tập hôm qua nhưng chưa tập hôm nay vẫn giữ streak', () {
      final logs = [
        DrillLog(
          id: 'l1',
          drillId: 'aim1',
          date: _today.subtract(const Duration(days: 1)),
          score: 9,
          attempts: 10,
        ),
      ];

      expect(
        streakDays(logs: logs, timerSessions: const [], today: _today),
        1,
      );
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/compute_recommendation_test.dart
```

Kỳ vọng: FAIL — `computeRecommendation` và `streakDays` chưa tồn tại.

- [ ] **Step 3: Bổ sung vào recommendation.dart**

```dart
/// Gợi ý cho hôm nay. Đây là **dữ liệu**, không phải câu chữ.
///
/// Màn hình dựng câu từ các trường này. Không chuỗi tiếng Việt nào được
/// nằm trong file này — xem mục 2.1 tài liệu thiết kế.
class TodayRecommendation {
  const TodayRecommendation({
    required this.cat,
    required this.reason,
    required this.drill,
    required this.article,
    required this.readyDrillIds,
    required this.streak,
  });

  final SkillCategory cat;
  final PickReason reason;

  /// `null` khi không còn bài nào phù hợp để gợi ý hôm nay — ví dụ
  /// người chơi đã tập hết bài của nhóm đó rồi.
  final Drill? drill;

  /// `null` khi chưa có bài kiến thức nào thuộc nhóm này. Không thay
  /// bằng bài nhóm khác cho có.
  final KnowledgeArticle? article;

  final List<String> readyDrillIds;
  final int streak;
}

/// Số ngày tập liên tiếp tính tới hôm nay.
///
/// Cả buổi tập theo bài lẫn buổi tập tự do đều tính. Nếu hôm nay chưa
/// tập nhưng hôm qua có, chuỗi vẫn được giữ — nó chỉ đứt khi bỏ trọn
/// một ngày.
int streakDays({
  required List<DrillLog> logs,
  required List<TimerSession> timerSessions,
  required DateTime today,
}) {
  final activeDays = <String>{
    for (final l in logs) _dayKey(l.date),
    for (final t in timerSessions) _dayKey(t.date),
  };

  if (activeDays.isEmpty) return 0;

  var cursor = DateTime(today.year, today.month, today.day);
  if (!activeDays.contains(_dayKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!activeDays.contains(_dayKey(cursor))) return 0;
  }

  var count = 0;
  while (activeDays.contains(_dayKey(cursor))) {
    count++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Tính gợi ý hôm nay từ toàn bộ dữ liệu người chơi.
TodayRecommendation computeRecommendation({
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<KnowledgeArticle> knowledge,
  required List<TimerSession> timerSessions,
  required List<ScheduleSlot> schedule,
  required DateTime today,
}) {
  final pi = computePlayerIntelligence(drills: drills, logs: logs);

  final pick = pickCategoryForToday(
    pi: pi,
    drills: drills,
    logs: logs,
    timerSessions: timerSessions,
    schedule: schedule,
    today: today,
  );

  final loggedToday = <String>{
    for (final l in logs)
      if (_dayKey(l.date) == _dayKey(today)) l.drillId,
  };

  final logsByDrill = <String, List<DrillLog>>{};
  for (final log in [...logs]..sort((a, b) => a.date.compareTo(b.date))) {
    logsByDrill.putIfAbsent(log.drillId, () => <DrillLog>[]).add(log);
  }

  final drill = pickDrillInCategory(
    cat: pick.cat,
    drills: drills,
    logsByDrillOldestFirst: logsByDrill,
    excludeDrillIds: loggedToday,
  );

  KnowledgeArticle? article;
  for (final a in knowledge) {
    if (a.cat == pick.cat) {
      article = a;
      break;
    }
  }

  return TodayRecommendation(
    cat: pick.cat,
    reason: pick.reason,
    drill: drill,
    article: article,
    readyDrillIds: pi.readyDrillIds,
    streak: streakDays(
      logs: logs,
      timerSessions: timerSessions,
      today: today,
    ),
  );
}
```

Thêm import `knowledge_article.dart`.

- [ ] **Step 4: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả đạt, analyze sạch.

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "Add today's recommendation and streak counting

The recommendation returns data, never sentences — no Vietnamese
string appears in this layer. Screens build their wording from the
category, the reason and the drill, so changing a number changes
what the player reads.

Both the drill and the article can be null. Nothing substitutes a
different category's article to avoid an empty slot."
```

---

## Task 9: Lưới an toàn — lớp suy luận không bao giờ bịa

**Files:**
- Test: `test/domain/no_fabrication_test.dart`

**Interfaces:**
- Consumes: mọi thứ ở trên, cộng `seedDrills` và `seedKnowledge`

Đây là bài kiểm thử của mục 2.1 tài liệu thiết kế, dựng thành test chạy được: **đổi dữ liệu thì kết luận phải đổi theo.**

- [ ] **Step 1: Viết test**

Tạo `test/domain/no_fabrication_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

final _today = DateTime(2026, 9, 17);

/// Dựng người chơi yếu đúng một nhóm: tập kém ở nhóm đó, tốt ở nhóm khác.
List<DrillLog> _playerWeakAt(SkillCategory weakCat) {
  final logs = <DrillLog>[];
  var n = 0;

  for (final drill in seedDrills) {
    if (!drill.usesAttempts) continue;
    final poor = drill.cat == weakCat;
    for (var i = 0; i < 3; i++) {
      n++;
      logs.add(
        DrillLog(
          id: 'l$n',
          drillId: drill.id,
          date: _today.subtract(Duration(days: 10 - i)),
          score: poor ? 2 : 10,
          attempts: 10,
        ),
      );
    }
  }
  return logs;
}

void main() {
  group('lớp suy luận bám dữ liệu, không viết cứng', () {
    test('đổi nhóm yếu trong dữ liệu thì kết luận đổi theo', () {
      for (final weakCat in [SkillCategory.position, SkillCategory.safety]) {
        final pi = computePlayerIntelligence(
          drills: seedDrills,
          logs: _playerWeakAt(weakCat),
        );

        expect(
          pi.weak.first,
          weakCat,
          reason: 'dữ liệu nói yếu $weakCat nhưng kết luận lại khác',
        );
      }
    });

    test('gợi ý hôm nay đi theo nhóm yếu, không cố định một nhóm', () {
      final picks = <SkillCategory>{};

      for (final weakCat in [SkillCategory.position, SkillCategory.safety]) {
        final rec = computeRecommendation(
          drills: seedDrills,
          logs: _playerWeakAt(weakCat),
          knowledge: seedKnowledge,
          timerSessions: const [],
          schedule: const [],
          today: _today,
        );
        picks.add(rec.cat);
      }

      expect(
        picks.length,
        2,
        reason: 'hai người chơi yếu khác nhau mà nhận cùng một gợi ý',
      );
    });

    test('chưa đủ dữ liệu thì nói không biết, không đoán', () {
      final pi = computePlayerIntelligence(
        drills: seedDrills,
        logs: [
          DrillLog(
            id: 'l1',
            drillId: seedDrills.first.id,
            date: _today,
            score: 9,
            attempts: 10,
          ),
        ],
      );

      expect(pi.weak, isEmpty);
      expect(pi.strong, isEmpty);
      for (final insight in pi.categories.values) {
        if (insight.sessionCount < 3) {
          expect(insight.mastery, isNull);
        }
      }
    });
  });
}
```

- [ ] **Step 2: Chạy test**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/no_fabrication_test.dart
```

Kỳ vọng: 3 test đạt. Nếu test thứ hai hỏng vì hai người chơi khác nhau nhận cùng gợi ý, đó là dấu hiệu có chỗ đang viết cứng — tìm và sửa, đừng nới test.

- [ ] **Step 3: Chạy toàn bộ và phân tích lần cuối**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

- [ ] **Step 4: Commit và đẩy lên**

```bash
git add test/domain
git commit -m "Add the no-fabrication safety net

The design document's falsifiable test, made runnable: change which
skill the data says is weak, and every conclusion must follow. Two
players weak at different things must not receive the same advice.

If this fails, something is hardcoded."
git push origin main
```

---

## Hoàn thành kế hoạch 2

- `lib/domain/` không import Flutter (trừ `skill_category.dart` đã có từ trước)
- Mọi hàm là pure function, cùng đầu vào cho cùng đầu ra
- Các case bắt buộc của spec mục 5.8 và 6.6 đều có test và đạt
- Thiếu dữ liệu trả `null`, không bao giờ đoán
- Không chuỗi tiếng Việt nào trong `recommendation.dart` hay `player_intelligence.dart`
- `flutter analyze` sạch, toàn bộ test xanh

Kế hoạch 3 dựng AI Home và Training Center đọc kết quả từ lớp này — màn hình không được tự tính lại bất cứ con số nào.
