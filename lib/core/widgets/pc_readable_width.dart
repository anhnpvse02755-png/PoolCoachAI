import 'package:flutter/widgets.dart';
import 'package:poolcoachai/core/theme/app_layout.dart';

/// Giữ nội dung màn đọc trong một cột rộng tối đa [maxWidth], đặt giữa
/// (quyết định D7 của kế hoạch responsive).
///
/// Trong cột, [child] được dàn đúng như `Scaffold` dàn thân màn: ràng buộc
/// lỏng, đặt ở góc trên đầu dòng. Nhờ vậy màn hẹp hơn [maxWidth] không xê
/// dịch gì, kể cả thân màn tự co theo nội dung như một cột căn trái.
class PcReadableWidth extends StatelessWidget {
  const PcReadableWidth({
    required this.child,
    this.maxWidth = AppLayout.readableMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        width: double.infinity,
        child: Align(alignment: AlignmentDirectional.topStart, child: child),
      ),
    ),
  );
}
