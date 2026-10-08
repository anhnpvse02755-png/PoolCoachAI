import 'package:poolcoachai/domain/table_geometry/stroke.dart';

// Hằng số của Kế hoạch dọn bàn — spec 2026-10-07 mục 3, tên bám PRD §4.
// Test chỉ dùng tên, không dùng giá trị: chỉnh điểm phạt sau buổi chủ sản
// phẩm xem trên Chrome không phải viết lại test.
//
// Góc cắt tối đa dùng chung `maxCutAngle` (85°) của shot_geometry.dart:
// khai báo lại ở đây là hai nguồn sự thật cho cùng một luật PRD §5.1.

/// Thứ tự thử cố định: bằng điểm thì giữ phương án thử trước.
const strokeCandidates = <Stroke>[Stroke.stun, Stroke.follow, Stroke.draw];

/// Năm mức lực — chung với màn Mô phỏng góc cắt.
const powerCandidates = powerPresets;

/// Lệch lực để đo vùng điều chịu sai số, điểm phần trăm.
const powerJitter = 15.0;

/// Cơ không đánh mạnh hơn 100 %: lực + [powerJitter] kẹp về đây.
const maxPower = 100.0;

/// Góc tính cho mức lực bị chắn, chết cái hoặc trượt lỗ, độ.
const blockedAngle = 95.0;

/// Cú kế tiếp giả định khi nhìn trước bi thứ hai: Đánh đứng bi ở lực này.
const lookaheadPower = 55.0;

/// Vùng điều: góc cắt dễ nhất cho bi kế tiếp, độ.
const zoneGood = 35.0;
const zoneFair = 55.0;

/// Cạnh ô lưới vùng điều, cm.
const zoneCell = 5.0;

/// Phạt dội băng: chạm 1 băng, từ 2 băng. Không chạm băng là 0. Tối đa
/// vẫn nhỏ hơn phạt trô: dội băng không bị coi là khó (PRD §5.3).
const bankPenaltyOneRail = 2.0;
const bankPenaltyManyRails = 7.0;

/// Phạt kỹ thuật theo kiểu đánh.
const techPenaltyStun = 0.0;
const techPenaltyFollow = 3.0;
const techPenaltyDraw = 10.0;

/// Phạt áp phê, cộng dồn với phạt kiểu đánh (spec quyết định 5).
const sidePenaltyHalfTip = 15.0;
const sidePenaltyOneTip = 20.0;

/// Hai mức áp phê của đường lui, đầu cơ.
const sideTipsCandidates = <double>[0.5, 1];

/// Lực × hệ số này: lực càng lớn càng dễ sai số và chết cái.
const powerPenaltyPerPercent = 0.04;

/// Quãng bi ảo → điểm dừng (cm) × hệ số này: chỉ để phân định khi hoà.
const distanceWeight = 0.01;

/// Cú dự phòng: Đánh đứng bi ở lực này.
const fallbackPower = 30.0;

/// Gợi ý dư dày / mỏng (PRD §5.5): sai số ngắm giả định, độ; quãng bi mục
/// tiêu trôi nếu trượt, cm.
const missAngleDeg = 5.0;
const missTravel = 110.0;

/// Số mức lực đều nhau trong ±[powerJitter] để đếm độ chịu sai số.
const toleranceSamples = 7;

/// Từ lực này trở lên thì cảnh báo lực cao (PRD §6.5).
const riskPower = 85.0;

/// Mỗi lát tính giữa hai khung hình (spec quyết định 4). 4 ms, không phải
/// 8 ms như spec gốc: đo sạch trên Chrome (task 14), 4 ms qua cổng khung
/// hình (trung vị ≤ 17 ms, p95 ≤ 20 ms) ở cả 7 lượt yên máy, 8 ms chỉ 3/7;
/// bước 1 vẫn 0,36–0,46 s. Chủ sản phẩm chốt 07/10/2026.
const sliceBudget = Duration(milliseconds: 4);

// Cú phòng thủ — spec 2026-10-07 planner-safety mục 4.5. Test chỉ dùng tên.

/// Độ dày cú thủ trực tiếp: trọn bi, ¾, ½, ¼, ⅛ (mỏng). Trừ trọn bi, mỗi
/// mức lệch hai bên.
const safetyThicknesses = <double>[1, 0.75, 0.5, 0.25, 0.125];

/// A băng: chạm trọn bi hoặc ½ bi hai bên.
const kickThicknesses = <double>[1, 0.5];

/// Áp phê của cú thủ trực tiếp, đúng thứ tự thử: trái ½, trái 1, phải ½,
/// phải 1 đầu cơ. Chỉ là đường lui (chủ sản phẩm chốt 08/10/2026, sửa spec
/// quyết định 4): mỗi bi hợp lệ thử trước các cú không áp phê, chỉ khi không
/// cú nào hợp lệ mới thử các cú này. A băng không áp phê.
const safetySideSpins = <SideSpin>[
  SideSpin(SpinSide.left, 0.5),
  SideSpin(SpinSide.left, 1),
  SideSpin(SpinSide.right, 0.5),
  SideSpin(SpinSide.right, 1),
];

/// A băng chỉ đánh đứng bi hoặc cu lê (spec 3.4).
const kickStrokes = <Stroke>[Stroke.stun, Stroke.follow];

/// Phạt A băng theo số băng (spec quyết định 7, số của chủ sản phẩm).
const kickRailPenalty = <int, double>{1: 10, 2: 20, 3: 45, 4: 55};

/// Thử tới 4 băng; chuỗi 4 băng chỉ là đường lui khi cả cú trực tiếp lẫn
/// A băng 1–3 băng không còn phương án hợp lệ nào (spec quyết định 3).
const maxKickRails = 4;
const kickFallbackRails = 4;

/// Thưởng mỗi bi sát băng (bi cái, bi đối thủ phải đánh dễ nhất).
const nearRailBonus = 5.0;

/// "Sát băng" là cách băng không quá ngần này đường kính bi (spec 4.5:
/// nearRailDistance = ballDiameter). Hằng số theo đường kính vì đường kính
/// là trường của TableSpec, không phải hằng số biên dịch.
const nearRailDiameters = 1.0;

/// Đối thủ "khó" khi góc cắt dễ nhất lớn hơn mức này (spec 4.3).
const opponentHardAngle = zoneFair;

/// Dò hướng cơ cho cú thủ: dừng khi độ lệch ngang lúc chạm sai dưới ngần
/// này đường kính bi (≈ 1 mm, khoảng 2 % độ dày).
const contactTolerance = 0.02;

/// Dò tối đa ngần này lần chạm thử mỗi phương án; không hội tụ thì bỏ
/// phương án (spec 3.4). Nguyên mẫu trên a35667b: A băng cần trung vị 9 lần.
const maxContactProbes = 16;

/// Mỗi bước cát tuyến xoay tối đa ngần này độ: bước lớn hơn dễ nhảy sang
/// chuỗi băng khác. Điểm soi gương trượt thì dò dần ra hai bên từng bước
/// [contactStartStepDeg].
const contactMaxStepDeg = 2.0;
const contactStartStepDeg = 0.5;

/// Số khoảng chấm: băng dài 0–8, băng ngắn 0–4 (spec, thuật ngữ "Chấm").
const longRailDiamonds = 8;
const shortRailDiamonds = 4;
