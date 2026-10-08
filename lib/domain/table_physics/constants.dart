// Hằng số vật lý của bàn — spec 2026-10-02 mục 3.
//
// Giá trị khởi điểm lấy từ tài liệu đã công bố (Alciatore, Han 2005,
// pooltool), rồi chủ sản phẩm chỉnh bằng mắt trên Chrome. Test chỉ dùng
// tên, không dùng giá trị, nên chỉnh hằng số không phải viết lại test.
// Đơn vị: cm, giây, gam, radian (trừ chỗ ghi độ).

/// Gia tốc trọng trường, cm/s².
const gravity = 981.0;

/// Khối lượng bi tiêu chuẩn, g.
const ballMass = 170.0;

/// Ma sát trượt bi–khăn (pooltool `u_s`).
const muSlide = 0.2;

/// Cản lăn (pooltool `u_r`).
const muRoll = 0.01;

/// Ma sát làm tắt xoáy quanh trục đứng (pooltool `u_sp`).
const muSpin = 0.044;

/// Hệ số phục hồi bi–bi.
const ballRestitution = 0.95;

/// Ma sát bi–bi theo vận tốc trượt `v` (m/s): `μ = A + B·e^(−C·v)`
/// (Alciatore TP A.14). `C` tính theo s/m, nên đổi cm/s ra m/s trước.
const throwFrictionA = 9.951e-3;
const throwFrictionB = 0.108;
const throwFrictionC = 1.088;

/// Hệ số phục hồi bi–băng (pooltool `e_c`).
const cushionRestitution = 0.85;

/// Ma sát bi–băng (pooltool `f_c`).
const cushionFriction = 0.2;

/// Độ cao mũi băng, tính theo đường kính bi (WPA 62.5–64.5 %).
const cushionHeight = 0.635;

/// Vận tốc bi cái ở lực 100 %, cm/s.
const maxCueSpeed = 800.0;

/// Độ lệch dọc của đầu cơ khi trô/cu lê, tính theo bán kính bi.
const strokeOffset = 0.5;

/// Khối lượng đầu cơ hiệu dụng chia khối lượng bi — quyết định độ lệch
/// do áp phê.
const endMassRatio = 0.03;

/// Hai mức độ dốc cơ, độ.
const cueElevationNormal = 5.0;
const cueElevationSteep = 15.0;

/// Bước tích phân, s.
const timeStep = 0.001;

/// Dưới cả hai ngưỡng thì bi đứng hẳn: cm/s và rad/s.
const stopSpeed = 0.5;
const stopSpin = 0.5;

/// Trần an toàn, s. Vượt là lỗi chứ không phải kết quả.
const maxSimTime = 20.0;

/// Màn mô phỏng: người chơi bấm *Chờ* thì tính lại với giới hạn này
/// (spec cú phòng thủ mục 7). Planner không bao giờ chờ.
const extendedSimTime = 3 * maxSimTime;

/// Dừng dò bù ném khi hướng bi mục tiêu sai dưới mức này, độ.
const aimTolerance = 0.05;

/// Dò bù ném tối đa ngần này vòng rồi chấp nhận kết quả tốt nhất.
const maxAimIterations = 12;

/// Đánh đứng bi dò điểm đặt cơ trong `[−stunMaxOffset·R, 0]`.
const stunMaxOffset = 0.6;

/// Bước dò lực khi tìm biên chết cái, %; rồi dò mịn 1 % trong khoảng
/// tìm được.
const overhitScanStep = 5.0;

/// Rút gọn đường đi: bỏ điểm lệch khỏi đoạn thẳng dưới mức này, cm.
const pathTolerance = 0.05;
