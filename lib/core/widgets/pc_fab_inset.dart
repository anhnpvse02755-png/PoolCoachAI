import 'package:flutter/widgets.dart';

/// Khoảng đáy mà nút Coach nổi của shell đang chiếm, công bố cho mọi màn con.
///
/// Shell điện thoại dọc công bố [extent] bằng chỗ nút chiếm; thanh bên và lúc
/// bàn phím mở công bố 0 (nút nằm trong thanh bên, hoặc bị ẩn). Ngoài shell
/// (màn gốc không có nút) không có widget này nên khoảng là 0.
class PcFabInset extends InheritedWidget {
  const PcFabInset({required this.extent, required super.child, super.key});

  final double extent;

  /// Khoảng đáy hiện hành; 0 khi không có shell phía trên.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PcFabInset>()?.extent ?? 0;

  @override
  bool updateShouldNotify(PcFabInset oldWidget) => extent != oldWidget.extent;
}

/// Đệm của một danh sách cuộn trong shell: [base] cộng thêm chỗ nút Coach ở
/// đáy, để cuộn hết thì phần cuối nằm trên nút chứ không dưới nó.
///
/// Mọi danh sách cuộn trong shell mà nút Coach có thể che phần cuối đều phải
/// qua hàm này; vùng ghim hay không cuộn thì giữ đệm cũ.
EdgeInsets pcScrollPadding(BuildContext context, EdgeInsets base) =>
    base.copyWith(bottom: base.bottom + PcFabInset.of(context));
