# PoolCoachAI — Kế hoạch 1: Nền móng & khung điều hướng

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng dự án Flutter chạy được trên Chrome với hệ thiết kế "Nỉ & Phấn", chuỗi tiếng Việt tập trung, các model nền tảng, và khung điều hướng 5 tab giữ ngăn xếp độc lập kèm nút Coach nổi và màn Thông báo.

**Architecture:** Feature-first. Riverpod không codegen quản lý trạng thái; `go_router` với `StatefulShellRoute.indexedStack` cho 5 tab có ngăn xếp riêng. Mọi màu lấy từ `AppColors`, mọi chữ tiếng Việt lấy từ `Vi` — không hardcode ở bất kỳ đâu khác. Kế hoạch này chưa có repository hay dữ liệu mock; nó dựng phần khung mà các kế hoạch sau cắm vào.

**Tech Stack:** Flutter 3.47.0 · Dart 3.13.0 · flutter_riverpod · go_router · google_fonts

**Spec:** `docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md`

## Global Constraints

Mọi nhiệm vụ đều ngầm bao gồm các ràng buộc sau.

- **Flutter không nằm trong PATH.** Mọi lệnh gọi bằng đường dẫn đầy đủ. Trong Bash dùng: `FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"` rồi `"$FLUTTER" test`. Trong PowerShell dùng: `& "C:\Users\anhnpv\flutter\bin\flutter.bat" test`. **Không dùng** `D:\flutter` (bản 3.44.6 cũ).
- **Tên package Dart là `poolcoachai`** (chữ thường, không gạch dưới). Tên thư mục `PoolCoachAI` có chữ hoa nên không dùng làm tên package được.
- **Toàn bộ giao diện bằng tiếng Việt.** Mọi chuỗi hiển thị cho người dùng nằm trong `lib/core/strings/vi.dart`. Không widget nào được chứa chuỗi tiếng Việt viết thẳng.
- **Mọi màu lấy từ `lib/core/theme/app_colors.dart`.** Không `Color(0x...)` viết thẳng trong widget.
- **Riverpod không dùng codegen.** Không `@riverpod`, không `build_runner`, không file `.g.dart`.
- **Thiết bị chạy thử: Chrome.** `"$FLUTTER" run -d chrome`.
- **Thuật ngữ đã chốt, không được đổi:** Ngắm bi · Điều bi / Vị trí · Phá · Phòng thủ · A băng · Đánh đứng bi · Đánh trô bi · Đánh cu lê · Chết cái · Bi ảo · Bi cái · Chấm / dọn bàn · Ván · Lỗi · Bi mục tiêu · Góc cắt · Đầu cơ · Cơ phá · Cơ nhảy.
- **Hạng:** `K I H G` nhóm phong trào · `F E D C B A` nhóm cạnh tranh · `PRO` chuyên nghiệp.
- **Commit sau mỗi nhiệm vụ.** Mỗi commit phải để lại cây mã ở trạng thái `analyze` sạch và `test` xanh.

---

## Cấu trúc file

Kế hoạch này tạo các file sau. Mỗi file một trách nhiệm duy nhất.

| File | Trách nhiệm |
|---|---|
| `pubspec.yaml` | Khai báo package và phụ thuộc |
| `analysis_options.yaml` | Luật lint |
| `lib/main.dart` | Điểm vào, bọc `ProviderScope` |
| `lib/app.dart` | `MaterialApp.router` — ghép theme và router |
| `lib/core/theme/app_colors.dart` | Hằng số màu "Nỉ & Phấn" |
| `lib/core/theme/app_spacing.dart` | Thang khoảng cách và bo góc |
| `lib/core/theme/app_typography.dart` | Thang chữ, Be Vietnam Pro + JetBrains Mono |
| `lib/core/theme/app_theme.dart` | Ghép thành `ThemeData` |
| `lib/core/strings/vi.dart` | Toàn bộ chuỗi tiếng Việt |
| `lib/domain/skill_category.dart` | 5 nhóm kỹ năng + màu của từng nhóm |
| `lib/domain/rank.dart` | 11 hạng + nhóm hạng |
| `lib/core/widgets/pc_card.dart` | Thẻ nền chuẩn |
| `lib/core/widgets/pc_section_header.dart` | Nhãn mục IN HOA |
| `lib/core/widgets/pc_skill_chip.dart` | Viên thuốc nhóm kỹ năng |
| `lib/core/widgets/pc_rank_badge.dart` | Huy hiệu hạng |
| `lib/core/widgets/pc_empty_state.dart` | Trạng thái rỗng |
| `lib/core/router/routes.dart` | Hằng số đường dẫn |
| `lib/core/router/app_router.dart` | Cấu hình `GoRouter` |
| `lib/core/widgets/pc_shell_scaffold.dart` | Khung chứa 5 tab + nút Coach + chuông |
| `lib/features/home/presentation/home_screen.dart` | Màn gốc tab Trang chủ |
| `lib/features/training/presentation/training_screen.dart` | Màn gốc tab Luyện tập |
| `lib/features/play/presentation/play_screen.dart` | Màn gốc tab Thi đấu |
| `lib/features/stats/presentation/stats_screen.dart` | Màn gốc tab Thống kê |
| `lib/features/profile/presentation/profile_screen.dart` | Màn gốc tab Hồ sơ |
| `lib/features/coach/presentation/coach_screen.dart` | Màn Coach, mở đè lên shell |
| `lib/features/notifications/presentation/notifications_screen.dart` | Màn Thông báo, mở đè lên shell |

---

## Task 1: Khởi tạo dự án Flutter

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, và bộ khung do `flutter create` sinh ra
- Modify: `.gitignore` (kiểm tra lại sau khi `flutter create` ghi đè)

**Interfaces:**
- Consumes: không có — đây là nhiệm vụ đầu tiên
- Produces: một dự án Flutter tên `poolcoachai` chạy được, có `flutter_riverpod`, `go_router`, `google_fonts`

- [ ] **Step 1: Sao lưu .gitignore hiện có**

`flutter create` sẽ ghi đè `.gitignore`. File hiện tại chứa các mục riêng của dự án cần giữ lại.

```bash
cd "C:/Users/anhnpv/Desktop/PoolCoachAI"
cp .gitignore .gitignore.backup
```

- [ ] **Step 2: Chạy flutter create**

Tên thư mục có chữ hoa nên bắt buộc truyền `--project-name`.

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" create . --project-name poolcoachai --org com.poolcoachai --platforms=android,ios,web
```

Kỳ vọng: in ra "All done!" và tạo `lib/`, `test/`, `web/`, `android/`, `ios/`, `pubspec.yaml`.

- [ ] **Step 3: Khôi phục các mục .gitignore riêng của dự án**

So sánh và ghép lại. Các mục bắt buộc phải có sau bước này:

```bash
cd "C:/Users/anhnpv/Desktop/PoolCoachAI"
for entry in ".superpowers/" "*.g.dart" "*.freezed.dart" "*.mocks.dart" "coverage/" ".env"; do
  grep -qxF "$entry" .gitignore || echo "$entry" >> .gitignore
done
rm .gitignore.backup
grep -c "" .gitignore
```

Kỳ vọng: `.gitignore` chứa cả nội dung Flutter sinh ra lẫn 6 mục trên.

- [ ] **Step 4: Thêm các gói phụ thuộc**

Dùng `pub add` để pub tự chọn phiên bản hợp với Flutter 3.47.0 — **không** viết số phiên bản bằng tay.

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" pub add flutter_riverpod go_router google_fonts
```

Kỳ vọng: `pubspec.yaml` có ba gói trong mục `dependencies`, `pub get` chạy xong không lỗi.

- [ ] **Step 5: Bật lint nghiêm hơn**

Ghi đè `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - avoid_print
    - require_trailing_commas
    - sort_child_properties_last
```

- [ ] **Step 6: Chạy phân tích tĩnh và kiểm thử mặc định**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" analyze
"$FLUTTER" test
```

Kỳ vọng: `analyze` in "No issues found!". `test` chạy `widget_test.dart` mặc định và **có thể thất bại** vì nó kiểm tra app đếm số mẫu — điều đó bình thường ở bước này.

- [ ] **Step 7: Xóa test mẫu và thay main.dart**

Test mẫu kiểm tra app đếm số, không còn đúng. Xóa nó.

```bash
rm test/widget_test.dart
```

Ghi `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: PoolCoachApp()));
}

/// Tạm thời ở nhiệm vụ 1. Nhiệm vụ 7 thay bằng bản dùng router thật.
class PoolCoachApp extends StatelessWidget {
  const PoolCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('PoolCoachAI')),
      ),
    );
  }
}
```

- [ ] **Step 8: Xác nhận cây mã sạch**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" analyze
"$FLUTTER" test
```

Kỳ vọng: `analyze` in "No issues found!". `test` in "No tests ran." — chưa có test nào, đúng như mong đợi.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Scaffold the Flutter project

Create the poolcoachai package targeting android, ios and web,
add flutter_riverpod, go_router and google_fonts, and tighten the
lint rules. Restore the project-specific gitignore entries that
flutter create overwrote."
```

---

## Task 2: Màu và thang khoảng cách

**Files:**
- Create: `lib/core/theme/app_colors.dart`, `lib/core/theme/app_spacing.dart`
- Test: `test/core/theme/app_colors_test.dart`

**Interfaces:**
- Consumes: không có
- Produces: `AppColors` với các hằng `Color`: `bgDeep`, `bgScreen`, `surface`, `surfaceRaised`, `border`, `borderStrong`, `accent`, `accentBright`, `textPrimary`, `textSecondary`, `textMuted`, `textDisabled`, `success`, `danger`, `warning`, `info`. `AppSpacing` với các hằng `double`: `xs`(4), `sm`(8), `md`(12), `lg`(16), `xl`(20), `xxl`(24), `xxxl`(32) và `radiusSm`(8), `radiusMd`(12), `radiusLg`(16), `radiusXl`(22)

- [ ] **Step 1: Viết test thất bại**

Tạo `test/core/theme/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('màu nhấn là vàng đồng của hệ Nỉ & Phấn', () {
      expect(AppColors.accent, const Color(0xFFD9A441));
    });

    test('nền màn hình là xanh nỉ', () {
      expect(AppColors.bgScreen, const Color(0xFF12261C));
    });

    test('chữ chính là màu phấn', () {
      expect(AppColors.textPrimary, const Color(0xFFEFE7D6));
    });

    test('thành công và thất bại là hai màu khác nhau', () {
      expect(AppColors.success, isNot(AppColors.danger));
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/theme/app_colors_test.dart
```

Kỳ vọng: FAIL — `Target of URI doesn't exist: 'package:poolcoachai/core/theme/app_colors.dart'`.

- [ ] **Step 3: Viết app_colors.dart**

```dart
import 'package:flutter/material.dart';

/// Bảng màu "Nỉ & Phấn".
/// Xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md mục 4.1.
abstract final class AppColors {
  // Nền & viền — sắc nỉ bàn bida
  static const bgDeep = Color(0xFF0E1F16);
  static const bgScreen = Color(0xFF12261C);
  static const surface = Color(0xFF18301F);
  static const surfaceRaised = Color(0xFF1B3527);
  static const border = Color(0xFF27462F);
  static const borderStrong = Color(0xFF3A6044);

  // Nhấn & chữ — phấn và đồng
  static const accent = Color(0xFFD9A441);
  static const accentBright = Color(0xFFE8BC63);
  static const textPrimary = Color(0xFFEFE7D6);
  static const textSecondary = Color(0xFFC6D3C6);
  static const textMuted = Color(0xFF9FB0A3);
  static const textDisabled = Color(0xFF6F8677);

  // Trạng thái
  static const success = Color(0xFF5FBF7E);
  static const danger = Color(0xFFE2685C);
  static const warning = Color(0xFFE5A93C);
  static const info = Color(0xFF6FA8D6);
}
```

- [ ] **Step 4: Viết app_spacing.dart**

```dart
/// Thang khoảng cách theo bội số 4 và thang bo góc.
/// Xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md mục 4.3.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 22.0;
}
```

- [ ] **Step 5: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/core/theme/app_colors_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 4 test đạt, `analyze` sạch.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme test/core/theme
git commit -m "Add the Felt and Chalk color and spacing scales"
```

---

## Task 3: Chuỗi tiếng Việt

**Files:**
- Create: `lib/core/strings/vi.dart`
- Test: `test/core/strings/vi_test.dart`

**Interfaces:**
- Consumes: không có
- Produces: `Vi` với các hằng `String`: `appName`, `tabHome`, `tabTraining`, `tabPlay`, `tabStats`, `tabProfile`, `coachTitle`, `notificationsTitle`, `comingSoonTitle`, `comingSoonBody`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/core/strings/vi_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';

void main() {
  group('Vi', () {
    test('nhãn 5 tab đúng như thiết kế', () {
      expect(Vi.tabHome, 'Trang chủ');
      expect(Vi.tabTraining, 'Luyện tập');
      expect(Vi.tabPlay, 'Thi đấu');
      expect(Vi.tabStats, 'Thống kê');
      expect(Vi.tabProfile, 'Hồ sơ');
    });

    test('không có nhãn tab nào bị rỗng', () {
      final labels = [
        Vi.tabHome,
        Vi.tabTraining,
        Vi.tabPlay,
        Vi.tabStats,
        Vi.tabProfile,
      ];
      for (final label in labels) {
        expect(label.trim(), isNotEmpty);
      }
    });

    test('tên app giữ nguyên, không dịch', () {
      expect(Vi.appName, 'PoolCoachAI');
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/strings/vi_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/strings/vi.dart`.

- [ ] **Step 3: Viết vi.dart**

```dart
/// Toàn bộ chuỗi tiếng Việt hiển thị cho người dùng.
///
/// Không widget nào được chứa chuỗi tiếng Việt viết thẳng — mọi chữ
/// phải đi qua đây. Nhờ vậy đổi cách gọi một thuật ngữ chỉ cần sửa
/// một dòng thay vì lục khắp 35 màn.
abstract final class Vi {
  static const appName = 'PoolCoachAI';

  // Thanh tab
  static const tabHome = 'Trang chủ';
  static const tabTraining = 'Luyện tập';
  static const tabPlay = 'Thi đấu';
  static const tabStats = 'Thống kê';
  static const tabProfile = 'Hồ sơ';

  // Màn mở đè lên shell
  static const coachTitle = 'Huấn luyện viên AI';
  static const notificationsTitle = 'Thông báo';

  // Trạng thái rỗng dùng chung
  static const comingSoonTitle = 'Đang xây dựng';
  static const comingSoonBody = 'Phần này sẽ có ở bản cập nhật sau.';
}
```

- [ ] **Step 4: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/core/strings/vi_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 3 test đạt, `analyze` sạch.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings test/core/strings
git commit -m "Add the central Vietnamese string table"
```

---

## Task 4: Nhóm kỹ năng và hạng

**Files:**
- Create: `lib/domain/skill_category.dart`, `lib/domain/rank.dart`
- Modify: `lib/core/strings/vi.dart`
- Test: `test/domain/skill_category_test.dart`, `test/domain/rank_test.dart`

**Interfaces:**
- Consumes: `AppColors` từ nhiệm vụ 2, `Vi` từ nhiệm vụ 3
- Produces:
  - `enum SkillCategory { aiming, position, breakShot, safety, bank }` với thuộc tính `Color fg`, `Color bg`, `Color borderColor`
  - `enum RankGroup { amateur, competitive, pro }`
  - `enum Rank { k, i, h, g, f, e, d, c, b, a, pro }` với `RankGroup get group` và `String get label`
  - `Vi.skill(SkillCategory)` trả về tên tiếng Việt

- [ ] **Step 1: Viết test thất bại cho nhóm kỹ năng**

Tạo `test/domain/skill_category_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('SkillCategory', () {
    test('có đúng 5 nhóm', () {
      expect(SkillCategory.values.length, 5);
    });

    test('tên tiếng Việt đúng thuật ngữ cơ thủ đã chốt', () {
      expect(Vi.skill(SkillCategory.aiming), 'Ngắm bi');
      expect(Vi.skill(SkillCategory.position), 'Điều bi / Vị trí');
      expect(Vi.skill(SkillCategory.breakShot), 'Phá');
      expect(Vi.skill(SkillCategory.safety), 'Phòng thủ');
      expect(Vi.skill(SkillCategory.bank), 'A băng');
    });

    test('mỗi nhóm có một màu chữ riêng biệt', () {
      final colors = SkillCategory.values.map((c) => c.fg).toSet();
      expect(colors.length, 5);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/skill_category_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/domain/skill_category.dart`.

- [ ] **Step 3: Viết skill_category.dart**

```dart
import 'package:flutter/material.dart';

/// Năm nhóm kỹ năng chính thức theo PRD.
///
/// Khóa giữ tiếng Anh; tên tiếng Việt nằm ở [Vi.skill].
/// Màu xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md mục 4.1.
enum SkillCategory {
  aiming(
    fg: Color(0xFFE8B44C),
    bg: Color(0xFF4A3A14),
    borderColor: Color(0xFF6B5220),
  ),
  position(
    fg: Color(0xFF6FA8D6),
    bg: Color(0xFF1E3648),
    borderColor: Color(0xFF2F5578),
  ),
  breakShot(
    fg: Color(0xFFE2685C),
    bg: Color(0xFF4A2320),
    borderColor: Color(0xFF7A3A34),
  ),
  safety(
    fg: Color(0xFF9B8BD6),
    bg: Color(0xFF322B4A),
    borderColor: Color(0xFF4B4277),
  ),
  bank(
    fg: Color(0xFF4FB3A5),
    bg: Color(0xFF14403C),
    borderColor: Color(0xFF226B62),
  );

  const SkillCategory({
    required this.fg,
    required this.bg,
    required this.borderColor,
  });

  /// Màu chữ và icon.
  final Color fg;

  /// Màu nền viên thuốc.
  final Color bg;

  /// Màu viền viên thuốc.
  final Color borderColor;
}
```

- [ ] **Step 4: Thêm Vi.skill vào vi.dart**

Thêm import ở đầu `lib/core/strings/vi.dart`:

```dart
import 'package:poolcoachai/domain/skill_category.dart';
```

Thêm phương thức vào trong `abstract final class Vi`:

```dart
  /// Tên tiếng Việt của một nhóm kỹ năng.
  ///
  /// Đây là thuật ngữ đã được cơ thủ xác nhận — "Phá" chứ không phải
  /// "Giao bóng", "A băng" (từ tiếng Pháp *à bande*) chứ không phải
  /// "Bi băng", "Điều bi" chứ không phải "Đi bi".
  static String skill(SkillCategory category) => switch (category) {
        SkillCategory.aiming => 'Ngắm bi',
        SkillCategory.position => 'Điều bi / Vị trí',
        SkillCategory.breakShot => 'Phá',
        SkillCategory.safety => 'Phòng thủ',
        SkillCategory.bank => 'A băng',
      };
```

- [ ] **Step 5: Chạy test nhóm kỹ năng để xác nhận đạt**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/skill_category_test.dart
```

Kỳ vọng: 3 test đạt.

- [ ] **Step 6: Viết test thất bại cho hạng**

Tạo `test/domain/rank_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  group('Rank', () {
    test('có đúng 11 hạng', () {
      expect(Rank.values.length, 11);
    });

    test('K I H G thuộc nhóm phong trào', () {
      for (final rank in [Rank.k, Rank.i, Rank.h, Rank.g]) {
        expect(rank.group, RankGroup.amateur, reason: 'hạng ${rank.label}');
      }
    });

    test('F đến A thuộc nhóm cạnh tranh', () {
      for (final rank in [Rank.f, Rank.e, Rank.d, Rank.c, Rank.b, Rank.a]) {
        expect(rank.group, RankGroup.competitive, reason: 'hạng ${rank.label}');
      }
    });

    test('professional đứng riêng một nhóm', () {
      expect(Rank.pro.group, RankGroup.pro);
    });

    test('nhãn hiển thị là chữ hoa, riêng pro là PRO', () {
      expect(Rank.k.label, 'K');
      expect(Rank.g.label, 'G');
      expect(Rank.pro.label, 'PRO');
    });

    test('thứ tự từ thấp lên cao', () {
      expect(Rank.values.first, Rank.k);
      expect(Rank.values.last, Rank.pro);
      expect(Rank.g.index, lessThan(Rank.f.index));
    });
  });
}
```

- [ ] **Step 7: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/domain/rank_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/domain/rank.dart`.

- [ ] **Step 8: Viết rank.dart**

```dart
/// Ba nhóm hạng của PoolCoachAI.
enum RankGroup {
  /// K → G: cơ thủ phong trào, nghiệp dư.
  amateur,

  /// F → A: đã bước vào sân chơi cạnh tranh.
  competitive,

  /// Chuyên nghiệp.
  pro,
}

/// Hệ hạng của PoolCoachAI, xếp từ thấp lên cao.
///
/// Đây là bảng định nghĩa riêng của PoolCoachAI dựa trên cách hiểu hạng
/// tại Hà Nội, **không phải** chuẩn xếp hạng quốc gia duy nhất. Màn hình
/// nào hiển thị hạng cũng phải kèm chú thích này.
enum Rank {
  k(RankGroup.amateur),
  i(RankGroup.amateur),
  h(RankGroup.amateur),
  g(RankGroup.amateur),
  f(RankGroup.competitive),
  e(RankGroup.competitive),
  d(RankGroup.competitive),
  c(RankGroup.competitive),
  b(RankGroup.competitive),
  a(RankGroup.competitive),
  pro(RankGroup.pro);

  const Rank(this.group);

  final RankGroup group;

  /// Nhãn hiển thị: 'K', 'G', … và 'PRO'.
  String get label => this == Rank.pro ? 'PRO' : name.toUpperCase();
}
```

- [ ] **Step 9: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả test đạt (4 + 3 + 3 + 6 = 16 test), `analyze` sạch.

- [ ] **Step 10: Commit**

```bash
git add lib/domain lib/core/strings test/domain
git commit -m "Add skill category and rank domain models

Skill categories carry their own chip colors. Vietnamese names live
in Vi.skill so the terms the player confirmed stay in one place.
Ranks split into amateur, competitive and pro groups."
```

---

## Task 5: Widget nền — thẻ, nhãn mục, trạng thái rỗng

**Files:**
- Create: `lib/core/widgets/pc_card.dart`, `lib/core/widgets/pc_section_header.dart`, `lib/core/widgets/pc_empty_state.dart`
- Test: `test/core/widgets/pc_card_test.dart`, `test/core/widgets/pc_empty_state_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` từ nhiệm vụ 2; `Vi` từ nhiệm vụ 3
- Produces:
  - `PcCard({Key? key, required Widget child, EdgeInsetsGeometry? padding, VoidCallback? onTap})`
  - `PcSectionHeader({Key? key, required String title, String? actionLabel, VoidCallback? onAction})`
  - `PcEmptyState({Key? key, required IconData icon, required String title, required String body})`

- [ ] **Step 1: Viết test thất bại cho PcCard**

Tạo `test/core/widgets/pc_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';

void main() {
  group('PcCard', () {
    testWidgets('hiển thị nội dung con', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcCard(child: Text('Nội dung')),
          ),
        ),
      );

      expect(find.text('Nội dung'), findsOneWidget);
    });

    testWidgets('dùng màu nền surface của hệ thiết kế', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcCard(child: Text('Nội dung')),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PcCard),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surface);
    });

    testWidgets('gọi onTap khi được bấm', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PcCard(
              onTap: () => tapped = true,
              child: const Text('Nội dung'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PcCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/widgets/pc_card_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/widgets/pc_card.dart`.

- [ ] **Step 3: Viết pc_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Thẻ nền chuẩn của PoolCoachAI.
///
/// Trên nền tối, phân tách bằng viền chứ không bằng đổ bóng — đổ bóng
/// gần như vô hình trên nền xanh đậm.
class PcCard extends StatelessWidget {
  const PcCard({
    required this.child,
    this.padding,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: card,
    );
  }
}
```

- [ ] **Step 4: Chạy test PcCard để xác nhận đạt**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/widgets/pc_card_test.dart
```

Kỳ vọng: 3 test đạt.

- [ ] **Step 5: Viết pc_section_header.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Nhãn mục IN HOA, giãn chữ, màu vàng đồng.
class PcSectionHeader extends StatelessWidget {
  const PcSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.accent,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Viết test thất bại cho PcEmptyState**

Tạo `test/core/widgets/pc_empty_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

void main() {
  testWidgets('PcEmptyState hiển thị icon, tiêu đề và nội dung', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PcEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Chưa có chứng nhận nào',
            body: 'Hoàn thành Kiểm tra kỹ năng để nhận chứng nhận đầu tiên.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    expect(find.text('Chưa có chứng nhận nào'), findsOneWidget);
    expect(
      find.text('Hoàn thành Kiểm tra kỹ năng để nhận chứng nhận đầu tiên.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 7: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/widgets/pc_empty_state_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/widgets/pc_empty_state.dart`.

- [ ] **Step 8: Viết pc_empty_state.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Trạng thái rỗng dùng cho các màn chưa có nội dung.
///
/// Mỗi màn ở mức "khung" phải dùng widget này để giải thích rõ sẽ có gì
/// ở bản sau, thay vì để trắng.
class PcEmptyState extends StatelessWidget {
  const PcEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả test đạt, `analyze` sạch.

- [ ] **Step 10: Commit**

```bash
git add lib/core/widgets test/core/widgets
git commit -m "Add card, section header and empty state widgets"
```

---

## Task 6: Viên thuốc kỹ năng và huy hiệu hạng

**Files:**
- Create: `lib/core/widgets/pc_skill_chip.dart`, `lib/core/widgets/pc_rank_badge.dart`
- Test: `test/core/widgets/pc_skill_chip_test.dart`, `test/core/widgets/pc_rank_badge_test.dart`

**Interfaces:**
- Consumes: `SkillCategory`, `Rank`, `RankGroup` từ nhiệm vụ 4; `Vi.skill` từ nhiệm vụ 4; `AppColors`, `AppSpacing` từ nhiệm vụ 2
- Produces:
  - `PcSkillChip({Key? key, required SkillCategory category})`
  - `PcRankBadge({Key? key, required Rank rank, bool showWord = false})` — `showWord: true` hiện "HẠNG G" thay vì "G"

- [ ] **Step 1: Viết test thất bại cho PcSkillChip**

Tạo `test/core/widgets/pc_skill_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('PcSkillChip', () {
    testWidgets('hiện tên tiếng Việt của nhóm kỹ năng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcSkillChip(category: SkillCategory.bank),
          ),
        ),
      );

      expect(find.text('A băng'), findsOneWidget);
    });

    testWidgets('dùng màu riêng của từng nhóm', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcSkillChip(category: SkillCategory.breakShot),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PcSkillChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, SkillCategory.breakShot.bg);
    });

    testWidgets('dựng được cả 5 nhóm không lỗi', (tester) async {
      for (final category in SkillCategory.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PcSkillChip(category: category)),
          ),
        );
        expect(find.byType(PcSkillChip), findsOneWidget);
      }
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/widgets/pc_skill_chip_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/widgets/pc_skill_chip.dart`.

- [ ] **Step 3: Viết pc_skill_chip.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Viên thuốc hiển thị một nhóm kỹ năng, màu theo đúng nhóm đó.
///
/// Màu giữ nguyên ở mọi nơi — bộ lọc bài tập, biểu đồ thống kê, nhãn
/// đồng hồ luyện tập — để người chơi nhìn màu là biết nhóm nào.
class PcSkillChip extends StatelessWidget {
  const PcSkillChip({required this.category, super.key});

  final SkillCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: category.bg,
        border: Border.all(color: category.borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        Vi.skill(category),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: category.fg,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Chạy test để xác nhận đạt**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/widgets/pc_skill_chip_test.dart
```

Kỳ vọng: 3 test đạt.

- [ ] **Step 5: Thêm chuỗi "Hạng" vào vi.dart**

Thêm vào trong `abstract final class Vi`:

```dart
  /// Tiền tố huy hiệu hạng, ví dụ "HẠNG G".
  static const rankWord = 'Hạng';
```

- [ ] **Step 6: Viết test thất bại cho PcRankBadge**

Tạo `test/core/widgets/pc_rank_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  group('PcRankBadge', () {
    testWidgets('mặc định chỉ hiện chữ cái hạng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PcRankBadge(rank: Rank.g)),
        ),
      );

      expect(find.text('G'), findsOneWidget);
    });

    testWidgets('showWord hiện thêm chữ "HẠNG"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PcRankBadge(rank: Rank.g, showWord: true)),
        ),
      );

      expect(find.text('HẠNG G'), findsOneWidget);
    });

    testWidgets('hạng phong trào và hạng cạnh tranh khác màu', (tester) async {
      Color backgroundOf(WidgetTester t) {
        final container = t.widget<Container>(
          find.descendant(
            of: find.byType(PcRankBadge),
            matching: find.byType(Container),
          ).first,
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PcRankBadge(rank: Rank.g))),
      );
      final amateur = backgroundOf(tester);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PcRankBadge(rank: Rank.f))),
      );
      final competitive = backgroundOf(tester);

      expect(amateur, isNot(competitive));
    });

    testWidgets('dựng được cả 11 hạng không lỗi', (tester) async {
      for (final rank in Rank.values) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: PcRankBadge(rank: rank))),
        );
        expect(find.byType(PcRankBadge), findsOneWidget);
      }
    });
  });
}
```

- [ ] **Step 7: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/widgets/pc_rank_badge_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/widgets/pc_rank_badge.dart`.

- [ ] **Step 8: Viết pc_rank_badge.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Huy hiệu hạng, đổi màu theo nhóm.
///
/// Xám xanh cho nhóm phong trào K→G, vàng đồng từ F trở lên khi bước
/// vào sân chơi cạnh tranh, trắng phấn cho Professional.
class PcRankBadge extends StatelessWidget {
  const PcRankBadge({required this.rank, this.showWord = false, super.key});

  final Rank rank;

  /// Khi bật, hiện "HẠNG G" thay vì chỉ "G".
  final bool showWord;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, borderColor) = switch (rank.group) {
      RankGroup.amateur => (
          const Color(0xFF26412E),
          const Color(0xFF8FA396),
          AppColors.borderStrong,
        ),
      RankGroup.competitive => (
          const Color(0xFF4A3A14),
          const Color(0xFFE8B44C),
          const Color(0xFF6B5220),
        ),
      RankGroup.pro => (
          AppColors.textPrimary,
          AppColors.bgScreen,
          AppColors.textPrimary,
        ),
    };

    final text = showWord
        ? '${Vi.rankWord.toUpperCase()} ${rank.label}'
        : rank.label;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả test đạt, `analyze` sạch.

- [ ] **Step 10: Commit**

```bash
git add lib/core/widgets lib/core/strings test/core/widgets
git commit -m "Add skill chip and rank badge widgets

The rank badge colors amateur, competitive and pro groups
differently, matching how players actually talk about the ladder."
```

---

## Task 7: Kiểu chữ và ThemeData

**Files:**
- Create: `lib/core/theme/app_typography.dart`, `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppColors` từ nhiệm vụ 2
- Produces:
  - `AppTypography` với các `TextStyle` tĩnh: `display`, `h1`, `h2`, `h3`, `body`, `caption`, `label`, và `mono` cho số liệu
  - `AppTheme.dark()` trả về `ThemeData`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('là theme tối', () {
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('nền scaffold là màu nền màn hình của hệ thiết kế', () {
      expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.bgScreen);
    });

    test('màu nhấn của scheme là vàng đồng', () {
      expect(AppTheme.dark().colorScheme.primary, AppColors.accent);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/theme/app_theme_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/theme/app_theme.dart`.

- [ ] **Step 3: Viết app_typography.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';

/// Thang chữ của PoolCoachAI.
///
/// Be Vietnam Pro cho toàn bộ giao diện — font thiết kế riêng cho tiếng
/// Việt, dấu má cân đối, không vỡ ở chữ hoa có dấu như "MỤC TIÊU".
/// JetBrains Mono cho số liệu vì chữ số đều bề ngang nên bảng thống kê
/// và đồng hồ đếm ngược không bị nhảy.
abstract final class AppTypography {
  static TextStyle get display => GoogleFonts.beVietnamPro(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get h1 => GoogleFonts.beVietnamPro(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.beVietnamPro(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => GoogleFonts.beVietnamPro(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.beVietnamPro(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.beVietnamPro(
        fontSize: 12,
        color: AppColors.textMuted,
      );

  static TextStyle get label => GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.accent,
      );

  /// Dùng cho mọi số liệu: tỷ lệ, streak, giờ tập, đồng hồ đếm.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.accent,
      );
}
```

- [ ] **Step 4: Viết app_theme.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/theme/app_typography.dart';

/// Ghép bảng màu, thang chữ và thang khoảng cách thành ThemeData.
abstract final class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgScreen,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.accent,
        onPrimary: AppColors.bgScreen,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgScreen,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.h2,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        titleMedium: AppTypography.h3,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
        labelSmall: AppTypography.label,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bgScreen,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgDeep,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bgScreen,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Chạy test để xác nhận đạt**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test test/core/theme/app_theme_test.dart
"$FLUTTER" analyze
```

Kỳ vọng: 3 test đạt, `analyze` sạch.

Ghi chú: `google_fonts` tải font qua mạng ở lần chạy đầu. Trong test nó dùng font dự phòng, không gây lỗi.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme test/core/theme
git commit -m "Add typography scale and dark theme

Be Vietnam Pro handles Vietnamese diacritics without breaking on
accented capitals; JetBrains Mono keeps numeric columns from
shifting."
```

---

## Task 8: Đường dẫn và 7 màn gốc

**Files:**
- Create: `lib/core/router/routes.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/training/presentation/training_screen.dart`, `lib/features/play/presentation/play_screen.dart`, `lib/features/stats/presentation/stats_screen.dart`, `lib/features/profile/presentation/profile_screen.dart`, `lib/features/coach/presentation/coach_screen.dart`, `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `lib/core/strings/vi.dart`
- Test: `test/core/router/routes_test.dart`

**Interfaces:**
- Consumes: `Vi`, `PcEmptyState` từ các nhiệm vụ trước
- Produces:
  - `Routes` với các hằng `String`: `home`, `training`, `play`, `stats`, `profile`, `coach`, `notifications`, và `Routes.tabs` là `List<String>` gồm 5 đường dẫn tab theo đúng thứ tự
  - Bảy widget màn hình không tham số: `HomeScreen`, `TrainingScreen`, `PlayScreen`, `StatsScreen`, `ProfileScreen`, `CoachScreen`, `NotificationsScreen`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/core/router/routes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';

void main() {
  group('Routes', () {
    test('có đúng 5 tab, theo đúng thứ tự thiết kế', () {
      expect(Routes.tabs, [
        Routes.home,
        Routes.training,
        Routes.play,
        Routes.stats,
        Routes.profile,
      ]);
    });

    test('mọi đường dẫn đều bắt đầu bằng dấu gạch chéo', () {
      final all = [...Routes.tabs, Routes.coach, Routes.notifications];
      for (final path in all) {
        expect(path, startsWith('/'), reason: path);
      }
    });

    test('không có đường dẫn nào trùng nhau', () {
      final all = [...Routes.tabs, Routes.coach, Routes.notifications];
      expect(all.toSet().length, all.length);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/router/routes_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/core/router/routes.dart`.

- [ ] **Step 3: Viết routes.dart**

```dart
/// Hằng số đường dẫn của toàn app.
///
/// Không widget nào được viết chuỗi đường dẫn thẳng — luôn đi qua đây.
abstract final class Routes {
  // Năm tab gốc
  static const home = '/home';
  static const training = '/training';
  static const play = '/play';
  static const stats = '/stats';
  static const profile = '/profile';

  // Mở đè lên shell
  static const coach = '/coach';
  static const notifications = '/notifications';

  /// Năm tab theo đúng thứ tự hiển thị trên thanh điều hướng.
  static const tabs = <String>[home, training, play, stats, profile];
}
```

- [ ] **Step 4: Chạy test để xác nhận đạt**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/router/routes_test.dart
```

Kỳ vọng: 3 test đạt.

- [ ] **Step 5: Thêm chuỗi cho 7 màn vào vi.dart**

Thêm vào trong `abstract final class Vi`:

```dart
  // Tiêu đề và mô tả tạm của các màn gốc
  static const homeTitle = 'Xin chào';
  static const homeComing = 'Gợi ý của huấn luyện viên, mục tiêu hôm nay '
      'và tiến độ sẽ hiện ở đây.';

  static const trainingTitle = 'Trung tâm luyện tập';
  static const trainingComing = 'Thư viện bài tập, lộ trình AI, mô phỏng '
      'góc cắt và đồng hồ luyện tập sẽ nằm ở đây.';

  static const playTitle = 'Thi đấu';
  static const playComing = 'Ghi trận đấu, lịch sử trận và giải đấu sẽ '
      'nằm ở đây.';

  static const statsTitle = 'Thống kê';
  static const statsComing = 'Biểu đồ tiến bộ theo từng nhóm kỹ năng, '
      'kết hợp dữ liệu luyện tập và thi đấu.';

  static const profileTitle = 'Hồ sơ';
  static const profileComing = 'Hạng, chứng nhận, cơ bi-a và cài đặt sẽ '
      'nằm ở đây.';

  static const coachComing = 'Hỏi huấn luyện viên hôm nay nên tập gì, '
      'hoặc vì sao trận vừa rồi thua.';

  static const notificationsComing = 'Nhắc lịch tập, nhắc bảo dưỡng đầu cơ '
      'và đề xuất mới sẽ hiện ở đây.';
```

- [ ] **Step 6: Viết 5 màn tab**

Cả năm theo cùng một khuôn. Tạo `lib/features/home/presentation/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.home_outlined,
      title: Vi.homeTitle,
      body: Vi.homeComing,
    );
  }
}
```

Tạo `lib/features/training/presentation/training_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.track_changes_outlined,
      title: Vi.trainingTitle,
      body: Vi.trainingComing,
    );
  }
}
```

Tạo `lib/features/play/presentation/play_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.play_circle_outline,
      title: Vi.playTitle,
      body: Vi.playComing,
    );
  }
}
```

Tạo `lib/features/stats/presentation/stats_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.bar_chart_outlined,
      title: Vi.statsTitle,
      body: Vi.statsComing,
    );
  }
}
```

Tạo `lib/features/profile/presentation/profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.person_outline,
      title: Vi.profileTitle,
      body: Vi.profileComing,
    );
  }
}
```

- [ ] **Step 7: Viết 2 màn mở đè lên shell**

Hai màn này có `AppBar` riêng vì chúng nằm ngoài shell.

Tạo `lib/features/coach/presentation/coach_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.coachTitle)),
      body: const PcEmptyState(
        icon: Icons.sports_bar_outlined,
        title: Vi.coachTitle,
        body: Vi.coachComing,
      ),
    );
  }
}
```

Tạo `lib/features/notifications/presentation/notifications_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.notificationsTitle)),
      body: const PcEmptyState(
        icon: Icons.notifications_none,
        title: Vi.notificationsTitle,
        body: Vi.notificationsComing,
      ),
    );
  }
}
```

- [ ] **Step 8: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả test đạt, `analyze` sạch.

- [ ] **Step 9: Commit**

```bash
git add lib/core/router lib/core/strings lib/features test/core/router
git commit -m "Add route constants and the seven root screens

Each root screen explains what will land there rather than showing
a blank page."
```

---

## Task 9: Khung shell 5 tab

**Files:**
- Create: `lib/core/widgets/pc_shell_scaffold.dart`, `lib/core/router/app_router.dart`
- Modify: `lib/app.dart` (tạo mới), `lib/main.dart`
- Test: `test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `Routes`, 7 widget màn hình từ nhiệm vụ 8; `AppTheme` từ nhiệm vụ 7; `Vi` từ nhiệm vụ 3
- Produces:
  - `PcShellScaffold({Key? key, required StatefulNavigationShell navigationShell})`
  - `appRouter` — một `GoRouter` dùng chung
  - `PoolCoachApp` — widget gốc dùng `MaterialApp.router`

- [ ] **Step 1: Viết test thất bại**

Tạo `test/core/router/app_router_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/training/presentation/training_screen.dart';

void main() {
  group('điều hướng khung app', () {
    testWidgets('mở lên là vào tab Trang chủ', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('thanh tab hiện đủ 5 nhãn tiếng Việt', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      expect(find.text(Vi.tabHome), findsOneWidget);
      expect(find.text(Vi.tabTraining), findsOneWidget);
      expect(find.text(Vi.tabPlay), findsOneWidget);
      expect(find.text(Vi.tabStats), findsOneWidget);
      expect(find.text(Vi.tabProfile), findsOneWidget);
    });

    testWidgets('bấm tab Luyện tập thì chuyển màn', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(Vi.tabTraining));
      await tester.pumpAndSettle();

      expect(find.byType(TrainingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('bấm tab Thi đấu rồi quay lại Trang chủ', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(Vi.tabPlay));
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget);

      await tester.tap(find.text(Vi.tabHome));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('nút tròn mở màn Huấn luyện viên', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(CoachScreen), findsOneWidget);
    });

    testWidgets('chuông mở màn Thông báo', (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
    });
  });
}
```

Thêm import `package:flutter/material.dart` vào đầu file test để dùng `Icons` và `FloatingActionButton`.

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/router/app_router_test.dart
```

Kỳ vọng: FAIL — không tìm thấy `package:poolcoachai/app.dart`.

- [ ] **Step 3: Viết pc_shell_scaffold.dart**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';

/// Khung bọc 5 tab: thanh điều hướng dưới, chuông thông báo trên,
/// và nút Coach nổi dùng được ở mọi tab.
class PcShellScaffold extends StatelessWidget {
  const PcShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _icons = <IconData>[
    Icons.home_outlined,
    Icons.track_changes_outlined,
    Icons.play_circle_outline,
    Icons.bar_chart_outlined,
    Icons.person_outline,
  ];

  static const _labels = <String>[
    Vi.tabHome,
    Vi.tabTraining,
    Vi.tabPlay,
    Vi.tabStats,
    Vi.tabProfile,
  ];

  void _onTap(int index) {
    // initialLocation: true khi bấm lại chính tab đang mở sẽ đưa nhánh
    // đó về màn gốc, đúng như hành vi quen thuộc trên di động.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Vi.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: Vi.notificationsTitle,
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        tooltip: Vi.coachTitle,
        onPressed: () => context.push(Routes.coach),
        child: const Icon(Icons.sports_bar_outlined),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        backgroundColor: AppColors.bgDeep,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        items: [
          for (var i = 0; i < _icons.length; i++)
            BottomNavigationBarItem(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Viết app_router.dart**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/widgets/pc_shell_scaffold.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';
import 'package:poolcoachai/features/training/presentation/training_screen.dart';

/// Router của toàn app.
///
/// Năm tab dùng StatefulShellRoute nên mỗi tab giữ ngăn xếp riêng: đi
/// sâu ba màn trong Luyện tập, sang Thi đấu, quay lại vẫn còn nguyên.
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          PcShellScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.training,
              builder: (context, state) => const TrainingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.play,
              builder: (context, state) => const PlayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.stats,
              builder: (context, state) => const StatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.coach,
      builder: (context, state) => const CoachScreen(),
    ),
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
```

- [ ] **Step 5: Viết app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';

class PoolCoachApp extends StatelessWidget {
  const PoolCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Vi.appName,
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 6: Thay main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/app.dart';

void main() {
  runApp(const ProviderScope(child: PoolCoachApp()));
}
```

- [ ] **Step 7: Chạy test điều hướng để xác nhận đạt**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/core/router/app_router_test.dart
```

Kỳ vọng: 6 test đạt.

Nếu test cuối thất bại vì tìm thấy nhiều icon `notifications_none` (màn Thông báo cũng dùng icon đó trong `PcEmptyState`), sửa test dùng `find.byTooltip(Vi.notificationsTitle)` thay cho `find.byIcon`.

- [ ] **Step 8: Chạy toàn bộ test và phân tích**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: tất cả test đạt, `analyze` sạch.

- [ ] **Step 9: Chạy thử trên Chrome**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" run -d chrome
```

Kiểm tra bằng mắt: nền xanh nỉ, thanh 5 tab tiếng Việt ở dưới, nút tròn vàng đồng góc phải, chuông trên thanh tiêu đề. Bấm qua lại các tab, mở Coach và Thông báo rồi quay lại. Thu hẹp cửa sổ trình duyệt về khổ điện thoại để kiểm tra bố cục không vỡ.

- [ ] **Step 10: Commit**

```bash
git add lib test
git commit -m "Wire up the five-tab shell with Coach and notifications

StatefulShellRoute gives each tab its own navigation stack, so
going three screens deep in Training survives a trip to Play.
Tapping the active tab again returns that branch to its root."
```

---

## Task 10: Lưới an toàn — smoke test mọi route

**Files:**
- Create: `test/smoke/all_routes_test.dart`
- Test: chính nó

**Interfaces:**
- Consumes: `Routes`, `appRouter`, `PoolCoachApp` từ nhiệm vụ 9
- Produces: một test đi qua mọi đường dẫn đã đăng ký và khẳng định không màn nào crash. Các kế hoạch sau thêm đường dẫn mới vào `Routes` sẽ được test này tự phủ.

- [ ] **Step 1: Viết smoke test**

Tạo `test/smoke/all_routes_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';

void main() {
  group('smoke test mọi route', () {
    testWidgets('mở được mọi đường dẫn mà không crash', (tester) async {
      final paths = <String>[
        ...Routes.tabs,
        Routes.coach,
        Routes.notifications,
      ];

      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      for (final path in paths) {
        appRouter.go(path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'màn $path ném lỗi khi dựng',
        );
      }
    });

    testWidgets('mọi màn đều vẽ ra ít nhất một đoạn chữ', (tester) async {
      final paths = <String>[
        ...Routes.tabs,
        Routes.coach,
        Routes.notifications,
      ];

      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      for (final path in paths) {
        appRouter.go(path);
        await tester.pumpAndSettle();

        expect(
          find.byType(Text),
          findsWidgets,
          reason: 'màn $path không hiện chữ nào — có thể đang trắng trơn',
        );
      }
    });
  });
}
```

- [ ] **Step 2: Chạy smoke test**

```bash
"C:/Users/anhnpv/flutter/bin/flutter.bat" test test/smoke/all_routes_test.dart
```

Kỳ vọng: 2 test đạt. Nếu một màn nào crash, thông báo lỗi sẽ chỉ đúng đường dẫn gây lỗi.

- [ ] **Step 3: Chạy toàn bộ test và phân tích lần cuối**

```bash
FLUTTER="C:/Users/anhnpv/flutter/bin/flutter.bat"
"$FLUTTER" test
"$FLUTTER" analyze
```

Kỳ vọng: toàn bộ test đạt, `analyze` in "No issues found!".

- [ ] **Step 4: Commit**

```bash
git add test/smoke
git commit -m "Add a smoke test covering every registered route

Later plans that register new paths in Routes get covered by this
automatically, so a screen can never silently start crashing."
```

- [ ] **Step 5: Đẩy lên GitHub**

```bash
git push origin main
```

---

## Hoàn thành kế hoạch 1

Sau nhiệm vụ 10, cây mã phải đạt:

- `flutter analyze` sạch, không cảnh báo
- Toàn bộ test đạt
- `flutter run -d chrome` cho ra app nền xanh nỉ, 5 tab tiếng Việt, nút Coach vàng đồng, chuông thông báo
- Mọi chuỗi tiếng Việt nằm trong `vi.dart`, mọi màu nằm trong `AppColors`
- Mọi đường dẫn nằm trong `Routes` và được smoke test phủ

Kế hoạch 2 (*Vòng lặp luyện tập*) sẽ cắm repository và dữ liệu mock vào khung này, rồi dựng chuỗi Chi tiết bài tập → Chuẩn bị → Buổi tập → Hoàn thành.
