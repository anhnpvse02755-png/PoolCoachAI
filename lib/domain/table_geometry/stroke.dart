/// Ba kiểu đánh theo trục dọc: đứng · trô · cu lê.
enum Stroke { stun, draw, follow }

enum SpinSide { left, right }

/// Bề rộng đầu cơ chuẩn, cm (giữa khoảng 12.2–12.8 mm).
const tipWidth = 1.25;

/// Từ mức lệch này trở lên thì cảnh báo trượt cơ: 2 đầu cơ ≈ 0.87R,
/// quá giới hạn thường gặp 0.5–0.6R.
const miscueTips = 2.0;

/// Ba mức lực trên màn — khớp `POWER_CANDIDATES` của Planner, để điều
/// người chơi thấy ở đây đúng là điều Planner sẽ gợi ý.
const powerPresets = <double>[40, 70, 95];

/// Áp phê, đo bằng số đầu cơ lệch từ tâm bi cái tới tâm đầu cơ.
///
/// Người chơi không đặt đầu cơ chính xác tới milimét được, nhưng tự
/// đối chiếu được "lệch một đầu cơ" bằng mắt — nên chỉ có các mức này.
class SideSpin {
  const SideSpin(SpinSide this.side, this.tips) : assert(tips > 0);
  const SideSpin.none()
      : side = null,
        tips = 0;

  final SpinSide? side;
  final double tips;

  static const all = <SideSpin>[
    SideSpin.none(),
    SideSpin(SpinSide.left, 0.5),
    SideSpin(SpinSide.left, 1),
    SideSpin(SpinSide.left, 2),
    SideSpin(SpinSide.right, 0.5),
    SideSpin(SpinSide.right, 1),
    SideSpin(SpinSide.right, 2),
  ];

  bool get isNone => side == null;
  bool get risksMiscue => tips >= miscueTips;

  @override
  bool operator ==(Object other) =>
      other is SideSpin && other.side == side && other.tips == tips;

  @override
  int get hashCode => Object.hash(side, tips);

  @override
  String toString() => 'SideSpin($side, $tips)';
}
