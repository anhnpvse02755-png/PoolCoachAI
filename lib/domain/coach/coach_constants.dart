// Hằng số của Coach tình huống — spec 2026-10-21 mục 5.1. Test chỉ dùng
// tên, không dùng giá trị, như hằng số của Planner: chỉnh sau buổi chủ sản
// phẩm thử 10 tình huống không phải viết lại test.

/// Số lần trả lời tối đa: sai 1 → gợi ý 1, sai 2 → gợi ý 2, sai 3 → đáp án
/// (chủ sản phẩm chốt Q1, 21/10/2026).
const coachMaxAnswers = 3;

/// Mức chênh `OptionScore.total` còn tính là đạt, điểm (Q3, 21/10/2026).
/// Bằng phạt Đánh cu lê.
const coachScoreTolerance = 3.0;

/// Số cú "cũng đạt" hiện trong đáp án.
const coachEquivalentsShown = 3;

/// Số thế bàn thử bằng hình học trước khi bỏ.
const coachGeometryTries = 400;

/// Số thế bàn được chạy Planner để thử, cho nhóm Ngắm bi và Vị trí.
const coachPhysicsTries = 6;

/// Khoảng cách tối thiểu từ tâm bi tới điểm lỗ, cm.
const coachMinPocketClearance = 12.0;

/// Khe tối thiểu giữa hai bi khi sinh ngẫu nhiên, cm.
const coachBallGap = 0.5;

/// Xác suất một bi nằm sát băng.
const coachFrozenRailChance = 0.1;

/// Vị trí sinh ra làm tròn tới mức này, cm.
const coachPositionQuantum = 0.5;

/// Số lần làm gần nhất dùng cho thẻ gợi ý.
const coachStatsWindow = 10;

/// Ít hơn số lần này thì thẻ gợi ý nói chưa đủ dữ liệu.
const coachStatsMin = 5;

/// Một nhóm lỗi xuất hiện từ ngần này lần trong [coachStatsWindow] lần gần
/// nhất mới là lỗi lặp lại.
const coachRecurringMin = 3;

/// Tăng khi hằng số chấm của Planner hoặc Coach đổi. Lưu trong mỗi lần làm.
const coachScoringVersion = 1;

/// Số trận đã xong gần nhất đưa vào ngữ cảnh Coach Chat (spec Giai đoạn B).
const coachChatRecentMatches = 10;
