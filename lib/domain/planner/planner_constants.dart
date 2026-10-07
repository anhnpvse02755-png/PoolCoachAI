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

/// Mỗi lát tính giữa hai khung hình (spec quyết định 4).
const sliceBudget = Duration(milliseconds: 8);
