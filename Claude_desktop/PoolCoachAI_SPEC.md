# PoolCoachAI — Technical Build Spec (cho Claude Code)

> Đọc toàn bộ file này trước khi code. File này định nghĩa: phạm vi từng phase, data model, công thức tính toán, và tiêu chí hoàn thành cho PoolCoachAI — để code đúng ngay từ đầu, không cần đoán ý.

---

## 0. Prototype tham khảo

Đã có 1 bản prototype chạy được, single-file HTML/CSS/JS (vanilla, không framework), lưu dữ liệu bằng `localStorage`, dùng làm **tài liệu tham khảo hành vi UI + logic của Phase 1** (không bắt buộc giữ nguyên kiến trúc kỹ thuật — có thể viết lại bằng stack phù hợp hơn, xem mục 1.2). File đính kèm cùng thư mục: `poolcoachai-reference.html`.

Những gì đã được implement và validate trong prototype, **giữ nguyên logic khi build lại**:
- Data model cho `drills`, `logs`, `schedule`, `cues`, `timerHistory`
- Công thức tính streak, tổng giờ tập
- Simulator tính góc cắt bằng phương pháp ghost ball
- Công thức Player Intelligence (mastery score, trend, weak/strong, ready-for-level-up) — xem mục 5, đây là phần quan trọng nhất, đã được unit-test bằng dữ liệu mẫu.

---

## 1. Phạm vi & Kiến trúc

### 1.1 Nguyên tắc thiết kế hệ thống
- **TẬP** (Training Center) và **CHƠI** (Play) là hai loại dữ liệu tách biệt, không trộn thành một loại session. Chúng chỉ gặp nhau ở tầng Statistics/Intelligence/Coach.
- **AI dẫn đường, người chơi quyết định.** Không module nào được khóa cứng người dùng vào một luồng bắt buộc, trừ progression *bên trong* một Drill (level gate).
- **Logic thuần trước, AI sau.** Player Intelligence, Skill Test gate, và mọi con số hiển thị cho người dùng phải được tính bằng công thức xác định (deterministic), không qua LLM. LLM (Coach Chat) chỉ được đọc **kết quả đã tính sẵn** làm ngữ cảnh để trả lời, không được tự suy ra số liệu.
- **Local-first.** Chạy được đầy đủ không cần backend/tài khoản. Kiến trúc lưu trữ phải cho phép gắn sync layer (Supabase) sau này mà không đổi lại business logic — tách rõ lớp `data access` khỏi UI và khỏi logic tính toán.

### 1.2 Gợi ý stack (không bắt buộc, Claude Code có thể chọn khác nếu hợp lý hơn)
- Frontend: React + TypeScript + Vite (hoặc Next.js nếu cần SSR sau này), Tailwind cho styling
- State/storage local: IndexedDB (qua Dexie.js) hoặc localStorage cho V1 nếu dữ liệu nhỏ
- Kiến trúc thư mục đề xuất:
  ```
  /src
    /domain          # types + pure logic, KHÔNG import React (drills, intelligence, streak...)
    /data            # data access layer (local storage adapter, sau này thêm supabase adapter)
    /features
      /training-center
      /play
      /coach
      /statistics
      /profile
    /components      # UI dùng chung
    /content         # seed data: drills.json, knowledge.json
  ```
  Lý do tách `/domain` khỏi UI: Player Intelligence và các công thức ở mục 5 phải là pure function, test được độc lập, để sau này Coach AI (LLM) gọi thẳng mà không phụ thuộc React.

### 1.3 Phân kỳ (phases) — build theo đúng thứ tự này

| Phase | Nội dung | Trạng thái |
|---|---|---|
| **Phase 1** | Training Center (Drill Library, Drill Session, Knowledge, Cut Angle Simulator, Timer & Schedule, Equipment/Cue) + Player Intelligence + AI Home (bản rule-based, chưa có LLM) | Đã có prototype, cần build lại chuẩn kiến trúc |
| **Phase 2** | Skill Test/Certification (progression gate dùng Player Intelligence), Onboarding & Skill Assessment, hệ Rank | Chưa build |
| **Phase 3** | Play (Match Recording, Match History, Competition), Statistics gộp Training+Play | Chưa build |
| **Phase 4** | Coach (AI Chat qua LLM, dùng Player Intelligence làm context), Recommendation engine nâng cấp | Chưa build |
| **Phase 5** | Camera/Vision auto-detect kết quả cú đánh, Backend sync (Supabase), Notifications | Chưa build |

**Yêu cầu cho lần code đầu tiên: chỉ build Phase 1 + khung sườn navigation cho các phase sau (route/tab rỗng với label "Sắp ra mắt" là đủ).**

---

## 2. Module tree đầy đủ (tham khảo toàn bộ sản phẩm, không phải yêu cầu build hết ngay)

```
PoolCoachAI
├── AI Home                          [Phase 1: rule-based / Phase 4: AI Coach thật]
│   ├── Today's Goals
│   ├── Continue
│   ├── Lịch hôm nay
│   ├── Progress rút gọn (streak, giờ tập)
│   └── Quick Actions
│
├── Training Center                  [Phase 1]
│   ├── AI Learning Path             [Phase 1: rule-based đơn giản]
│   ├── All Drills (search/filter theo trình độ & kỹ năng)
│   ├── Drill Detail
│   ├── Recording Preparation
│   ├── Drill Session (ghi nhận thủ công; camera/vision để Phase 5)
│   ├── Cut Angle Simulator
│   ├── Timer & Weekly Schedule
│   ├── Knowledge
│   ├── Skill Test                   [Phase 2]
│   └── Certification                [Phase 2]
│
├── Play                             [Phase 3]
│   ├── Match Recording
│   ├── Match History
│   └── Competition / Tournament
│
├── Coach                            [Phase 4]
│   ├── AI Chat
│   ├── Analysis
│   └── Recommendations
│
├── Statistics                       [Phase 1: chỉ Training / Phase 3: gộp Play]
│
├── Profile
│   ├── Player Profile & Rank        [Phase 2 cho phần Rank]
│   ├── Equipment (Cơ bi-a)          [Phase 1]
│   ├── History
│   └── Settings
│
└── Notifications                    [Phase 5]
```

---

## 3. Data Model (Phase 1)

```typescript
type CategoryId = 'aim' | 'position' | 'brk' | 'safety' | 'kick';

interface Category {
  id: CategoryId;
  label: string;      // "Ngắm bi", "Đi bi / Vị trí", "Giao bóng", "Phòng thủ", "Bi băng"
  color: string;       // hex, dùng cho badge/chart
}

interface Drill {
  id: string;
  cat: CategoryId;
  name: string;
  level: 1|2|3|4|5;
  unit: string;               // label hiển thị, VD "lần trúng / 10"
  goal: string;                // mô tả mục tiêu bài tập
  steps: string[];             // hướng dẫn từng bước
  // CHỈ MỘT trong hai field dưới được set, dùng để tính drillRatio (xem mục 5):
  passThreshold?: number;      // 0–1, dùng khi log có field attempts (tỉ lệ thành công cần đạt)
  target?: number;             // dùng khi log KHÔNG có attempts (VD: cm, số lần trong 60s)
}

interface DrillLog {
  id: string;
  drillId: string;
  date: string;        // ISO yyyy-mm-dd
  score: number;
  attempts?: number;   // optional — có thì dùng passThreshold, không thì dùng target
  notes?: string;
}

interface ScheduleSlot {
  id: string;
  day: 0|1|2|3|4|5|6;  // 0 = Thứ 2 ... 6 = Chủ nhật
  time: string;         // "HH:MM"
  label: string;
  cat?: CategoryId;
}

interface Cue {
  id: string;
  name: string;
  type: 'Cơ chính' | 'Cơ break' | 'Cơ jump';
  weight?: number;       // oz
  tipSize?: number;      // mm
  tipType?: 'Mềm'|'Vừa'|'Cứng';
  suited: CategoryId[];  // kỹ năng phù hợp — dùng để gợi ý cơ trong Timer session
  lastMaintenance?: string; // ISO date
  notes?: string;
}

interface TimerSession {
  id: string;
  date: string;
  durationSec: number;
  cat?: CategoryId;
  cueId?: string;
}

interface KnowledgeArticle {
  id: string;
  cat: CategoryId;
  title: string;
  body: string;
  relatedDrillIds?: string[]; // liên kết 2 chiều với Drill
}
```

**Seed data:** dùng đúng 5 category, 10 drill mẫu, và 6 bài Knowledge đã có trong prototype (copy nguyên từ `poolcoachai-reference.html`, phần `const CATS`, `const DRILLS`, `const KNOWLEDGE`) làm dữ liệu khởi tạo — không cần nghĩ lại nội dung.

---

## 4. Các module Phase 1 — chi tiết hành vi

### 4.1 AI Home (bản rule-based)
- Hiển thị: streak hiện tại, tổng giờ tập, lịch tập của hôm nay (lấy từ `ScheduleSlot` theo `day` tương ứng), hoạt động gần đây (4 log gần nhất).
- "Today's Goals" (Complete / Read / Next) = output của Rule-based Recommendation Engine, xem chi tiết đầy đủ ở **mục 6**. Không tự chế logic khác ở đây — mục 4.1 chỉ là nơi hiển thị.
- Quick Actions: mở All Drills, mở Cut Angle Simulator, bắt đầu Timer.

### 4.2 Drill Library / Drill Detail / Drill Session
- List + filter theo `CategoryId`, hiển thị level bằng 5 chấm tròn, hiển thị điểm tốt nhất từng đạt.
- Drill Detail: mục tiêu, các bước, form ghi kết quả (`score`, `attempts` optional, `notes`), lịch sử 5 lần gần nhất.
- **Recording Preparation:** trước khi vào Drill Session hiển thị checklist ngắn (setup bàn, xác nhận sẵn sàng) — button "Bắt đầu" mới mở form ghi kết quả. Đây là màn hình riêng, không gộp vào Drill Detail.
- Không làm Camera/Vision ở Phase 1 — chỉ có nút ghi nhận thủ công. Vẫn thiết kế Drill Session component sao cho có thể thêm chế độ camera sau (interface `RecordingMethod = 'manual' | 'vision'`).

### 4.3 Cut Angle Simulator
Thuật toán ghost-ball, copy nguyên từ prototype:
```
u = normalize(pocket - objectBall)
ghostBall = objectBall - u * (2 * ballRadius)
cutAngle = angle_between(ghostBall - cueBall, u)   // độ, 0–90+
```
Ngưỡng độ khó: `<35° dễ`, `35–65° trung bình`, `65–88° khó`, `>88° gần bất khả thi`.
UI: canvas cho phép đặt 3 điểm (bi cái → bi mục tiêu → chọn lỗ, snap vào lỗ gần nhất), vẽ đường ngắm + đường vào lỗ, hiển thị số độ và nhãn độ khó.

### 4.4 Timer & Weekly Schedule
- Đồng hồ: đếm lên hoặc đếm ngược (nhập số phút), gắn optional `cat` + `cueId`, nút "Lưu buổi tập" tạo 1 `TimerSession`.
- Lịch tuần: CRUD `ScheduleSlot`, hiển thị nhóm theo 7 ngày.
- `TimerSession` và `DrillLog` cùng đóng góp vào streak (ngày có ít nhất 1 trong 2 loại → tính là ngày có tập).

### 4.5 Equipment (Cơ bi-a)
- CRUD `Cue`. Hiển thị cảnh báo nếu `lastMaintenance` quá 90 ngày.
- `suited: CategoryId[]` dùng để hiển thị gợi ý cơ khi bắt đầu Timer session theo `cat` đã chọn (nếu có cơ nào match thì show gợi ý, không bắt buộc chọn).

### 4.6 Knowledge
- List + accordion mở rộng nội dung. Filter theo `cat`. Nếu vào từ Drill Detail (qua `relatedDrillIds`), mở đúng bài liên quan.

### 4.7 Statistics (bản Phase 1, chỉ có Training)
- Tổng giờ tập, streak.
- Biểu đồ số lượt tập theo từng kỹ năng (bar chart đơn giản).
- Biểu đồ tiến bộ theo từng Drill cụ thể (chọn 1 Drill → line chart điểm số theo thời gian).
- **Đánh giá năng lực (Player Intelligence)** — xem mục 5, đây là phần hiển thị quan trọng nhất của Statistics.

---

## 5. Player Intelligence — công thức bắt buộc (đã test, giữ nguyên)

Đây là lớp logic thuần (pure function), không phụ thuộc UI, không phụ thuộc AI. Đặt trong `/domain/playerIntelligence.ts`.

### 5.1 Hằng số
```typescript
const MIN_SESSIONS = 3;       // số buổi tối thiểu trong 1 kỹ năng để dám kết luận
const RECENCY_DECAY = 0.85;   // buổi càng cũ càng giảm trọng số
const WEAK_CUTOFF = 55;       // dưới ngưỡng này -> điểm yếu
const STRONG_CUTOFF = 75;     // trên ngưỡng này -> điểm mạnh
const READY_STREAK = 3;       // số buổi đạt liên tiếp để coi là sẵn sàng lên cấp
```

### 5.2 Quy đổi 1 log → tỉ lệ đạt mục tiêu (`drillRatio`)
```typescript
function drillRatio(drill: Drill, log: DrillLog): number | null {
  if (drill.passThreshold && log.attempts) {
    return (log.score / log.attempts) / drill.passThreshold;
  }
  if (drill.target) {
    return log.score / drill.target;
  }
  return null; // thiếu thông tin để chấm
}
```
`ratio >= 1` = đạt mục tiêu của level đó. `ratio` được chặn trên ở 1.2 khi đưa vào tính mastery (tránh 1 buổi ăn may kéo điểm quá cao).

### 5.3 Mastery score theo từng category (0–100, recency-weighted)
```typescript
function categoryMastery(logsAscByDate: {ratio:number}[]): number {
  const rev = [...logsAscByDate].reverse(); // mới nhất trước
  let wsum = 0, vsum = 0;
  rev.forEach((l, i) => {
    const w = Math.pow(RECENCY_DECAY, i);
    wsum += w;
    vsum += w * Math.min(1.2, l.ratio);
  });
  return Math.round(Math.min(1, vsum / wsum) * 100);
}
```
Nếu số log trong category < `MIN_SESSIONS` → trả `mastery: null`, `trend: 'na'` — **không được suy diễn** khi chưa đủ dữ liệu.

### 5.4 Xu hướng (trend)
So trung bình nửa log gần đây với nửa log trước đó (chỉ tính khi n ≥ 4):
```typescript
function trend(logsAscByDate: {ratio:number}[]): 'up'|'down'|'flat' {
  const n = logsAscByDate.length;
  const half = Math.floor(n / 2);
  const avg = (arr) => arr.reduce((s,x)=>s+Math.min(1.2,x.ratio),0)/arr.length;
  const diff = avg(logsAscByDate.slice(n-half)) - avg(logsAscByDate.slice(0,half));
  if (diff > 0.1) return 'up';
  if (diff < -0.1) return 'down';
  return 'flat';
}
```

### 5.5 Weak / Strong categories
Chỉ xét category đã có đủ dữ liệu (`mastery !== null`):
- `weak`: `mastery < WEAK_CUTOFF`, sắp xếp tăng dần
- `strong`: `mastery >= STRONG_CUTOFF`, sắp xếp giảm dần

### 5.6 Sẵn sàng lên cấp (readyForLevelUp) — dùng làm gate cho Skill Test ở Phase 2
```typescript
function isReadyForLevelUp(drill: Drill, logsAscByDate: DrillLog[]): boolean {
  if (logsAscByDate.length < READY_STREAK) return false;
  const lastN = logsAscByDate.slice(-READY_STREAK).map(l => drillRatio(drill, l));
  return lastN.every(r => r !== null && r >= 1);
}
```
**Business rule quan trọng (đồng bộ với PoolCoachAI gốc):** người chơi KHÔNG được tự bấm nút "Hoàn thành Level" để mở level tiếp theo. Ở Phase 2, Skill Test chỉ được kích hoạt/hiện nút khi `isReadyForLevelUp === true`.

### 5.7 Output tổng hợp — đây là object sẽ được dùng lại ở Phase 4 (Coach)
```typescript
interface PlayerIntelligence {
  categories: Record<CategoryId, { mastery: number|null; trend: 'up'|'down'|'flat'|'na'; n: number }>;
  weak: CategoryId[];
  strong: CategoryId[];
  readyDrills: string[]; // drill ids
  hasAnyData: boolean;
}
```
Ở Phase 4, Coach Chat (LLM) chỉ nhận object này (đã tính sẵn) làm ngữ cảnh — **không bao giờ để LLM tự tính lại các con số**, tránh AI "bịa" nhận định sai về người chơi.

### 5.8 Unit test bắt buộc trước khi coi Phase 1 xong
Test case tối thiểu (giá trị mong đợi đã verify thủ công):
```typescript
// 4 log drill d1 (passThreshold 0.8): 8/10, 9/10, 9/10, 10/10 → mastery cao, trend 'up', strong
// 3 log drill d7 (passThreshold 0.7): 3/10, 4/10, 4/10 → mastery ~53, trend 'flat', weak
// d1 có 4 log liên tiếp ratio >= 1 ở 3 log cuối → readyDrills chứa 'd1'
```

---

## 6. Rule-based Recommendation Engine (AI Learning Path v1)

Đặt trong `/domain/recommendation.ts`. Đây vẫn là logic thuần (deterministic), **không gọi LLM** — chỉ tiêu thụ output của `computePlayerIntelligence()` (mục 5) để quyết định "hôm nay nên tập gì". Đây chính là nội dung hiển thị ở khối "Today's Goals" trên AI Home (mục 4.1).

### 6.1 Chọn kỹ năng nên tập hôm nay — thứ tự luật ưu tiên (rule đầu tiên khớp sẽ thắng)
1. **Lịch tập hôm nay có gắn kỹ năng cụ thể** (`ScheduleSlot.cat` cho `day` hôm nay) → dùng đúng kỹ năng đó. Ý định tường minh của người chơi luôn thắng luật tự động.
2. **Sắp mất streak** — hôm nay và hôm qua đều chưa có `DrillLog` hoặc `TimerSession` nào, nhưng đã từng có dữ liệu trước đó → chọn kỹ năng có **tổng số lượt log ít nhất** (ưu tiên dễ, mục tiêu là kéo người chơi quay lại tập chứ chưa phải sửa điểm yếu).
3. **Có kỹ năng đang yếu** (`pi.weak` không rỗng, đã đủ dữ liệu) → chọn kỹ năng yếu nhất (`pi.weak[0]`, đã sort tăng dần).
4. **Người mới, chưa đủ dữ liệu ở bất kỳ kỹ năng nào** (`pi.hasAnyData === false`) → đi theo thứ tự làm quen cố định: `aim → position → brk → safety → kick`, chọn kỹ năng đầu tiên chưa từng được log.
5. **Có kỹ năng đang đi xuống** (`trend === 'down'`) dù chưa tới ngưỡng yếu → ôn lại kỹ năng đó.
6. **Mặc định (rotate)** — không rule nào ở trên khớp → chọn kỹ năng có ngày log gần nhất **xa nhất trong quá khứ** (lâu chưa đụng tới), để tránh dồn hết vào 1–2 kỹ năng.

### 6.2 Chọn Drill cụ thể trong kỹ năng đã chọn
```typescript
function pickDrillInCategory(cat: CategoryId, excludeDrillIds: string[]): Drill | null {
  const candidates = drillsOf(cat)
    .filter(d => !excludeDrillIds.includes(d.id))
    .sort((a, b) => a.level - b.level);
  for (const d of candidates) {
    const logs = logsOf(d.id).sort(byDateAsc);
    if (logs.length === 0) return d;                       // chưa từng tập -> ưu tiên thử
    const lastRatio = drillRatio(d, logs[logs.length - 1]);
    if (lastRatio === null || lastRatio < 1) return d;      // lần gần nhất chưa đạt -> vẫn cần tập
  }
  return candidates[candidates.length - 1] ?? null;          // đã đạt hết -> ôn bài khó nhất để giữ phong độ
}
```
`excludeDrillIds` = các drill đã được log **trong ngày hôm nay** — tránh gợi ý lại đúng bài người chơi vừa hoàn thành.

### 6.3 Gợi ý "Đọc thêm" (Knowledge)
Chọn 1 `KnowledgeArticle` có `cat` trùng với kỹ năng vừa chọn ở mục 6.1 (đơn giản nhất: article đầu tiên khớp category — không cần cá nhân hóa sâu ở Phase 1).

### 6.4 Gợi ý "Tiếp theo" (Next)
- Nếu `pi.readyDrills` không rỗng → hiển thị drill đầu tiên trong đó kèm thông báo đã sẵn sàng lên cấp (đây là điểm nối trực tiếp sang Skill Test ở Phase 2).
- Ngược lại → hiển thị streak hiện tại để khuyến khích duy trì (hoặc "tập buổi đầu tiên" nếu streak = 0).

### 6.5 Output tổng hợp cho AI Home
```typescript
interface TodayRecommendation {
  complete: { drill: Drill; reason: string } | null; // null nếu không còn drill nào phù hợp để gợi ý hôm nay
  read: KnowledgeArticle | null;
  next: string;
}
```

### 6.6 Test case bắt buộc (đã verify bằng 3 kịch bản)
```typescript
// A. Cold start (không có log nào): complete = drill Level 1 đầu tiên của category 'aim'
// B. Có log cũ (>1 ngày trước), có category yếu nhưng KHÔNG log gì hôm nay/hôm qua:
//    -> rule "sắp mất streak" phải thắng rule "kỹ năng yếu" (ưu tiên giữ thói quen trước khi sửa điểm yếu)
// C. Hôm nay có ScheduleSlot với cat cụ thể -> luôn thắng mọi rule khác, kể cả khi có kỹ năng đang rất yếu
```

---

## 7. Design tokens (giữ nguyên nếu muốn đồng bộ UI với prototype)

```css
--felt:#1F4D3A;   /* accent chính, nền hero */
--rail:#6B4226;   /* viền, header */
--chalk:#3D5A80;  /* nút chính, link */
--brass:#B8912B;  /* số liệu nổi bật, streak */
--ivory:#F6F1E7;  /* nền sáng */
--ink:#16211B;    /* chữ chính */
font-display: 'Fraunces' (heading)
font-body: 'Inter' (UI/body)
font-mono: 'JetBrains Mono' (mọi số liệu: điểm, giờ, góc, streak)
```
Dark mode: xem file prototype, đã có bộ biến tương ứng qua `prefers-color-scheme`.

Motif: dùng bi số (ball number badge, màu theo category) thay cho số thứ tự thông thường khi liệt kê Drill/Knowledge — đây là chi tiết nhận diện thương hiệu, giữ lại.

---

## 8. Ngoài phạm vi lần build này (để tránh scope creep)
Không code các phần sau trừ khi được yêu cầu thêm: Onboarding/Rank, Skill Test/Certification thật, Play/Match, Coach Chat (LLM), Camera/Vision, Backend/Supabase sync, Notifications. Chỉ cần chừa route/tab rỗng có nhãn tương ứng để không phải sửa navigation về sau.

## 9. Tiêu chí hoàn thành Phase 1
- [ ] Toàn bộ data model ở mục 3 implement bằng TypeScript interfaces, lưu qua local storage adapter tách biệt khỏi UI
- [ ] 7 module ở mục 4 hoạt động đầy đủ, dùng đúng seed data từ prototype
- [ ] `computePlayerIntelligence` là pure function trong `/domain`, có unit test theo mục 5.8 pass
- [ ] `computeRecommendation` (mục 6) là pure function trong `/domain`, có unit test theo mục 6.6 pass, và được hiển thị ở AI Home dưới dạng Complete/Read/Next
- [ ] Simulator tính đúng góc cắt theo công thức mục 4.3, verify bằng vài case tay (VD: bi thẳng hàng → 0°)
- [ ] Không có gọi API/LLM nào trong Phase 1 — toàn bộ chạy offline
- [ ] UI responsive, theo design tokens mục 7, có dark mode
