import 'dart:async';

import 'package:flutter/widgets.dart';

/// Dựng lại [builder] khi tới giờ kế tiếp mà [nextAt] trả về (cộng một giây
/// cho chắc), rồi đặt tiếp cho giờ sau đó.
///
/// Dành cho thứ phụ thuộc vào "đã tới giờ chưa" mà không có sự kiện nào báo
/// khi giờ tới. Timer thuộc về widget: widget đổi thì đặt lại, bỏ widget thì
/// huỷ. [nextAt] nhận "bây giờ" theo [clock] và trả về giờ kế tiếp sau đó,
/// hoặc null là không đặt timer.
class PcRebuildAt extends StatefulWidget {
  const PcRebuildAt({
    required this.clock,
    required this.nextAt,
    required this.builder,
    super.key,
  });

  final DateTime Function() clock;
  final DateTime? Function(DateTime now) nextAt;
  final WidgetBuilder builder;

  @override
  State<PcRebuildAt> createState() => _PcRebuildAtState();
}

class _PcRebuildAtState extends State<PcRebuildAt> {
  Timer? _timer;

  /// Máy ngủ thì timer đứng yên: lúc quay lại, giờ có thể đã qua mà timer
  /// chưa chạy. Quay lại app thì dựng lại và đặt timer theo đồng hồ mới.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _due);
    _schedule();
  }

  @override
  void didUpdateWidget(PcRebuildAt old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _due() {
    if (!mounted) return;
    setState(() {});
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final now = widget.clock();
    final at = widget.nextAt(now);
    // Giờ không ở phía sau "bây giờ" thì không đặt, kẻo timer 0 giây lặp mãi.
    if (at == null || !at.isAfter(now)) return;
    _timer = Timer(at.difference(now) + const Duration(seconds: 1), _due);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
