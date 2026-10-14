/// Lần lấy hạng từ máy chủ của người đang đăng nhập (spec mục 8).
enum RankFetch {
  /// Chưa có lượt đồng bộ nào trả lời.
  pending,

  /// Máy chủ trả lời: tài khoản chưa có dòng hạng nào.
  foundNone,

  /// Máy chủ trả lời: có dòng hạng (đã gộp xuống máy).
  found,

  /// Lượt đồng bộ hỏng trước khi lấy được hạng.
  failed,
}
