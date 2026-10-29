import 'package:flutter/material.dart';

/// Hàng thông báo có một nút hành động: biểu tượng, tiêu đề, chữ giải thích
/// và nút chữ.
///
/// Nút nằm cùng hàng với chữ khi cột chữ còn đủ rộng, ngược lại nút xuống
/// dưới chữ. Quy tắc theo bề rộng, không đo chữ bằng TextPainter (font nạp
/// muộn làm số đo cũ): cột chữ, sau biểu tượng và nút, phải còn ít nhất 11
/// ký tự cỡ 12 sp theo cỡ chữ người dùng chọn. Hẹp hơn thì chữ bị bóp từng
/// từ một dòng, che hết màn hình.
class PcActionTile extends StatelessWidget {
  const PcActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final Widget icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;

  static const _iconSlot = 56.0;
  static const _buttonPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(onPressed: onAction, child: Text(actionLabel));
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        // Bề rộng nút ước theo cỡ chữ nút (14 sp) và số ký tự nhãn.
        final buttonWidth =
            scaler.scale(14) * actionLabel.length * 0.5 + _buttonPadding * 2;
        final textWidth = box.maxWidth - _iconSlot - buttonWidth;
        if (textWidth >= scaler.scale(12) * 11) {
          return ListTile(
            leading: icon,
            title: Text(title),
            subtitle: Text(body),
            trailing: button,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(leading: icon, title: Text(title), subtitle: Text(body)),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: button,
              ),
            ),
          ],
        );
      },
    );
  }
}
