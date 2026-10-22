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

  /// Bề ngang từ đó màn thuộc loại "vừa" của Material 3: dưới 600 dp là
  /// điện thoại dọc. Mọi điện thoại nằm ngang rộng ít nhất 640 dp nên đều
  /// thuộc loại vừa.
  ///
  /// Từ mốc này shell đổi thanh tab dưới thành thanh bên: thanh dưới ăn
  /// 80 dp trong 360 dp chiều cao của máy ngang, còn chiều ngang thì dư.
  static const double mediumWidth = 600;

  /// Chiều cao dưới mức này là loại "thấp" của Material 3: điện thoại nằm
  /// ngang, cao 360–430 dp.
  ///
  /// Ở đó thanh bên không chứa nổi năm mục có nhãn cộng nút Coach (cần gần
  /// 400 dp, mà máy 360 dp trừ thanh trạng thái chỉ còn 336), nên chỉ mục
  /// đang chọn hiện nhãn.
  static const double compactHeight = 480;

  /// Bề rộng tối đa của nội dung màn đọc trên cửa sổ rộng, đặt giữa.
  ///
  /// Danh sách kéo dài 1200 dp rất khó đọc. Màn có bàn bi thì không bị
  /// chặn: bàn cần từng điểm ảnh.
  static const double readableMaxWidth = 840;
}
