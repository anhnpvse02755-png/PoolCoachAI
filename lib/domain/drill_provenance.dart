import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';

/// Nguồn của một bài nâng cao: bài BU và bậc mà bố cục của nó mượn.
///
/// Mọi con số suy ra từ phiếu điểm BU, không chép tay: số cú là
/// `attemptCount` của bài BU (một điểm mỗi cú), cấp là bậc.
final class DrillProvenance {
  const DrillProvenance({required this.buDrillId, required this.version});

  final String buDrillId;
  final ExamIIVersion version;

  /// Số cú của bài, theo phiếu điểm BU.
  int get shots => drillFor(buDrillId, version).attemptCount;

  /// Cấp của bài: Bachelors 1, Masters 2, Doctorate 3.
  int get level => version.index + 1;
}

/// Bảng nguồn d11–d19. Không lưu trong DB; chỉ chứa mã và bậc.
const drillProvenance = <String, DrillProvenance>{
  'd11': DrillProvenance(buDrillId: 'S8', version: ExamIIVersion.bachelors),
  'd12': DrillProvenance(buDrillId: 'S8', version: ExamIIVersion.masters),
  'd13': DrillProvenance(buDrillId: 'S8', version: ExamIIVersion.doctorate),
  'd14': DrillProvenance(buDrillId: 'S9', version: ExamIIVersion.bachelors),
  'd15': DrillProvenance(buDrillId: 'S9', version: ExamIIVersion.masters),
  'd16': DrillProvenance(buDrillId: 'S9', version: ExamIIVersion.doctorate),
  'd17': DrillProvenance(buDrillId: 'S9', version: ExamIIVersion.bachelors),
  'd18': DrillProvenance(buDrillId: 'S9', version: ExamIIVersion.masters),
  'd19': DrillProvenance(buDrillId: 'S9', version: ExamIIVersion.doctorate),
};

DrillProvenance? drillProvenanceOf(String drillId) => drillProvenance[drillId];

/// Lỗi điểm của bài đếm theo cú.
enum ShotScoreError { notWhole, aboveShots }

/// Điểm của bài BU là số cú thành công: số nguyên từ 0 tới số cú.
/// `null` với bài không có nguồn BU. Điểm âm hoặc không hữu hạn để cho
/// các kiểm tra sẵn có xử lý.
ShotScoreError? checkShotScore(Drill drill, num score) {
  if (drillProvenanceOf(drill.id) == null) return null;
  if (!score.isFinite || score < 0) return null;
  if (score != score.truncate()) return ShotScoreError.notWhole;
  if (score > drill.target!) return ShotScoreError.aboveShots;
  return null;
}
