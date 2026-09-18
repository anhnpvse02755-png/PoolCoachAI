/// Kết quả một lần thực hiện bài tập.
///
/// [attempts] có mặt khi bài chấm theo tỉ lệ (`Drill.passThreshold`),
/// vắng mặt khi bài chấm theo mục tiêu tuyệt đối (`Drill.target`).
class DrillLog {
  const DrillLog({
    required this.id,
    required this.drillId,
    required this.date,
    required this.score,
    this.attempts,
    this.notes,
  });

  final String id;
  final String drillId;
  final DateTime date;
  final num score;
  final int? attempts;
  final String? notes;
}
