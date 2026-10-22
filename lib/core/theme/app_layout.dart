/// Giá trị dàn trang dùng chung: cỡ chữ tối đa, mốc bề ngang, bề rộng đọc.
///
/// Gom về một chỗ để mọi màn đọc cùng một con số, sửa một nơi là đủ.
abstract final class AppLayout {
  /// Cỡ chữ hệ thống lớn nhất app chịu theo; lớn hơn thì kẹp về đây, nhỏ
  /// hơn thì để nguyên.
  ///
  /// 1.5 phủ mọi cỡ chữ chuẩn trên cả hai nền tảng: iOS lên tới khoảng
  /// 1.35 trước khi sang các cỡ trợ năng.
  static const double maxTextScale = 1.5;

  /// Cỡ chữ lớn nhất của nhãn thanh tab dưới.
  ///
  /// Ở 360 dp mỗi ô trong năm ô của thanh chỉ rộng 72 dp, nhãn không còn
  /// chỗ để to thêm. Thanh bên không bị giới hạn này.
  static const double navBarLabelMaxTextScale = 1.0;
}
