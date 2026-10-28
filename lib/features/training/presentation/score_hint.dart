import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';

/// Gợi ý ô nhập điểm của một bài: một nguồn duy nhất cho màn tập và màn
/// Skill Test. Bài đếm theo lần thử có gợi ý riêng; bài có nguồn BU lấy số
/// cú từ nguồn; còn lại dùng ví dụ chung.
String scoreHintFor(Drill drill) {
  if (drill.usesAttempts) return Vi.sessionScoreHintAttempts;
  final provenance = drillProvenanceOf(drill.id);
  if (provenance != null) return Vi.sessionScoreHintRange(provenance.shots);
  return Vi.sessionScoreHintTarget;
}
