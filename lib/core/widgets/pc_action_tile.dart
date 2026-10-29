import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Hàng thông báo có một nút hành động: biểu tượng, tiêu đề, chữ giải thích
/// và nút chữ.
///
/// Nút nằm cùng hàng với chữ khi cột chữ còn đủ rộng, ngược lại nút xuống
/// dưới chữ. Bố cục đo nút thật lúc dàn trang (nên chạy lại khi font nạp
/// muộn hay cỡ chữ đổi): hàng chỉ khi cột chữ, sau biểu tượng và nút, còn ít
/// nhất 11 em (cỡ 12 sp theo cỡ chữ người dùng chọn). Hẹp hơn thì chữ bị bóp
/// từng từ một dòng, che hết màn hình.
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

  static const _padding = 16.0;
  static const _iconGap = 16.0;
  static const _iconWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(_padding, 12, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _iconWidth, child: icon),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
    return _ActionLayout(
      // Phần cột chữ không phải chữ: lề trái, biểu tượng, khoảng cách.
      chrome: _padding + _iconWidth + _iconGap,
      minTextWidth: scaler.scale(12) * 11,
      content: content,
      button: TextButton(onPressed: onAction, child: Text(actionLabel)),
    );
  }
}

class _ActionLayout extends MultiChildRenderObjectWidget {
  _ActionLayout({
    required this.chrome,
    required this.minTextWidth,
    required Widget content,
    required Widget button,
  }) : super(children: [content, button]);

  final double chrome;
  final double minTextWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderActionLayout(chrome: chrome, minTextWidth: minTextWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActionLayout renderObject,
  ) {
    renderObject
      ..chrome = chrome
      ..minTextWidth = minTextWidth;
  }
}

class _ActionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderActionLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ActionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ActionParentData> {
  _RenderActionLayout({required double chrome, required double minTextWidth})
    : _chrome = chrome,
      _minTextWidth = minTextWidth;

  static const _gap = 8.0;

  double _chrome;
  double get chrome => _chrome;
  set chrome(double value) {
    if (value == _chrome) return;
    _chrome = value;
    markNeedsLayout();
  }

  double _minTextWidth;
  double get minTextWidth => _minTextWidth;
  set minTextWidth(double value) {
    if (value == _minTextWidth) return;
    _minTextWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ActionParentData) {
      child.parentData = _ActionParentData();
    }
  }

  RenderBox get _content => firstChild!;
  RenderBox get _button => childAfter(firstChild!)!;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _button.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final buttonSize = _button.size;
    final textWidth = width - buttonSize.width - _gap - chrome;
    final asRow = textWidth >= minTextWidth;
    final contentWidth = asRow ? width - buttonSize.width - _gap : width;
    _content.layout(
      BoxConstraints.tightFor(width: contentWidth),
      parentUsesSize: true,
    );
    final contentParent = _content.parentData! as _ActionParentData;
    final buttonParent = _button.parentData! as _ActionParentData;
    contentParent.offset = Offset.zero;
    if (asRow) {
      final height = _content.size.height > buttonSize.height
          ? _content.size.height
          : buttonSize.height;
      buttonParent.offset = Offset(
        width - buttonSize.width - _gap,
        (height - buttonSize.height) / 2,
      );
      size = constraints.constrain(Size(width, height));
    } else {
      buttonParent.offset = Offset(
        width - buttonSize.width - _gap,
        _content.size.height,
      );
      size = constraints.constrain(
        Size(width, _content.size.height + buttonSize.height + _gap),
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
