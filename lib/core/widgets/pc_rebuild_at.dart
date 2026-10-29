import 'dart:async';

import 'package:flutter/widgets.dart';

/// Dựng lại [builder] một lần khi tới giờ [at] (cộng một giây cho chắc).
///
/// Dành cho thứ phụ thuộc vào "đã tới giờ chưa" mà không có sự kiện nào báo
/// khi giờ tới. Timer thuộc về widget: đổi [at] hoặc [now] thì đặt lại, bỏ
/// widget thì huỷ. [at] null là không đặt timer.
class PcRebuildAt extends StatefulWidget {
  const PcRebuildAt({
    required this.at,
    required this.now,
    required this.builder,
    super.key,
  });

  final DateTime? at;
  final DateTime now;
  final WidgetBuilder builder;

  @override
  State<PcRebuildAt> createState() => _PcRebuildAtState();
}

class _PcRebuildAtState extends State<PcRebuildAt> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(PcRebuildAt old) {
    super.didUpdateWidget(old);
    if (old.at != widget.at || old.now != widget.now) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final at = widget.at;
    if (at == null) return;
    var wait = at.difference(widget.now) + const Duration(seconds: 1);
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
