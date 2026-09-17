# PoolCoachAI

Ứng dụng huấn luyện bida cá nhân hoá cho cơ thủ Việt Nam. Giao diện hoàn toàn tiếng Việt.

Vòng lặp cốt lõi: **Đánh giá → Học → Tập → Chơi → Phân tích → Đề xuất → Tập tiếp**

---

## Đang ở đâu

**Kế hoạch 1 — Nền móng & khung điều hướng: XONG.**

| | |
|---|---|
| Nền tảng | Flutter (Android · iOS · Web) |
| Trạng thái | 43 test đạt · `flutter analyze` sạch · `flutter build web --release` chạy được |
| Chạy thử | Chrome (Android SDK chưa cài trên máy gốc) |

Đã có: khung 5 tab giữ ngăn xếp riêng, nút Huấn luyện viên nổi ở mọi tab, màn Thông báo, hệ thiết kế "Nỉ & Phấn", bảng chuỗi tiếng Việt tập trung, mô hình nhóm kỹ năng và hạng, 6 widget dùng chung.

Bảy màn gốc hiện hiển thị trạng thái "Đang xây dựng" có mô tả rõ sẽ có gì — **cố ý**, không phải chưa làm xong. Xem mục 2.1 tài liệu thiết kế: thà nói thẳng còn hơn bịa nội dung cho đầy màn hình.

**Tiếp theo — Kế hoạch 2: lớp suy luận.** Kế hoạch đã viết đầy đủ, chưa thực thi dòng nào:
`docs/superpowers/plans/2026-09-17-poolcoachai-intelligence.md`

---

## Chạy trên máy mới

### 1. Flutter

Cần **Flutter 3.47.0 / Dart 3.13.0** trở lên.

```bash
flutter --version
```

Nếu không có, cài từ https://docs.flutter.dev/get-started/install rồi `flutter doctor`.

> Trên máy đã dựng kế hoạch 1, Flutter **không** nằm trong PATH mà ở `C:\Users\anhnpv\flutter\bin\flutter.bat`. Máy đó còn một bản cũ hơn ở `D:\flutter` — không dùng. Trên máy mới, kiểm tra lại trước khi chạy bất kỳ lệnh nào trong các kế hoạch.

### 2. Lấy phụ thuộc và kiểm tra

```bash
flutter pub get
flutter analyze        # phải sạch
flutter test           # phải xanh, hiện 43 test
```

### 3. Chạy app

```bash
flutter run -d chrome
```

Muốn chạy trên điện thoại Android thì cài Android Studio trước (máy gốc chưa cài).

---

## Tài liệu — đọc theo thứ tự này

| File | Nội dung |
|---|---|
| `docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md` | **Tài liệu thiết kế chính.** Đọc mục 2.1 và 2.2 trước bất cứ thứ gì khác |
| `PRD_PoolCoachAI.md` | Mô tả sản phẩm đầy đủ |
| `Claude_desktop/PoolCoachAI_SPEC.md` | Công thức Player Intelligence và recommendation engine, phân kỳ 5 phase |
| `Claude_desktop/poolcoachai-reference.html` | Prototype, chứa dữ liệu khởi tạo (dòng 302–395) |
| `Tu-Dien-Kien-Thuc-Billiard-Pool.md` | 38 bài kiến thức thật — nội dung module Kiến thức |
| `PoolCoachAI.md` | Bản mô tả gốc, đã được PRD thay thế |
| `docs/superpowers/plans/` | Kế hoạch triển khai từng phần |

---

## Bốn quy tắc không được phá

### 1. Không bịa, không viết cứng nội dung sinh ra

Chữ cố định của giao diện (nhãn tab, tên nút) nằm trong `vi.dart` — viết sẵn là **đúng**.

Nội dung do hệ thống sinh ra (gợi ý huấn luyện viên, mục tiêu hôm nay, nội dung thông báo, kết luận thống kê) **phải tính từ dữ liệu** bằng hàm có tên, có kiểm thử. Câu chữ là khuôn có tham số, tham số do hàm điền. Thiếu dữ liệu thì nói thẳng là thiếu, không đoán.

*Phép thử:* đổi dữ liệu mẫu cho người chơi yếu nhóm khác — mọi kết luận trong app phải tự đổi theo. Không đổi nghĩa là có chỗ viết cứng.

### 2. Phân tầng AI

| Tầng | Công cụ |
|---|---|
| Player Intelligence | Dart thuần, deterministic |
| Cổng mở cấp (progression gate) | **Rule-based, cấm LLM tuyệt đối** — hỏi hai lần ra hai đáp án thì không còn là xếp hạng |
| Recommendation | Rule trước, ML sau |
| Coach Chat | LLM thật, nhưng **chỉ diễn giải** số liệu tầng 1 đã tính, không tự tính |
| Camera/Vision | Computer vision, bài toán riêng, làm sau cùng |

**API key không bao giờ nằm trong app.** Luồng: `App → Supabase Edge Function (giữ key) → Claude API`.

### 3. Thuật ngữ đã chốt

Cơ thủ đã sửa từng từ. Tiếng bida Việt Nam mượn nhiều từ **tiếng Pháp**, không dịch nghĩa đen từ tiếng Anh.

| Tiếng Việt | Gốc | |
|---|---|---|
| Ngắm bi | aiming | |
| Điều bi / Vị trí | position | *không phải "Đi bi"* |
| Phá | break | *không phải "Giao bóng"* |
| Phòng thủ | safety | |
| **A băng** | **kick** · *à bande* | bi **cái** chạm băng trước |
| **Cân bi** | **bank** | bi **mục tiêu** chạm băng |
| Đánh đứng bi | stop shot | |
| Đánh trô bi | draw · *rétro* | |
| Đánh cu lê | follow · *coulé* | |
| Chết cái | scratch | |
| Bi ảo | ghost ball | |
| Bi cái, gọi tắt "cái" | cue ball | |

⚠️ **Bẫy dễ vấp:** "bank" và "a băng" nhìn như cùng gốc nhưng **ngược nhau**. A băng = kick.

### 4. Kiến trúc

- Mọi màn hình đọc dữ liệu qua **repository interface**, không bao giờ import mock trực tiếp
- `lib/domain/` là pure Dart, không import Flutter
- Mọi màu qua `AppColors`, mọi khoảng cách qua `AppSpacing`, mọi chữ tiếng Việt qua `vi.dart`
- Riverpod **không dùng codegen**

---

## Việc còn treo

**Review độc lập cho nhiệm vụ 7–10 của kế hoạch 1 chưa chạy.** Hạ tầng phân loại của Claude Code lỗi đúng lúc đó, nên bốn nhiệm vụ cuối chỉ được chính người viết đọc lại. Cần một lượt review toàn nhánh cho `ac65e21..0b8143d` với độ soi kỹ như review từng nhiệm vụ.

**"Cân bi" chưa thuộc nhóm kỹ năng nào.** Drill `d8` trong prototype đang gắn nhầm vào `kick` — mô tả của nó là bank shot. Ba lối xử lý nằm ở đầu kế hoạch 2, cần chủ sản phẩm chốt.

**Seed data trong prototype dùng thuật ngữ cũ.** Copy nguyên văn sẽ mang toàn bộ từ sai trở lại. Kế hoạch 2 Task 2 có bảng đối chiếu và một test chặn.

**Android SDK chưa cài** trên máy gốc — không chặn gì, chạy Chrome là đủ để dựng.

---

## Cấu trúc mã

```
lib/
├── main.dart            điểm vào, bọc ProviderScope
├── app.dart             MaterialApp.router
├── core/
│   ├── theme/           AppColors · AppSpacing · AppTypography · AppTheme
│   ├── router/          Routes · createAppRouter()
│   ├── strings/vi.dart  toàn bộ chữ tiếng Việt
│   └── widgets/         PcCard · PcSectionHeader · PcEmptyState
│                        PcSkillChip · PcRankBadge · PcShellScaffold
├── domain/              SkillCategory · Rank  (pure Dart)
└── features/            home · training · play · stats · profile
                         coach · notifications
```
