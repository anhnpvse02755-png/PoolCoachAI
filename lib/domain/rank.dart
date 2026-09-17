/// Ba nhóm hạng của PoolCoachAI.
enum RankGroup {
  /// K → G: cơ thủ phong trào, nghiệp dư.
  amateur,

  /// F → A: đã bước vào sân chơi cạnh tranh.
  competitive,

  /// Chuyên nghiệp.
  pro,
}

/// Hệ hạng của PoolCoachAI, xếp từ thấp lên cao.
///
/// Đây là bảng định nghĩa riêng của PoolCoachAI dựa trên cách hiểu hạng
/// tại Hà Nội, **không phải** chuẩn xếp hạng quốc gia duy nhất. Màn hình
/// nào hiển thị hạng cũng phải kèm chú thích này.
enum Rank {
  k(RankGroup.amateur),
  i(RankGroup.amateur),
  h(RankGroup.amateur),
  g(RankGroup.amateur),
  f(RankGroup.competitive),
  e(RankGroup.competitive),
  d(RankGroup.competitive),
  c(RankGroup.competitive),
  b(RankGroup.competitive),
  a(RankGroup.competitive),
  pro(RankGroup.pro);

  const Rank(this.group);

  final RankGroup group;

  /// Nhãn hiển thị: 'K', 'G', … và 'PRO'.
  String get label => this == Rank.pro ? 'PRO' : name.toUpperCase();
}
