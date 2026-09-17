# PoolCoachAI — Thiết kế bản khung ứng dụng Flutter

**Ngày:** 2026-09-17
**Trạng thái:** Đã chốt, sẵn sàng lập kế hoạch triển khai
**Nguồn yêu cầu:**
- `PRD_PoolCoachAI.md` — tài liệu chuẩn
- `PoolCoachAI.md` — bản gốc, đã được PRD thay thế
- `Tu-Dien-Kien-Thuc-Billiard-Pool.md` — **nội dung thật của module Kiến thức**: 38 mục, cấu trúc đồng nhất 5 phần

---

## 1. Bối cảnh & phạm vi

PoolCoachAI là nền tảng huấn luyện bida cá nhân hóa cho cơ thủ Việt Nam. Toàn bộ sản phẩm xoay quanh một vòng lặp:

```
Đánh giá → Học → Tập → Chơi → Phân tích → Đề xuất → Tập tiếp
```

PRD mô tả trọn sản phẩm, gồm nhiều hệ thống lớn độc lập: onboarding và ước lượng hạng, Training Center, Knowledge, Play, Intelligence và Coach AI, nhận diện cú đánh bằng camera, backend Supabase. Xây tất cả trong một lượt là bất khả thi.

**Lượt này xây bản khung (shell) đầy đủ 35 màn hình với dữ liệu mẫu.** Người dùng điều hướng được toàn bộ sản phẩm, đánh giá được trải nghiệm thật, nhưng không có dữ liệu nào được lưu lại sau khi đóng app.

### Trong phạm vi

- Toàn bộ 35 màn hình, mỗi màn có bố cục hoàn chỉnh và nội dung tiếng Việt thật
- Điều hướng đầy đủ: 5 tab giữ ngăn xếp riêng, Coach mở từ nút nổi, Thông báo mở từ chuông
- Hệ thiết kế "Nỉ & Phấn" áp dụng nhất quán
- Mô hình dữ liệu hoàn chỉnh (thực thể + repository interface) với bản cài đặt mock trong bộ nhớ
- Ba màn có logic tính toán thật: Đánh giá trình độ, Buổi tập, Mô phỏng góc cắt

### Ngoài phạm vi (các lượt sau)

- Lưu trữ cục bộ (Drift/SQLite) và đồng bộ Supabase
- Nhận diện cú đánh bằng camera/vision
- Coach AI thật (lượt này là kịch bản định sẵn)
- Player Intelligence thật (phát hiện điểm yếu từ dữ liệu)
- Ghi trận đấu chi tiết từng cú theo từng ván
- Xác thực người dùng, nhiều thiết bị, sao lưu đám mây

---

## 2. Các quyết định đã chốt

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| Nền tảng | Flutter (iOS + Android) | Đa nền tảng, phù hợp cho ghi hình bằng camera ở lượt sau |
| SDK | Flutter 3.47.0 tại `C:\Users\anhnpv\flutter` | Bản mới hơn trong hai bản có sẵn trên máy |
| Chạy thử khi dựng | Chrome trước, Android sau | Không phải chờ cài Android SDK; đủ để đánh giá bố cục và điều hướng |
| Ngôn ngữ giao diện | **Tiếng Việt hoàn toàn**, kể cả thuật ngữ chuyên môn | Người dùng mục tiêu là cơ thủ Việt Nam |
| Quản lý trạng thái | `flutter_riverpod`, **không dùng codegen** | Tránh `build_runner` chạy lại liên tục khi sửa 35 màn |
| Điều hướng | `go_router` với `StatefulShellRoute` | 5 tab giữ ngăn xếp độc lập |
| Cấu trúc | Feature-first | Màn hình nằm cạnh trạng thái của nó; file nhỏ, dễ sửa |
| Điều hướng gốc | 5 tab + Coach là nút nổi + Thông báo là chuông | 7 module không vừa thanh tab; Coach là điểm khác biệt nên phải với tới từ mọi nơi |
| Hướng thiết kế | **"Nỉ & Phấn"** — xanh nỉ bàn bida + vàng đồng | Bản sắc riêng, không giống app thể thao đại trà |
| Phạm vi lượt này | Cả 35 màn, chia 3 mức hoàn thiện | Chủ sản phẩm muốn thấy trọn bản đồ sớm |
| Dữ liệu | Mock trong bộ nhớ, sau repository interface | Đổi sang Drift/Supabase chỉ sửa một dòng provider |
| Nội dung Kiến thức | **Dùng 38 mục thật** từ từ điển, không bịa mock | Nội dung đã có sẵn và có cấu trúc đồng nhất |

---

## 3. Kiến trúc kỹ thuật

### 3.1 Thư viện

| Mục đích | Gói | Ghi chú |
|---|---|---|
| Trạng thái | `flutter_riverpod` | Dùng `Notifier`/`AsyncNotifier` viết tay, không codegen |
| Điều hướng | `go_router` | `StatefulShellRoute.indexedStack` cho 5 tab |
| Biểu đồ | `fl_chart` | Thống kê, tiến bộ theo kỹ năng |
| Font | `google_fonts` | Be Vietnam Pro + JetBrains Mono |
| Mô phỏng góc cắt | `CustomPainter` (có sẵn trong Flutter) | Không cần gói ngoài |
| Lưu trữ | *chưa dùng* | Toàn bộ mock trong bộ nhớ |

### 3.2 Cấu trúc thư mục

```
lib/
├── main.dart
├── app.dart                      PoolCoachApp: router + theme
├── core/
│   ├── theme/
│   │   ├── app_colors.dart       bảng màu Nỉ & Phấn
│   │   ├── app_typography.dart   thang chữ
│   │   ├── app_spacing.dart      thang khoảng cách + bo góc
│   │   └── app_theme.dart        ThemeData ghép lại
│   ├── router/
│   │   ├── app_router.dart       GoRouter, 35 route
│   │   └── routes.dart           hằng số đường dẫn
│   ├── strings/
│   │   └── vi.dart               TOÀN BỘ chữ tiếng Việt, một chỗ duy nhất
│   └── widgets/                  PcCard, PcSectionHeader, PcStatTile,
│                                 PcSkillChip, PcRankBadge, PcEmptyState,
│                                 PcProgressBar, PcShotButtons, PcLevelPill,
│                                 PcDrillTile, PcCueCard, PcTimerRing,
│                                 PcBottomNav, PcCoachFab
├── domain/                       Player, Rank, SkillCategory, MeasurementUnit
├── data/
│   ├── mock/                     dữ liệu mẫu tĩnh
│   └── repositories/             interface + bản in-memory
└── features/
    ├── onboarding/               splash · welcome · assessment · result
    ├── home/                     AI Home
    ├── notifications/
    ├── training/
    │   ├── center/               trung tâm luyện tập
    │   ├── drills/               danh sách · chi tiết
    │   ├── session/              chuẩn bị · buổi tập · hoàn thành
    │   ├── simulator/            mô phỏng góc cắt
    │   ├── timer/                đồng hồ luyện tập
    │   ├── schedule/             lịch tập hằng tuần
    │   ├── knowledge/            danh sách · chi tiết
    │   ├── ai_path/              lộ trình AI
    │   └── skill_test/           kiểm tra kỹ năng · chứng nhận
    ├── play/                     trang chính · ghi trận · lịch sử · chi tiết · giải đấu
    ├── coach/                    chat · phân tích · đề xuất
    ├── stats/                    tổng quan · phân tích chi tiết
    └── profile/                  hồ sơ · cơ bi-a · chi tiết cơ · lịch sử · cài đặt
```

Mỗi thư mục feature chia ba phần: `presentation/` (màn hình + widget riêng của feature), `application/` (provider, controller), `domain/` (model riêng của feature).

### 3.3 Cây điều hướng

```
Ngoài shell:
  /splash → /welcome → /assessment → /assessment/result

ShellRoute (thanh 5 tab + nút Coach nổi):
  /home
  /training
    ├── /training/ai-path
    ├── /training/drills
    │     └── /training/drills/:id
    │           └── /training/drills/:id/prepare
    │                 └── /training/drills/:id/session
    │                       └── /training/drills/:id/complete
    ├── /training/simulator
    ├── /training/timer
    ├── /training/schedule
    ├── /training/knowledge
    │     └── /training/knowledge/:id
    └── /training/skill-test
          └── /training/skill-test/certificate
  /play
    ├── /play/record
    ├── /play/history
    │     └── /play/history/:id
    └── /play/tournament
  /stats
    └── /stats/analytics
  /profile
    ├── /profile/cues
    │     └── /profile/cues/:id
    ├── /profile/history
    └── /profile/settings

Mở đè lên shell:
  /coach            (từ nút nổi, dùng được ở mọi tab)
  /notifications    (từ chuông trên thanh tiêu đề)
```

### 3.4 Nguyên tắc bất di bất dịch

**Không màn hình nào được import dữ liệu mock trực tiếp.** Mọi màn đọc qua repository interface, lấy từ provider:

```dart
abstract class DrillRepository {
  Future<List<Drill>> getAll();
  Future<Drill?> getById(String id);
  Future<List<Drill>> search({String? query, SkillCategory? skill, int? level});
}

final drillRepositoryProvider = Provider<DrillRepository>(
  (ref) => MockDrillRepository(),
);
```

Lượt sau đổi sang `DriftDrillRepository` hoặc `SupabaseDrillRepository` chỉ sửa **một dòng**, không đụng vào bất kỳ màn hình nào. Đây chính là yêu cầu của PRD mục 12: *"business logic và UI không phụ thuộc cứng vào backend implementation"*.

---

## 4. Hệ thiết kế "Nỉ & Phấn"

### 4.1 Bảng màu

**Nền & viền** — sắc nỉ bàn bida

| Vai trò | Mã |
|---|---|
| Nền sâu nhất (thanh tab) | `#0E1F16` |
| Nền màn hình | `#12261C` |
| Thẻ / card | `#18301F` |
| Thẻ nổi | `#1B3527` |
| Viền | `#27462F` |
| Viền đậm | `#3A6044` |

**Nhấn & chữ** — phấn và đồng

| Vai trò | Mã |
|---|---|
| Nhấn chính | `#D9A441` |
| Nhấn sáng | `#E8BC63` |
| Chữ chính | `#EFE7D6` |
| Chữ phụ | `#C6D3C6` |
| Chữ mờ | `#9FB0A3` |
| Chữ tắt | `#6F8677` |

**Trạng thái**

| Vai trò | Mã |
|---|---|
| Thành công | `#5FBF7E` |
| Thất bại | `#E2685C` |
| Cảnh báo | `#E5A93C` |
| Thông tin | `#6FA8D6` |

**5 nhóm kỹ năng** — màu cố định, dùng xuyên suốt ở bộ lọc bài tập, biểu đồ thống kê, nhãn đồng hồ luyện tập và gợi ý của Coach

| Nhóm | Chữ | Nền | Viền |
|---|---|---|---|
| Ngắm bi | `#E8B44C` | `#4A3A14` | `#6B5220` |
| Điều bi / Vị trí | `#6FA8D6` | `#1E3648` | `#2F5578` |
| Phá | `#E2685C` | `#4A2320` | `#7A3A34` |
| Phòng thủ | `#9B8BD6` | `#322B4A` | `#4B4277` |
| A băng | `#4FB3A5` | `#14403C` | `#226B62` |

**Hạng**

| Nhóm | Hạng | Kiểu |
|---|---|---|
| Phong trào | K · I · H · G | Chữ `#8FA396` trên nền `#26412E` |
| Cạnh tranh | F · E · D · C · B · A | Chữ `#E8B44C` trên nền `#4A3A14` |
| Chuyên nghiệp | Professional | Chữ `#12261C` trên nền `#EFE7D6` |

App phải kèm dòng chú thích: đây là bảng định nghĩa của PoolCoachAI, không phải chuẩn xếp hạng quốc gia duy nhất; cách gọi hạng khác nhau giữa các CLB và khu vực. "Chưa từng chơi" không hiển thị như một cấp hạng.

### 4.2 Kiểu chữ

- **Be Vietnam Pro** cho toàn bộ giao diện. Đây là font Google thiết kế riêng cho tiếng Việt; dấu má cân đối, không vỡ ở chữ hoa có dấu như `MỤC TIÊU HÔM NAY` hay `Ữ`, `Ỡ`.
- **JetBrains Mono** cho số liệu. Chữ số đều bề ngang nên bảng thống kê và đồng hồ đếm ngược không bị nhảy.

| Cấp | Cỡ / đậm | Dùng cho |
|---|---|---|
| display | 32 / 800 | Tên bài tập ở màn chi tiết |
| h1 | 24 / 700 | Tiêu đề màn hình |
| h2 | 20 / 700 | Tiêu đề khối lớn |
| h3 | 16 / 600 | Tiêu đề mục |
| body | 14 / 400 | Nội dung chính |
| caption | 12 / 400 | Chú thích, dữ liệu phụ |
| label | 11 / 700, giãn chữ `.1em`, IN HOA | Nhãn mục — ví dụ `HUẤN LUYỆN VIÊN AI` |

### 4.3 Thang khoảng cách & bo góc

- Khoảng cách theo bội số 4: `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48`
- Bo góc: nhỏ `8`, vừa `12`, lớn `16`, rất lớn `22`, viên thuốc `999`
- Trên nền tối, **phân tách bằng viền chứ không bằng đổ bóng** — đổ bóng gần như vô hình trên nền xanh đậm

### 4.4 Component dùng chung

Đặt trong `core/widgets/`, 35 màn dùng chung:

| Component | Mô tả |
|---|---|
| `PcCard` | Thẻ nền `#18301F`, viền `#27462F`, bo `12` |
| `PcSectionHeader` | Nhãn IN HOA + nút "Xem tất cả" tùy chọn |
| `PcStatTile` | Số lớn (JetBrains Mono, màu nhấn) + nhãn nhỏ bên dưới |
| `PcSkillChip` | Viên thuốc màu theo 1 trong 5 nhóm kỹ năng |
| `PcRankBadge` | Huy hiệu hạng, đổi màu theo nhóm phong trào / cạnh tranh / pro |
| `PcProgressBar` | Thanh tiến độ + nhãn ngưỡng đạt |
| `PcShotButtons` | Hai nút ✓ / ✗ **cỡ lớn** — người chơi bấm khi một tay đang cầm cơ |
| `PcLevelPill` | Nhãn `CẤP 1` / `CẤP 2` / `CẤP 3` |
| `PcDrillTile` | Dòng bài tập: icon kỹ năng · tên · cấp · tiến độ |
| `PcCueCard` | Thẻ cơ bi-a, có cảnh báo khi tip quá hạn bảo dưỡng |
| `PcTimerRing` | Vòng tròn đếm giờ cho Đồng hồ luyện tập |
| `PcEmptyState` | Icon + tiêu đề + gợi ý hành động, dùng cho các màn mức khung |
| `PcBottomNav` | Thanh 5 tab |
| `PcCoachFab` | Nút tròn 🎱 mở Coach, nổi trên mọi tab |

---

## 5. Bảng thuật ngữ

Chủ sản phẩm đã sửa 9 thuật ngữ. Phát hiện quan trọng: **tiếng bida Việt Nam mượn nhiều từ tiếng Pháp**, không dịch nghĩa đen từ tiếng Anh.

Toàn bộ chuỗi tiếng Việt nằm trong `core/strings/vi.dart`. Khóa trong code giữ tiếng Anh (`SkillCategory.bank`), nên đổi cách gọi chỉ sửa một dòng.

| Tiếng Việt | Gốc | Ghi chú |
|---|---|---|
| Ngắm bi | aiming | Nhóm kỹ năng 1 |
| **Điều bi / Vị trí** | position | Nhóm kỹ năng 2 — *không phải "Đi bi"* |
| **Phá** | break | Nhóm kỹ năng 3 — *không phải "Giao bóng"* |
| Phòng thủ | safety | Nhóm kỹ năng 4 |
| **A băng** | bank · *à bande* | Nhóm kỹ năng 5 — *không phải "Bi băng"* |
| **Đánh đứng bi** | stop shot | Tên bài tập |
| **Đánh trô bi** | draw · *rétro* | Tên bài tập |
| **Đánh cu lê** | follow · *coulé* | Tên bài tập |
| **Chết cái** | scratch | Thống kê trận đấu — *không phải "Lỗi trắng"* |
| **Bi ảo** | ghost ball | Mô phỏng góc cắt — *không phải "Bi ma"* |
| Bi cái · "cái" | cue ball | Suy ra từ "chết cái" |
| Chấm / dọn bàn | runout | Câu 5 & 6 bài đánh giá |
| Ván | rack | Ghi trận đấu |
| Lỗi | foul | Ghi trận đấu |
| Bi mục tiêu | object ball | Mô phỏng, hướng dẫn bài tập |
| Góc cắt | cut angle | Mô phỏng góc cắt |
| Đầu cơ / tip | tip | Quản lý cơ |
| Cơ phá | break cue | Loại cơ |
| Cơ nhảy | jump cue | Loại cơ |

Ba cú đánh nền tảng của nhóm Điều bi tạo thành một bộ gốc Pháp: **đánh đứng bi** (stop) · **đánh trô bi** (*rétro*) · **đánh cu lê** (*coulé*).

---

## 6. Mô hình dữ liệu

Mock rồi sẽ vứt đi, nhưng hình dạng dữ liệu thì ở lại — Drift và Supabase sau này bám theo đúng sơ đồ này.

### 6.1 Ba loại "buổi" tách biệt

PRD nêu rõ dữ liệu TẬP và CHƠI không trộn lẫn thành một loại session. Thực tế có **ba** loại, không phải hai:

| Loại | Thuộc về | Đặc điểm |
|---|---|---|
| `DrillSession` | Luyện tập, có bài | Gắn Drill + Cấp; ghi từng cú hoặc tổng; có ngưỡng đạt để mở cấp sau |
| `PracticeSession` | Luyện tập, tự do | Chỉ có đồng hồ; gắn nhãn kỹ năng + cơ; tính vào tổng giờ & streak; **không có đạt/trượt** |
| `Match` | Thi đấu | Đối thủ, thể loại, tỷ số, chia theo ván; **không bao giờ là một buổi tập** |

Nếu gộp ba thứ này thành một bảng, toàn bộ tầng phân tích sau này sẽ sai. Chúng chỉ gặp nhau ở tầng Thống kê:

```
DrillSession    ─┐
PracticeSession  ┼─→ Statistics → PlayerIntelligence → Coach → Recommendation
Match           ─┘
```

### 6.2 Thực thể

**Người chơi & hạng**

| Thực thể | Trường chính |
|---|---|
| `Player` | id · tên · `rank` · `streakDays` · `totalPracticeMinutes` · ngàyTạo |
| `Rank` | enum `K I H G F E D C B A PRO` + nhóm `phongTrào / cạnhTranh / pro` |
| `AssessmentResult` | 8 đáp án → `estimatedRank` · `confidence` — **chỉ là baseline, không cố định** |

**Luyện tập**

| Thực thể | Trường chính |
|---|---|
| `SkillCategory` | enum `aiming · position · breakShot · safety · bank` |
| `Drill` | id · tên · `skillCategory` · mô tả · `steps[]` · `levels[]` · `relatedKnowledgeIds[]` |
| `DrillLevel` | `level` (1·2·3) · nhãn độ khó · `measurementUnit` · `targetValue` · `passThreshold` |
| `MeasurementUnit` | enum `shots` (✓/✗) · `ratio` (7/10) · `distanceCm` · `seconds` |
| `DrillSession` | id · drillId · level · thờiGianBắtĐầu/KếtThúc · `recordingMode` (camera/manual) · `shots[]` · `aggregateValue` · `successRate` · `passed` · `cueId` |
| `ShotResult` | thứTự · `success` · thờiĐiểm · `source` (camera/manual) |
| `PracticeSession` | id · thờiGianBắtĐầu · `durationMinutes` · `skillCategory` · `cueId` · ghiChú |
| `ScheduleEntry` | id · thứTrongTuần · giờBắtĐầu · thờiLượng · `skillCategory` · bật/tắt |
| `Knowledge` | id · số thứ tự · tiêuĐề · `category` · `description` · `steps[]` · `notes[]` · `mistakes[]` · `fixes[]` · `relatedDrillIds[]` · `readTimeMinutes` |
| `KnowledgeMistake` | `symptom` (hiện tượng quan sát được) · `cause` (nguyên nhân) |
| `SkillTest` → `Certification` | tiêuChíĐạt · lầnThử[] → chứngNhận · ngàyĐạt |

**Thi đấu**

| Thực thể | Trường chính |
|---|---|
| `Match` | id · đốiThủ · thểLoại (8/9/10-ball) · ngày · kếtQuả · tỷSố · `racks[]` |
| `Rack` | thứTự · aiPhá · thắng? · `shots[]` |
| `MatchShot` | `type`: vàoBi · phòngThủ · trượt · chếtCái · lỗi · phá · lỗiViTrí |

**Dụng cụ & hệ thống**

| Thực thể | Trường chính |
|---|---|
| `Cue` | tên · `type` (cơChính/cơPhá/cơNhảy) · trọngLượng · cỡTip · độCứngTip · `suitedSkills[]` · `lastTipMaintenance` · chuKỳ → cảnh báo quá hạn |
| `Notification` | `type`: lịchTập · bảoDưỡngCơ · đềXuấtMới · sắpMấtStreak |
| `CoachMessage` | vaiTrò (user/coach) · nộiDung · thờiĐiểm · đềXuấtĐínhKèm? |
| `Recommendation` | lýDo · `targetType` (drill/knowledge/simulator) · targetId |

Thống kê là dữ liệu **suy ra**, không lưu.

### 6.3 Kiến thức — cấu trúc và phân loại

Từ điển có 38 mục, **mọi mục đều theo đúng một khuôn 5 phần**. Vì vậy `Knowledge` là thực thể có cấu trúc, không phải một khối markdown:

| Trường trong từ điển | Trường trong model | Hiển thị |
|---|---|---|
| Mô tả | `description` | Đoạn mở đầu |
| Hướng dẫn thực hiện | `steps[]` | Danh sách đánh số |
| Các lưu ý để thực hiện | `notes[]` | Danh sách gạch đầu dòng |
| Các lỗi thường gặp | `mistakes[]` — mỗi lỗi gồm `symptom` + `cause` | Thẻ đỏ, tiêu đề là **hiện tượng** |
| Cách sửa | `fixes[]` | Thẻ xanh ngay dưới phần lỗi |

Lỗi được mô tả theo **hiện tượng quan sát được** ("bi cái rẽ trái", "bi cái bị hút ngược lại") chứ không phải theo thuật ngữ kỹ thuật. Đây là dữ liệu chẩn đoán có sẵn cho Coach ở các lượt sau: người chơi tả hiện tượng → tra ra nguyên nhân → đề xuất bài tập. Lượt này chỉ hiển thị, chưa dùng để chẩn đoán.

**Phân loại.** Năm nhóm kỹ năng không phủ hết nội dung từ điển — cầm cơ, tư thế, luật 9-ball, bảo trì cơ không thuộc nhóm nào. Do đó `KnowledgeCategory` gồm 9 giá trị: 5 nhóm kỹ năng sẵn có, cộng 4 nhóm mới.

| Nhóm mới | Nội dung từ điển | Màu |
|---|---|---|
| Nền tảng | Cầm cơ · tư thế · cầu tay · ra cơ · các phương pháp ngắm | Chữ `#C6D3C6` nền `#26412E` viền `#3A6044` |
| Chiến thuật & Tâm lý | Đọc bàn · kế hoạch dọn bàn · phòng thủ nâng cao · tâm lý thi đấu · khởi động | Chữ `#D9A441` nền `#4A3A14` viền `#6B5220` |
| Luật chơi | 8-Ball · 9-Ball · 10-Ball · 14.1 · One Pocket | Chữ `#9FB0A3` nền `#1B3527` viền `#2F5139` |
| Thiết bị | Chọn cơ · bảo trì cơ và dụng cụ | Chữ `#6FA8D6` nền `#1E3648` viền `#2F5578` |

Nhóm kỹ năng vẫn giữ nguyên 5 giá trị và màu như mục 4.1 — `KnowledgeCategory` là tập rộng hơn, chỉ dùng cho Kiến thức, không thay `SkillCategory` của Drill.

### 6.4 Repository

Chín interface, mỗi cái có một bản `Mock…` in-memory ở lượt này:

`PlayerRepository` · `DrillRepository` · `SessionRepository` · `ScheduleRepository` · `KnowledgeRepository` · `MatchRepository` · `CueRepository` · `CoachRepository` · `NotificationRepository`

---

## 7. Danh sách 35 màn hình & mức hoàn thiện

Không màn nào bị bỏ trống, nhưng công sức chia theo mức độ quan trọng.

- **Đầy đủ (15 màn)** — tương tác thật, trạng thái thật, có kiểm thử
- **Đọc được (13 màn)** — hiện dữ liệu mock thật, bố cục hoàn chỉnh, hành động giản lược
- **Khung (7 màn)** — bố cục + trạng thái rỗng + ghi chú "lượt sau"

### Khởi động — 4 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| Đánh giá trình độ | Đầy đủ | 8 câu, tính hạng thật từ đáp án |
| Kết quả — Hạng của bạn | Đọc được | Kèm chú thích "đây là bảng của PoolCoachAI" |
| Chào mừng | Đọc được | |
| Splash | Đọc được | |

### 🏠 Trang chủ — 2 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| AI Home | Đầy đủ | Gợi ý AI · Mục tiêu hôm nay · Tiếp tục · **Lịch hôm nay** · **Streak & giờ tập** · Truy cập nhanh |
| Thông báo | Đọc được | Nhắc lịch · cơ quá hạn · đề xuất mới · sắp mất streak |

### 🎯 Luyện tập — 14 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| Trung tâm luyện tập | Đầy đủ | Cửa vào mọi nhánh luyện tập |
| Tất cả bài tập | Đầy đủ | Tìm kiếm + lọc theo 5 kỹ năng và cấp, chạy thật |
| Chi tiết bài tập | Đầy đủ | Mục tiêu · các bước · kiến thức liên quan · lịch sử gần nhất |
| Chuẩn bị ghi hình | Đầy đủ | Setup bàn/camera · xác nhận "Tôi đã sẵn sàng" · **checklist khởi động lấy từ mục 23.1 của từ điển** (quy trình 3 giai đoạn, ~5 phút) |
| Buổi tập | Đầy đủ | ✓/✗ · 7/10 · cm · giây — giao diện đổi theo đơn vị đo của bài |
| Hoàn thành | Đầy đủ | Tính kết quả thật từ session, cập nhật tiến độ |
| Mô phỏng góc cắt | Đầy đủ | Kéo thả bi cái/bi mục tiêu/lỗ · vẽ bi ảo · tính góc cắt |
| Đồng hồ luyện tập | Đầy đủ | Đếm lên/xuống, gắn nhãn kỹ năng + cơ, lưu vào tổng giờ |
| Lịch tập hằng tuần | Đọc được | |
| Lộ trình AI | Đọc được | |
| Kiến thức — danh sách | **Đầy đủ** | 38 bài thật · tìm kiếm · lọc theo 9 nhóm `KnowledgeCategory` |
| Kiến thức — chi tiết | **Đầy đủ** | 5 phần có cấu trúc · lỗi→cách sửa · liên kết hai chiều với bài tập |
| Kiểm tra kỹ năng | Khung | |
| Chứng nhận | Khung | |

### ▶ Thi đấu — 5 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| Trang Thi đấu | Đọc được | |
| Lịch sử trận | Đọc được | |
| Chi tiết trận | Đọc được | Theo ván · chết cái · phòng thủ · lỗi |
| Ghi trận đấu | Đọc được | **Bản giản lược: ghi theo ván** (tỷ số, ai phá, kết quả ván). Ghi chi tiết từng cú để lượt sau |
| Giải đấu | Khung | |

### 🎱 Huấn luyện viên — 3 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| Chat với AI | Đầy đủ | Kịch bản định sẵn, bám sát dữ liệu mẫu |
| Phân tích | Khung | |
| Đề xuất | Khung | |

### 📊 Thống kê — 2 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| Tổng quan | Đọc được | Biểu đồ thật từ 24 buổi tập + 8 trận |
| Phân tích chi tiết | Khung | |

### 👤 Hồ sơ — 5 màn

| Màn | Mức | Ghi chú |
|---|---|---|
| Cơ bi-a — danh sách | Đầy đủ | Cảnh báo tip quá hạn bảo dưỡng |
| Chi tiết cơ | Đầy đủ | Loại · trọng lượng · cỡ/độ cứng tip · kỹ năng phù hợp · ngày bảo dưỡng · **liên kết tới mục 29 "Chọn cơ" và 30 "Bảo trì cơ"** của từ điển |
| Hồ sơ & Hạng | Đọc được | |
| Cài đặt | Đọc được | |
| Lịch sử | Khung | |

**Tổng: 4 + 2 + 14 + 5 + 3 + 2 + 5 = 35 màn** (15 đầy đủ · 13 đọc được · 7 khung)

---

## 8. Nội dung mẫu

Dữ liệu mẫu được dựng **có chủ đích**, không ngẫu nhiên. Người chơi mẫu là **hạng G, mạnh Ngắm bi nhưng yếu Điều bi**. Nhờ vậy biểu đồ có hình dạng thật và lời khuyên của Coach trên AI Home khớp với số liệu phía dưới, thay vì mỗi màn một kiểu bịa.

| Loại | Số lượng | Ghi chú |
|---|---|---|
| Bài tập | 18 | Trải đều 5 nhóm kỹ năng, mỗi bài 3 cấp. Gồm **Đánh đứng bi · Đánh trô bi · Đánh cu lê** |
| Bài kiến thức | **38 — nội dung thật, không mock** | Chuyển từ `Tu-Dien-Kien-Thuc-Billiard-Pool.md` sang dữ liệu có cấu trúc, gán `KnowledgeCategory` và liên kết hai chiều với bài tập |
| Buổi tập đã hoàn thành | 24 | Để biểu đồ có đường tiến bộ thật |
| Buổi tập tự do (đồng hồ) | 9 | |
| Trận đấu | 8 | Có ván và cú đánh chi tiết |
| Cơ bi-a | 3 | **1 cây quá hạn bảo dưỡng tip** để thấy cảnh báo hoạt động |
| Mục lịch tập hằng tuần | 5 | |
| Thông báo | 6 | Đủ 4 loại |
| Tin nhắn Coach mẫu | 8 | |

---

## 9. Kiểm thử

| Loại | Nội dung |
|---|---|
| Unit | Tính hạng từ 8 câu đánh giá · tỷ lệ thành công theo từng `MeasurementUnit` · cổng mở cấp · tính streak · phát hiện tip quá hạn · hình học bi ảo và góc cắt · **tính toàn vẹn dữ liệu Kiến thức** (đủ 38 mục, mục nào cũng có mô tả và ít nhất một bước, mọi lỗi đều có nguyên nhân) |
| Widget | Buổi tập (bấm ✓/✗ cập nhật đúng trạng thái) · Đồng hồ (chạy/dừng/lưu) · Đánh giá (8 câu ra đúng hạng) · Mô phỏng (kéo bi → đường ngắm đổi theo) |
| Smoke | **Một test đi qua cả 35 route**, không màn nào crash — lưới an toàn quan trọng nhất của một bản khung |
| Tĩnh | `flutter analyze` sạch, không cảnh báo |

---

## 10. Thứ tự dựng

Mười bước, mỗi bước chạy được và commit riêng:

| # | Bước | Nội dung |
|---|---|---|
| 1 | Nền móng | Scaffold dự án · theme Nỉ & Phấn · `vi.dart` · router · core widgets · domain models · mock repositories |
| 2 | Khung điều hướng | 5 tab + Coach FAB + Thông báo — **chạy được lần đầu** |
| 3 | Vòng lặp cốt lõi | Trung tâm → Bài tập → Chi tiết → Chuẩn bị → Buổi tập → Hoàn thành |
| 4 | Onboarding | Splash → Chào mừng → Đánh giá 8 câu → Kết quả hạng |
| 5 | Công cụ | Mô phỏng góc cắt · Đồng hồ · Lịch tập |
| 6 | Nội dung | **Chuyển 38 mục từ điển sang dữ liệu có cấu trúc** · Kiến thức danh sách + chi tiết · gán `KnowledgeCategory` · nối hai chiều với 18 bài tập · Lộ trình AI |
| 7 | Thi đấu | Trang Thi đấu · Lịch sử · Chi tiết · Ghi trận (theo ván) |
| 8 | Hồ sơ | Hồ sơ · Cơ bi-a · Chi tiết cơ · Cài đặt |
| 9 | Thống kê & Coach | Tổng quan có biểu đồ · Chat Coach |
| 10 | Hoàn tất | 7 màn khung còn lại + smoke test 35 route |

---

## 11. Điều kiện tiên quyết & rủi ro

### Môi trường phát triển

**Flutter SDK đã có sẵn.** Dùng bản `C:\Users\anhnpv\flutter` — Flutter **3.47.0** stable, Dart **3.13.0**. Máy còn một bản cũ hơn ở `D:\flutter` (3.44.6), **không dùng** cho dự án này.

SDK không nằm trong PATH, nên mọi lệnh gọi bằng đường dẫn đầy đủ: `C:\Users\anhnpv\flutter\bin\flutter.bat`. (Thêm `C:\Users\anhnpv\flutter\bin` vào PATH là tùy chọn, không bắt buộc.)

**Thiết bị chạy thử: Chrome trước, Android sau.** Trong lúc dựng 35 màn, chạy trên Chrome là đủ để đánh giá bố cục, điều hướng và màu sắc, lại không phải chờ cài gì.

| Hạng mục | Trạng thái | Ảnh hưởng |
|---|---|---|
| Flutter 3.47.0 · Dart 3.13.0 | ✅ | `flutter analyze`, `flutter test` chạy được ngay — toàn bộ mục 9 hoạt động |
| Chrome · Edge | ✅ | Chạy và xem app được ngay |
| Android SDK | ❌ chưa có | Cần Android Studio khi muốn thử trên điện thoại thật. Không chặn việc dựng |
| Visual Studio C++ | ❌ chưa có | Chỉ cần cho bản Windows desktop — ngoài phạm vi |
| iOS | ❌ không thể | Build iOS bắt buộc phải có macOS. Giới hạn của Apple, không phải lỗi cấu hình |

**Hệ quả cần lưu ý khi dựng:** vì kiểm chứng chủ yếu trên Chrome, mọi thứ phụ thuộc nền tảng phải được để dành hoặc bọc sau interface — quyền camera, thông báo hệ thống, lưu trữ thiết bị. Ở lượt này không có phần nào như vậy, nhưng cần nhớ khi thêm camera ở lượt sau. Bố cục phải được kiểm tra ở khổ hẹp cỡ điện thoại chứ không phải cửa sổ trình duyệt rộng.

### Rủi ro

| Rủi ro | Cách xử lý |
|---|---|
| 35 màn là phạm vi lớn; các màn mức "khung" có thể gây cảm giác trống rỗng | Mỗi màn khung có `PcEmptyState` giải thích rõ sẽ có gì ở lượt sau, không để trắng |
| Mô phỏng góc cắt là công việc thật, không mock được | Lượt này làm bản dùng được nhưng đơn giản: kéo thả + bi ảo + góc cắt. Ước lượng độ khó và nối vào Lộ trình AI để lượt sau |
| Ghi trận đấu chi tiết từng cú tương đương một luồng lớn | Lượt này ghi theo ván; ghi từng cú là một lượt riêng |
| Thuật ngữ bida có thể khác giữa các vùng | Toàn bộ chuỗi nằm trong `vi.dart`; đổi cách gọi chỉ sửa một dòng |
| Không có lưu trữ — đóng app là mất dữ liệu | Có chủ đích ở lượt này. Repository interface đã sẵn sàng để cắm Drift vào |
| Chuyển 38 mục từ điển sang dữ liệu có cấu trúc là việc thủ công, dễ sai sót | Làm thành bước riêng (bước 6) với kiểm thử đếm: đủ 38 mục, mục nào cũng có `description` và ít nhất một `step`, mọi `mistake` đều có `cause` |
| 7 mục trong từ điển dùng nhãn lỗi khác (*"theo hiện tượng cụ thể"*) | Vẫn cùng khuôn `symptom` + `cause`, chỉ khác tiêu đề — xử lý như nhau khi chuyển đổi |

---

## 12. Bước tiếp theo

Sau khi tài liệu này được duyệt: lập kế hoạch triển khai chi tiết theo 10 bước ở mục 10, mỗi bước có tiêu chí hoàn thành và kiểm thử cụ thể.
